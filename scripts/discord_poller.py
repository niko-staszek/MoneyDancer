#!/usr/bin/env python3
"""
Live Discord -> CSV poller for DiscoSignalReplay EA.

Polls one or more Discord channels via REST API every N seconds, parses each
new message as a trading signal, applies typo + cancellation logic, and
appends survivors to a "live inbox" CSV in MT4/MT5 Files/ folder. The EA
re-reads this CSV on a timer and processes only new msg_ids.

Setup:
  - Config file (JSON) holds Discord token + channel IDs + paths.
  - Token: get from Discord browser by opening DevTools -> Network -> any API
    call -> Authorization header value. (Self-token, ToS-grey but standard
    for personal automation.)
  - Channel IDs: right-click channel in Discord -> Copy Channel ID
    (requires Developer Mode enabled in Discord settings).
  - State file persists last-seen message ID per channel for incremental polls.

Run:
  python scripts/discord_poller.py --config path/to/config.json
"""
import argparse
import csv
import json
import os
import signal
import sys
import time
from collections import defaultdict
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).parent))
from replay_discord_signals import (
    parse_discord_signal,
    typo_check_and_repair,
    apply_cancellations,
)

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

DISCORD_API = 'https://discord.com/api/v10'
USER_AGENT = 'DiscoSignalPoller/1.0'

# Each polled message is converted from the JSON API format into the same
# raw-text record format the existing Discord-export parser expects.
RECORD_TEMPLATE = (
    '"{author_id},""{author_name}"",""{timestamp}"",""{content_first_line}"\n'
    '{content_rest}","",""""'
)

_running = True


def handle_sigint(_sig, _frm):
    global _running
    print('\n[shutdown] SIGINT received, stopping after current poll', flush=True)
    _running = False


signal.signal(signal.SIGINT, handle_sigint)


def load_config(path: Path) -> dict:
    with open(path, 'r', encoding='utf-8') as f:
        return json.load(f)


def load_state(path: Path) -> dict:
    if path.exists():
        with open(path, 'r', encoding='utf-8') as f:
            return json.load(f)
    return {'last_msg_id_by_channel': {}, 'next_our_msg_id': 0}


def save_state(path: Path, state: dict) -> None:
    tmp = path.with_suffix('.tmp')
    with open(tmp, 'w', encoding='utf-8') as f:
        json.dump(state, f, indent=2)
    tmp.replace(path)


def fetch_messages(token: str, channel_id: str, after_id: str | None = None,
                   limit: int = 50) -> list[dict]:
    """GET /channels/{id}/messages?after=<id>&limit=N -> list of message dicts (newest first).

    Returns list sorted oldest-first for easier downstream processing.
    """
    url = f'{DISCORD_API}/channels/{channel_id}/messages'
    params = {'limit': limit}
    if after_id:
        params['after'] = after_id
    headers = {'Authorization': token, 'User-Agent': USER_AGENT}
    r = requests.get(url, headers=headers, params=params, timeout=15)
    if r.status_code == 429:
        retry_after = float(r.headers.get('Retry-After', '5'))
        print(f'[rate-limit] channel {channel_id}: sleeping {retry_after}s', flush=True)
        time.sleep(retry_after + 0.5)
        return []
    if r.status_code == 401:
        raise RuntimeError('Discord auth failed (401). Token invalid or expired.')
    if r.status_code == 403:
        raise RuntimeError(f'Discord 403 for channel {channel_id}. No access or missing permission.')
    r.raise_for_status()
    msgs = r.json()
    msgs.sort(key=lambda m: int(m['id']))   # oldest first
    return msgs


def msg_to_record(msg: dict) -> str:
    """Convert one Discord API message dict into a single raw-text record string that
    the existing parse_discord_signal regex stack can consume.
    """
    author = msg.get('author', {})
    author_id = author.get('id', '0')
    author_name = author.get('username', 'unknown')
    timestamp = msg.get('timestamp', '')   # ISO-8601 with offset
    content = msg.get('content', '') or ''
    # The existing parser tolerates extra quoting/escaping; mimic the DCE CSV shape:
    # first line of content goes into the same line as the metadata wrapped in "..."
    lines = content.splitlines()
    first = lines[0] if lines else ''
    rest = '\n'.join(lines[1:]) if len(lines) > 1 else ''
    record = (
        f'"{author_id},""{author_name}"",""{timestamp}"",""{first}"\n'
        + (rest + '\n' if rest else '')
        + '","",""""'
    )
    return record


def _safe_channel_alias(name: str) -> str:
    """Sanitize channel name -> short alnum upper alias for MT comment."""
    return ''.join(c for c in name.upper() if c.isalnum())[:12] or 'CH'


def append_inbox_row(csv_path: Path, our_msg_id: int, time_utc, channel: str,
                     symbol: str, side: str, entry: float, sl: float, tps: list[float]) -> None:
    """Append one signal row to the live inbox CSV (in MT-friendly format)."""
    csv_path.parent.mkdir(parents=True, exist_ok=True)
    new_file = not csv_path.exists()
    mt5_time = time_utc.strftime('%Y.%m.%d %H:%M:%S')
    tps_str = '|'.join(f'{t:.5f}' for t in tps)
    alias = _safe_channel_alias(channel)
    with open(csv_path, 'a', newline='', encoding='ascii') as f:
        w = csv.writer(f)
        if new_file:
            w.writerow(['id', 'time_mt5', 'channel', 'symbol', 'side', 'entry', 'sl', 'n_tps', 'tps'])
        w.writerow([our_msg_id, mt5_time, alias, symbol, side,
                    f'{entry:.5f}', f'{sl:.5f}', len(tps), tps_str])


def process_new_messages(cfg: dict, state: dict) -> int:
    """One poll cycle. Fetch all configured channels, parse, dedup, append.

    Returns number of new signals written.
    """
    written = 0
    inbox_csv = Path(cfg['out_csv'])
    only_symbol = cfg.get('symbol_filter', 'XAUUSD')

    # Per-channel parse + accumulate
    fresh_parsed = []
    for ch in cfg['channels']:
        ch_id = str(ch['id'])
        last_id = state['last_msg_id_by_channel'].get(ch_id)
        try:
            msgs = fetch_messages(cfg['token'], ch_id, after_id=last_id)
        except Exception as e:
            print(f'[fetch-error] channel {ch_id} ({ch.get("name", "?")}): {e}', flush=True)
            continue
        if not msgs:
            continue
        for m in msgs:
            rec = msg_to_record(m)
            sig = parse_discord_signal(rec, idx=0, source=ch.get('name', ch_id))
            if sig is None:
                # Not a tradable signal (no symbol / no side / no entry etc.) - skip
                pass
            else:
                fresh_parsed.append(sig)
            state['last_msg_id_by_channel'][ch_id] = m['id']
        print(f'[poll] channel {ch.get("name", ch_id)}: got {len(msgs)} new msg(s); '
              f'parseable signals: {sum(1 for m in msgs if parse_discord_signal(msg_to_record(m), 0, "x") is not None)}', flush=True)

    if not fresh_parsed:
        return 0

    # Apply typo + cancellation to the fresh batch only (in isolation; long-term
    # could merge with recent history for better cancellation context)
    cleaned, typo_stats = typo_check_and_repair(fresh_parsed)
    cancel_stats = apply_cancellations(cleaned)

    survivors = [s for s in cleaned if not s.skip_reason and s.symbol == only_symbol]
    if typo_stats.get('repaired-sl', 0) or typo_stats.get('rejected-bad-sl', 0) or typo_stats.get('rejected-bad-entry', 0):
        print(f'[clean] typo: {typo_stats}', flush=True)
    if cancel_stats.get('canceled', 0):
        print(f'[clean] cancel: {cancel_stats}', flush=True)

    for s in survivors:
        our_id = state.get('next_our_msg_id', 0)
        # s.source_file was set to channel.name during parse
        append_inbox_row(inbox_csv, our_id, s.time_utc, s.source_file,
                         s.symbol, s.side, s.entry, s.sl, s.tps[:15])
        print(f'[written] id={our_id} ch={_safe_channel_alias(s.source_file)} '
              f'{s.time_utc} {s.symbol} {s.side} entry={s.entry} sl={s.sl} tps={len(s.tps)}', flush=True)
        state['next_our_msg_id'] = our_id + 1
        written += 1
    return written


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--config', type=Path, required=True,
                    help='JSON config file (see discord_poller_config.example.json)')
    ap.add_argument('--once', action='store_true', help='Single poll cycle then exit')
    args = ap.parse_args()

    cfg = load_config(args.config)
    state_path = Path(cfg.get('state_file', 'discord_poller_state.json'))
    interval = int(cfg.get('poll_interval_sec', 5))

    print(f'[start] DiscoSignalPoller; channels={[c.get("name", c["id"]) for c in cfg["channels"]]} '
          f'inbox={cfg["out_csv"]} interval={interval}s', flush=True)

    state = load_state(state_path)
    while _running:
        try:
            n = process_new_messages(cfg, state)
            if n:
                save_state(state_path, state)
        except KeyboardInterrupt:
            break
        except Exception as e:
            print(f'[error] poll cycle: {e}', flush=True)
        if args.once:
            break
        save_state(state_path, state)
        time.sleep(interval)

    print('[stop] saving state and exiting', flush=True)
    save_state(state_path, state)


if __name__ == '__main__':
    main()
