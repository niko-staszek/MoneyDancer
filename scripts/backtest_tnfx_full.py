#!/usr/bin/env python3
"""
Backtest the full TNFX historical signal set (parse_tnfx_html.py output) against
Duka XAU tick data for the window we have ticks (2025-01-01 .. 2026-05-15).

Reuses fill / exit / sizing logic from replay_telegram_signals.py.
"""
import argparse
import csv
import sys
from collections import namedtuple
from datetime import datetime
from pathlib import Path

import numpy as np
import pandas as pd

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

sys.path.insert(0, str(Path(__file__).parent))
from replay_telegram_signals import (
    load_ticks, find_fill_for_entry, precompute_crossings,
    walk_to_exit, compute_lot, pnl_signal,
    COMMISSION_PER_LOT_RT, LATENCY_S, FILL_VALIDITY_H, WALK_HORIZON_H,
    STARTING_BALANCE,
)
from replay_discord_signals import discover_optimal_sizing, DD_CEILING_PCT

ParsedSig = namedtuple('ParsedSig', 'msg_idx time_utc side entry sl tps channel')

TICK_FILES = {
    'duka': 'XAUUSD_2025.csv',
    'duka_2026': 'XAUUSD_2026_jan-may.csv',
}

# Risk sweep — extend to expose flat-Sharpe behaviour if it scales
RISK_LEVELS = [0.1, 0.25, 0.5, 1.0, 2.0, 3.0, 5.0, 7.5, 10.0, 15.0, 20.0]
EXIT_POLICIES = ['scale_out', 'tp1_be', 'tp1_only', 'tp1_be_unbounded', 'tp1_be_full',
                 'tp2_only', 'tp3_only', 'tplast_only']


def load_signals_csv(path: Path) -> list:
    """Load the 9-col canonical CSV produced by parse_tnfx_html.py."""
    sigs = []
    with open(path, 'r', encoding='ascii') as f:
        r = csv.DictReader(f)
        for row in r:
            time_utc = pd.to_datetime(row['time_mt5'], format='%Y.%m.%d %H:%M:%S', utc=True)
            tps = [float(x) for x in row['tps'].split('|') if x]
            sigs.append(ParsedSig(
                msg_idx=int(row['id']),
                time_utc=time_utc,
                side=row['side'],
                entry=float(row['entry']),
                sl=float(row['sl']),
                tps=tps,
                channel=row['channel'],
            ))
    return sigs


def load_ticks_window(tick_root: Path, start: str, end: str):
    """Load duka XAU ticks across both year files, concatenate, return single DataFrame."""
    parts = []
    for tag, fname in TICK_FILES.items():
        fp = tick_root / fname
        if not fp.exists():
            print(f'  WARN: missing {fp}')
            continue
        print(f'  loading {fname}...', flush=True)
        t0 = datetime.now()
        df = load_ticks(fp, start, end)
        dt = (datetime.now() - t0).total_seconds()
        print(f'    {len(df):,} ticks in {dt:.1f}s')
        parts.append(df)
    full = pd.concat(parts, ignore_index=True).sort_values('utc_datetime').reset_index(drop=True)
    print(f'  combined: {len(full):,} ticks')
    return full


def run_backtest(sigs: list, ticks: pd.DataFrame) -> pd.DataFrame:
    """For each (sig, policy, risk), walk and record outcome."""
    ts_arr = ticks['utc_datetime'].values
    rows = []
    n_combos = len(EXIT_POLICIES) * len(RISK_LEVELS)
    combo_i = 0
    for policy in EXIT_POLICIES:
        for risk_pct in RISK_LEVELS:
            combo_i += 1
            equity = STARTING_BALANCE
            for s in sigs:
                fill_idx, fill_time, fill_price, fill_kind = find_fill_for_entry(
                    ticks, s.time_utc, LATENCY_S, s.side, s.entry)
                eq_pre = equity
                if fill_idx is None:
                    rows.append({
                        'msg_idx': s.msg_idx, 'time_utc': s.time_utc, 'channel': s.channel,
                        'side': s.side, 'entry': s.entry, 'sl': s.sl, 'n_tps': len(s.tps),
                        'fill_time': pd.NaT, 'fill_price': float('nan'), 'fill_kind': 'NEVER',
                        'exit_policy': policy, 'spread_profile': 'duka', 'risk_pct': risk_pct,
                        'equity_pre': round(eq_pre, 2), 'lot': 0.0,
                        'first_exit_label': 'NO_FILL', 'first_exit_sec': float('nan'),
                        'gross_pnl': 0.0, 'commission': 0.0, 'net_pnl': 0.0, 'net_pct': 0.0,
                        'equity_post': round(equity, 2),
                    })
                    continue

                sl_dist = abs(fill_price - s.sl)
                lot = compute_lot(risk_pct, equity, sl_dist)
                horizon = fill_time + pd.Timedelta(hours=WALK_HORIZON_H)
                horizon_idx = int(np.searchsorted(ts_arr, np.datetime64(horizon.tz_convert(None))))
                walk_view = ticks.iloc[fill_idx + 1:horizon_idx]
                if walk_view.empty:
                    continue
                sl_idx, tp_idxs = precompute_crossings(walk_view, s.side, s.sl, s.tps)
                exits = walk_to_exit(policy, sl_idx, tp_idxs, s.sl, s.tps,
                                      walk_view, s.side, fill_price)
                gross, comm, net = pnl_signal(fill_price, s.side, lot, exits, COMMISSION_PER_LOT_RT)
                equity += net

                first_exit_idx, _, _, first_label = exits[0]
                first_exit_time = walk_view['utc_datetime'].iloc[first_exit_idx]
                secs_to_first = (first_exit_time - fill_time).total_seconds()

                rows.append({
                    'msg_idx': s.msg_idx, 'time_utc': s.time_utc, 'channel': s.channel,
                    'side': s.side, 'entry': s.entry, 'sl': s.sl, 'n_tps': len(s.tps),
                    'fill_time': fill_time, 'fill_price': round(float(fill_price), 3),
                    'fill_kind': fill_kind,
                    'exit_policy': policy, 'spread_profile': 'duka', 'risk_pct': risk_pct,
                    'equity_pre': round(eq_pre, 2), 'lot': lot,
                    'first_exit_label': first_label,
                    'first_exit_sec': round(secs_to_first, 1),
                    'gross_pnl': round(gross, 2), 'commission': round(comm, 2),
                    'net_pnl': round(net, 2), 'net_pct': round(net / eq_pre * 100, 3),
                    'equity_post': round(equity, 2),
                })
            print(f'  [{combo_i:2d}/{n_combos}] {policy} / {risk_pct}% -> equity {equity:,.0f}', flush=True)
    return pd.DataFrame(rows)


def reverse_signals(sigs: list) -> list:
    """Mirror every signal across its entry: BUY<->SELL, SL/TPs reflected.
    Tests the 'fade the provider' hypothesis - if provider has negative alpha,
    reversing turns it positive.
    """
    out = []
    for s in sigs:
        new_side = 'SELL' if s.side == 'BUY' else 'BUY'
        new_sl = 2 * s.entry - s.sl
        new_tps = sorted([2 * s.entry - tp for tp in s.tps],
                         key=lambda tp: abs(tp - s.entry))
        out.append(ParsedSig(
            msg_idx=s.msg_idx, time_utc=s.time_utc, side=new_side,
            entry=s.entry, sl=new_sl, tps=new_tps,
            channel=s.channel + 'R',
        ))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--signals', type=Path, default=Path('runs/tnfx_full/tnfx_full_signals.csv'))
    ap.add_argument('--tick-root', type=Path, default=Path('data/duka'))
    ap.add_argument('--out', type=Path, default=Path('runs/tnfx_full'))
    ap.add_argument('--window-start', default='2025-01-01 00:00:00')
    ap.add_argument('--window-end',   default='2026-05-17 00:00:00')
    ap.add_argument('--reverse', action='store_true',
                    help='Flip BUY<->SELL on every signal (fade-the-provider test)')
    args = ap.parse_args()

    args.out.mkdir(parents=True, exist_ok=True)

    print(f'Loading signals from {args.signals}')
    sigs = load_signals_csv(args.signals)
    print(f'  total parsed: {len(sigs)}')

    # Filter to tick window
    t0 = pd.Timestamp(args.window_start, tz='UTC')
    t1 = pd.Timestamp(args.window_end, tz='UTC')
    in_window = [s for s in sigs if t0 <= s.time_utc < t1]
    print(f'  in window [{args.window_start} .. {args.window_end}]: {len(in_window)}')
    sigs = sorted(in_window, key=lambda s: s.time_utc)

    if args.reverse:
        sigs = reverse_signals(sigs)
        print(f'  REVERSED: all BUY<->SELL flipped, SL/TPs mirrored across entry')
        # Save outputs under separate suffix to avoid overwriting baseline
        args.out = args.out.parent / (args.out.name + '_reversed')
        args.out.mkdir(parents=True, exist_ok=True)

    print(f'\nLoading tick data:')
    ticks = load_ticks_window(args.tick_root, args.window_start, args.window_end)

    print(f'\nRunning backtest matrix...')
    outcomes = run_backtest(sigs, ticks)
    out_csv = args.out / 'signal_outcomes.csv'
    outcomes.to_csv(out_csv, index=False)
    print(f'Wrote {len(outcomes)} outcome rows -> {out_csv.name}')

    # Daily aggregation
    outcomes['date'] = pd.to_datetime(outcomes['time_utc']).dt.date
    daily = (outcomes.groupby(['date', 'spread_profile', 'exit_policy', 'risk_pct'], as_index=False)
             .agg(n_signals=('msg_idx', 'count'),
                  daily_net_pnl=('net_pnl', 'sum'),
                  starting_equity=('equity_pre', 'first'),
                  ending_equity=('equity_post', 'last')))
    daily['daily_pnl_pct'] = (daily['daily_net_pnl'] / daily['starting_equity'] * 100).round(3)
    daily.to_csv(args.out / 'daily_pnl.csv', index=False)
    print(f'Wrote {len(daily)} daily rows -> daily_pnl.csv')

    # Sizing discovery (re-use from replay_discord_signals)
    daily['hit_3pct'] = daily['daily_pnl_pct'] >= 3.0
    daily['hit_5pct'] = daily['daily_pnl_pct'] >= 5.0
    sizing = discover_optimal_sizing(daily)
    sizing.to_csv(args.out / 'sizing_discovery.csv', index=False)
    print(f'Wrote {len(sizing)} sizing rows -> sizing_discovery.csv')

    # Quick console verdict
    print('\n========== TL;DR ==========')
    safe = sizing[sizing['within_dd_ceiling']]
    if safe.empty:
        print(f'NO config keeps DD under {DD_CEILING_PCT}%. Pure risk-reward problem.')
        safe = sizing
    best_tr = safe.sort_values('total_return_pct', ascending=False).head(1).iloc[0]
    best_sh = safe.sort_values('sharpe_proxy', ascending=False).head(1).iloc[0]
    print(f'Best total return within DD ceiling: {best_tr["total_return_pct"]:+.2f}% '
          f'({best_tr["exit_policy"]}/{best_tr["risk_pct"]}%), max DD {best_tr["max_dd_pct"]:.1f}%')
    print(f'Best Sharpe within DD ceiling:       {best_sh["sharpe_proxy"]:.2f} '
          f'({best_sh["exit_policy"]}/{best_sh["risk_pct"]}%)')

    # Top 10 by total return
    print('\nTop 10 configs by total return:')
    head = sizing.sort_values('total_return_pct', ascending=False).head(10)
    for _, r in head.iterrows():
        flag = '' if r['within_dd_ceiling'] else ' BREACHES-DD'
        print(f"  {r['exit_policy']:<10} risk={r['risk_pct']:>5.2f}%  "
              f"total={r['total_return_pct']:+7.2f}%  "
              f"DD={r['max_dd_pct']:5.1f}%  "
              f"Sharpe={r['sharpe_proxy']:5.2f}  "
              f"days+={int(r['days_pos']):3d}/{int(r['n_days']):3d}  "
              f"d>=3%={int(r['days_ge_3pct']):3d}{flag}")


if __name__ == '__main__':
    main()
