"""For each APL signal, find the time at which Duka mid was closest to the
stated Entry, in a wide window before/after the signal timestamp.

If entries match a PRE-signal-time tick (mid ≈ entry at signal_time - X seconds),
that supports the "trader-composed-message-then-price-moved" hypothesis.
If entries match a FUTURE tick (mid ≈ entry at signal_time + X seconds), pending
order. If neither matches anywhere within ±some_hours, the entry is genuinely a
level price has to reach.
"""
import pandas as pd
import numpy as np
from pathlib import Path

# Reuse from main script
import sys
sys.path.insert(0, str(Path(__file__).parent))
from replay_telegram_signals import SIGNALS, load_ticks  # type: ignore

TICK_PATH = Path('data/duka/XAUUSD_2026_jan-may.csv')
TZ_OFFSET = 2

# Load ticks once for the 3-day window
print("Loading duka ticks (3-day window)...")
ticks = load_ticks(TICK_PATH, '2026-03-17 00:00:00', '2026-03-21 00:00:00')
ticks['mid'] = (ticks['bid'] + ticks['ask']) / 2
ts = ticks['utc_datetime'].values
mids = ticks['mid'].values
print(f"  {len(ticks):,} ticks loaded")
print()

# For each signal, find the time in [signal_time - 2h, signal_time + 2h] where mid is closest to entry.
WINDOW_BEFORE_S = 2 * 3600   # 2 hours pre-signal
WINDOW_AFTER_S = 60          # 1 minute post-signal (the "what came after" check is the main backtest)

print("For each signal: time in [signal - 2h, signal + 1min] where mid was closest to Entry")
print(f"  {'id':>3} {'side':<5} {'sig_time':<20} {'entry':>8}  -> {'closest_time':<24} {'mid':>8}  {'delta':>7} {'sec_offset':>11}")
for s in SIGNALS:
    sig_time = pd.Timestamp(s['time_local'], tz='UTC') - pd.Timedelta(hours=TZ_OFFSET)
    win_start = sig_time - pd.Timedelta(seconds=WINDOW_BEFORE_S)
    win_end = sig_time + pd.Timedelta(seconds=WINDOW_AFTER_S)
    i_start = int(np.searchsorted(ts, np.datetime64(win_start.tz_convert(None))))
    i_end = int(np.searchsorted(ts, np.datetime64(win_end.tz_convert(None))))
    if i_end <= i_start:
        print(f"  {s['id']:>3} (no ticks in window)")
        continue
    window_mids = mids[i_start:i_end]
    window_ts = ts[i_start:i_end]
    delta_abs = np.abs(window_mids - s['entry'])
    best_rel = int(np.argmin(delta_abs))
    best_mid = window_mids[best_rel]
    best_time = window_ts[best_rel]
    best_delta = best_mid - s['entry']
    sec_offset = (pd.Timestamp(best_time) - sig_time.tz_convert(None)).total_seconds()
    print(f"  {s['id']:>3} {s['side']:<5} {str(sig_time)[:19]:<20} {s['entry']:>8.2f}  -> "
          f"{str(best_time)[:23]:<24} {best_mid:>8.2f}  {best_delta:>+7.2f} {sec_offset:>+11.1f}s")

print()
print("Interpretation:")
print("  sec_offset NEGATIVE = mid matched entry BEFORE signal time (composed-then-posted lag)")
print("  sec_offset POSITIVE = mid matched entry AFTER signal time (pending order fill)")
print("  large |delta| = entry never close to current mid in this 2h window")
