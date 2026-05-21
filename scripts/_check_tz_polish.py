"""Compare UTC+1 (Polish CET, winter) vs UTC+2 (CEST, summer / EE winter).
Run the same lag analysis at both offsets to see which fits better.
"""
import pandas as pd
import numpy as np
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).parent))
from replay_telegram_signals import SIGNALS, load_ticks  # type: ignore

TICK_PATH = Path('data/duka/XAUUSD_2026_jan-may.csv')
print("Loading duka ticks (3-day window)...")
ticks = load_ticks(TICK_PATH, '2026-03-17 00:00:00', '2026-03-21 00:00:00')
ticks['mid'] = (ticks['bid'] + ticks['ask']) / 2
ts = ticks['utc_datetime'].values
mids = ticks['mid'].values
print(f"  {len(ticks):,} ticks loaded")
print()

WINDOW_S = 2 * 3600   # ±2h window

print("For each tz hypothesis, find best-matching mid for each signal entry within ±2h:")
print()

for tz_offset in [0, 1, 2, 3, -4, -5]:
    print(f"=== TZ = UTC+{tz_offset} ===")
    print(f"  {'id':>3} {'side':<5} {'utc_time':<20} {'entry':>8}  best_match_utc           mid    delta   sec_off  abs_at_sig_time")
    sum_abs_delta = 0.0
    sum_abs_delta_at_sig = 0.0
    sum_abs_delta_small = 0.0  # only signals where best-fit delta is small (market-style)
    for s in SIGNALS:
        sig_time = pd.Timestamp(s['time_local'], tz='UTC') - pd.Timedelta(hours=tz_offset)
        win_start = sig_time - pd.Timedelta(seconds=WINDOW_S)
        win_end = sig_time + pd.Timedelta(seconds=WINDOW_S)
        i_start = int(np.searchsorted(ts, np.datetime64(win_start.tz_convert(None))))
        i_end = int(np.searchsorted(ts, np.datetime64(win_end.tz_convert(None))))
        if i_end <= i_start:
            continue
        wm = mids[i_start:i_end]
        wt = ts[i_start:i_end]
        delta_abs = np.abs(wm - s['entry'])
        best_rel = int(np.argmin(delta_abs))
        best_mid = wm[best_rel]
        best_time = wt[best_rel]
        best_delta = best_mid - s['entry']
        sec_offset = (pd.Timestamp(best_time) - sig_time.tz_convert(None)).total_seconds()

        # Also mid at signal time + 3s (current logic's reconciliation point)
        sig_plus_3 = sig_time + pd.Timedelta(seconds=3)
        i_sig = int(np.searchsorted(ts, np.datetime64(sig_plus_3.tz_convert(None))))
        i_sig = min(i_sig, len(mids) - 1)
        mid_at_sig = mids[i_sig]
        delta_at_sig = abs(mid_at_sig - s['entry'])

        sum_abs_delta += abs(best_delta)
        sum_abs_delta_at_sig += delta_at_sig
        if abs(best_delta) < 1.0:
            sum_abs_delta_small += abs(best_delta)
        print(f"  {s['id']:>3} {s['side']:<5} {str(sig_time)[:19]:<20} {s['entry']:>8.2f}  "
              f"{str(best_time)[:19]:<20} {best_mid:>8.2f} {best_delta:>+7.2f} {sec_offset:>+8.0f}s "
              f"  {delta_at_sig:>10.2f}")
    print(f"  ---")
    print(f"  Sum |best-fit delta| across 10: {sum_abs_delta:.2f}")
    print(f"  Sum |delta at sig+3s|:        {sum_abs_delta_at_sig:.2f}   (this is what auto-detect uses)")
    print()
