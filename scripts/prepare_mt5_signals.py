#!/usr/bin/env python3
"""
Convert Discord chat export -> MT5-friendly CSV the EA can FileOpen.

Pipeline:
  1. Parse Discord CSV (reuses replay_discord_signals.parse_discord_csv)
  2. Apply typo detection + 1-digit auto-repair
  3. Apply opposite-direction cancellation
  4. Drop rejected/canceled signals
  5. Write a clean CSV in MT5 datetime format to MT5/MQL5/Files/disco/

Output schema (one signal per row, semicolon-separated TPs):
  id,time_mt5,symbol,side,entry,sl,n_tps,tps
  1,2026.03.26 07:43:56,XAUUSD,SELL,4459.5,4480.0,3,4456.4|4452.3|4439.0
"""
import argparse
import csv
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).parent))
from replay_discord_signals import (
    parse_discord_csv, typo_check_and_repair, apply_cancellations,
    SIGNALS_DIR_DEFAULT,
)

# Default MT5 destination: RoboForex terminal data folder
MT5_FILES_DIR_DEFAULT = Path(
    'C:/Users/nikof/AppData/Roaming/MetaQuotes/Terminal/'
    '5FFA568149E88FCD5B44D926DCFEAA79/MQL5/Files/disco'
)

MAX_TPS = 15  # cap; signals beyond this are truncated


def discord_to_mt5_csv(src: Path, dst_dir: Path, only_symbol: str = 'XAUUSD') -> dict:
    """Process one Discord CSV and write a clean MT5 CSV.

    Returns stats dict.
    """
    raw = parse_discord_csv(src)
    sigs, typo_stats = typo_check_and_repair(raw)
    cancel_stats = apply_cancellations(sigs)

    surviving = [s for s in sigs if not s.skip_reason and s.symbol == only_symbol]
    surviving.sort(key=lambda s: s.time_utc)

    dst_dir.mkdir(parents=True, exist_ok=True)
    out_path = dst_dir / f'{src.stem}_processed.csv'
    # Channel alias = file stem upper-cased, sanitized for MT comment use
    channel_alias = ''.join(c for c in src.stem.upper() if c.isalnum())[:12]
    with open(out_path, 'w', newline='', encoding='ascii') as f:
        w = csv.writer(f)
        w.writerow(['id', 'time_mt5', 'channel', 'symbol', 'side', 'entry', 'sl', 'n_tps', 'tps'])
        for s in surviving:
            tps = s.tps[:MAX_TPS]
            mt5_time = s.time_utc.strftime('%Y.%m.%d %H:%M:%S')
            tps_str = '|'.join(f'{t:.5f}' for t in tps)
            w.writerow([s.msg_idx, mt5_time, channel_alias, s.symbol, s.side,
                        f'{s.entry:.5f}', f'{s.sl:.5f}', len(tps), tps_str])

    return {
        'src': str(src),
        'dst': str(out_path),
        'raw_count': len(raw),
        'surviving_count': len(surviving),
        'typo_stats': typo_stats,
        'cancel_stats': cancel_stats,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--signals-dir', type=Path, default=SIGNALS_DIR_DEFAULT)
    ap.add_argument('--out-dir', type=Path, default=MT5_FILES_DIR_DEFAULT,
                    help='MT5 Files folder (default: RoboForex terminal disco/ subdir)')
    ap.add_argument('--files', nargs='+', default=['signals1.csv', 'tnfx.csv'])
    ap.add_argument('--symbol', default='XAUUSD',
                    help='Only export signals for this symbol (default XAUUSD)')
    args = ap.parse_args()

    print(f'Output dir: {args.out_dir}')
    print()
    for fname in args.files:
        src = args.signals_dir / fname
        print(f'=== {fname} ===')
        stats = discord_to_mt5_csv(src, args.out_dir, args.symbol)
        print(f'  raw parsed:   {stats["raw_count"]}')
        print(f'  typo:         {stats["typo_stats"]}')
        print(f'  cancellation: {stats["cancel_stats"]}')
        print(f'  surviving {args.symbol}: {stats["surviving_count"]}')
        print(f'  -> {stats["dst"]}')
        print()


if __name__ == '__main__':
    main()
