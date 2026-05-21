#!/usr/bin/env python3
"""
Live Telegram -> CSV bridge for DiscoSignalReplay (and DISCO_BALL with a small mod).

Uses Telethon's user-API client (your phone number) to subscribe to channels
you're already in. Real-time event-driven, NOT polling. Lowest possible
end-to-end latency (typically <1 s from post to CSV).

Pipeline per incoming message:
  1. Telethon NewMessage event fires
  2. Convert message into a raw record string the existing parser eats
  3. parse_discord_signal() -> ParsedSignal (same parser handles TG and Discord format)
  4. typo_check_and_repair + apply_cancellations
  5. Append survivor to inbox CSV (same format as discord_poller writes)
  6. EA's OnTimer (CsvReloadIntervalSec) picks it up within seconds

Setup:
  1. Get api_id and api_hash from https://my.telegram.org -> API Development Tools
     (5-minute, free, one-time)
  2. Copy telegram_poller_config.example.json -> telegram_poller_config.json
     and fill in api_id, api_hash, channels, out_csv path.
  3. First run:
       python scripts/telegram_poller.py --config scripts/telegram_poller_config.json
     Telethon will prompt for your phone number and the SMS code Telegram sends.
     A session file is saved; subsequent runs auto-login.
  4. Leave it running (Task Scheduler, screen, tmux, nssm Windows service).
"""
import argparse
import asyncio
import csv
import json
import os
import signal as _signal
import sys
from collections import defaultdict, deque
from pathlib import Path

from telethon import TelegramClient, events
from telethon.tl.types import Channel, Chat, User

sys.path.insert(0, str(Path(__file__).parent))
from replay_discord_signals import (
    parse_discord_signal,
    typo_check_and_repair,
    apply_cancellations,
)

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

# Rolling buffer of recent signals per (author, symbol) so cancellation has
# context across calls. apply_cancellations() works on a list - we keep the
# last N parsed signals to apply the rule against.
RECENT_BUFFER_SIZE = 50


def load_config(path: Path) -> dict:
    with open(path, 'r', encoding='utf-8') as f:
        return json.load(f)


def load_state(path: Path) -> dict:
    if path.exists():
        with open(path, 'r', encoding='utf-8') as f:
            return json.load(f)
    return {'next_our_msg_id': 0}


def save_state(path: Path, state: dict) -> None:
    tmp = path.with_suffix('.tmp')
    with open(tmp, 'w', encoding='utf-8') as f:
        json.dump(state, f, indent=2)
    tmp.replace(path)


def msg_to_record(tg_msg, channel_label: str) -> str:
    """Convert a Telethon Message into the raw text record the existing parser expects.

    The parser reads ID, name, ISO timestamp, content - we mimic that shape.
    """
    sender_id = tg_msg.sender_id or 0
    # Channels post as the channel itself (no User); fall back to channel label
    sender_name = channel_label
    timestamp = tg_msg.date.isoformat()
    content = tg_msg.message or ''
    lines = content.splitlines()
    first = lines[0] if lines else ''
    rest = '\n'.join(lines[1:]) if len(lines) > 1 else ''
    return (
        f'"{sender_id},""{sender_name}"",""{timestamp}"",""{first}"\n'
        + (rest + '\n' if rest else '')
        + '","",""""'
    )


def _safe_channel_alias(name: str) -> str:
    return ''.join(c for c in name.upper() if c.isalnum())[:12] or 'CH'


def append_inbox_row(csv_path: Path, our_id: int, time_utc, channel: str,
                     symbol: str, side: str, entry: float, sl: float, tps: list[float]) -> None:
    csv_path.parent.mkdir(parents=True, exist_ok=True)
    new_file = not csv_path.exists()
    mt5_time = time_utc.strftime('%Y.%m.%d %H:%M:%S')
    tps_str = '|'.join(f'{t:.5f}' for t in tps)
    alias = _safe_channel_alias(channel)
    with open(csv_path, 'a', newline='', encoding='ascii') as f:
        w = csv.writer(f)
        if new_file:
            w.writerow(['id', 'time_mt5', 'channel', 'symbol', 'side', 'entry', 'sl', 'n_tps', 'tps'])
        w.writerow([our_id, mt5_time, alias, symbol, side,
                    f'{entry:.5f}', f'{sl:.5f}', len(tps), tps_str])


async def main_async(cfg: dict, state_path: Path):
    state = load_state(state_path)
    inbox_csv = Path(cfg['out_csv'])
    only_symbol = cfg.get('symbol_filter', 'XAUUSD')
    session_name = cfg.get('session', 'telegram_poller_session')

    # Resolve channels: accept either int IDs or string @usernames
    channel_specs = cfg['channels']     # [{"name": "...", "id": -100...|"@username"}]
    label_for_chat = {}                 # chat_id -> human label
    chat_id_filter = []

    client = TelegramClient(session_name, cfg['api_id'], cfg['api_hash'])
    await client.start()
    print(f'[start] Telethon connected as {(await client.get_me()).first_or_username if hasattr(await client.get_me(), "first_or_username") else "user"}', flush=True)

    for spec in channel_specs:
        ident = spec['id']
        try:
            entity = await client.get_entity(ident)
        except Exception as e:
            print(f'[start] WARN: cannot resolve channel {ident!r}: {e}', flush=True)
            continue
        cid = entity.id
        # Telegram channels resolve as -100<id> in some contexts; Telethon handles this
        chat_id_filter.append(cid)
        label_for_chat[cid] = spec.get('name', str(ident))
        title = getattr(entity, 'title', None) or getattr(entity, 'username', None) or str(cid)
        print(f'[start] subscribed: {spec.get("name", ident)} -> {title} (id={cid})', flush=True)

    if not chat_id_filter:
        print('[start] FATAL: no resolvable channels. Check api credentials and channel IDs.', flush=True)
        return

    # Rolling buffers used for cancellation context (per author+symbol)
    recent_signals = deque(maxlen=RECENT_BUFFER_SIZE)

    @client.on(events.NewMessage(chats=chat_id_filter))
    async def on_message(event):
        msg = event.message
        cid = event.chat_id
        label = label_for_chat.get(cid, str(cid))
        record = msg_to_record(msg, label)

        sig = parse_discord_signal(record, idx=msg.id, source=label)
        if sig is None:
            return

        # Drop non-target symbols early
        if only_symbol and sig.symbol != only_symbol:
            return

        # Bundle the new signal with the recent buffer so typo + cancel logic
        # has context (cancellation looks at "earlier opposite signals")
        batch = list(recent_signals) + [sig]
        cleaned, typo_stats = typo_check_and_repair(batch)
        cancel_stats = apply_cancellations(cleaned)

        # The signal we just received is the last element
        new_sig = cleaned[-1]
        recent_signals.append(new_sig)

        if new_sig.skip_reason:
            print(f'[skip] {label} msg={msg.id} reason={new_sig.skip_reason}', flush=True)
            return

        our_id = state.get('next_our_msg_id', 0)
        append_inbox_row(inbox_csv, our_id, new_sig.time_utc, label,
                         new_sig.symbol, new_sig.side, new_sig.entry, new_sig.sl,
                         new_sig.tps[:15])
        print(f'[written] id={our_id} ch={_safe_channel_alias(label)} '
              f'{new_sig.time_utc} {new_sig.symbol} {new_sig.side} '
              f'entry={new_sig.entry} sl={new_sig.sl} tps={len(new_sig.tps)} '
              f'typo={new_sig.typo_action}', flush=True)
        state['next_our_msg_id'] = our_id + 1
        save_state(state_path, state)

    print(f'[ready] listening on {len(chat_id_filter)} channel(s); writing to {inbox_csv}', flush=True)
    await client.run_until_disconnected()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--config', type=Path, required=True,
                    help='JSON config (see telegram_poller_config.example.json)')
    args = ap.parse_args()

    cfg = load_config(args.config)
    state_path = Path(cfg.get('state_file', 'telegram_poller_state.json'))

    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    # Graceful shutdown on Ctrl+C
    def _shutdown(*_):
        print('\n[shutdown] stopping', flush=True)
        for task in asyncio.all_tasks(loop):
            task.cancel()
    try:
        _signal.signal(_signal.SIGINT, _shutdown)
    except Exception:
        pass
    try:
        loop.run_until_complete(main_async(cfg, state_path))
    except (KeyboardInterrupt, asyncio.CancelledError):
        pass
    finally:
        loop.close()


if __name__ == '__main__':
    main()
