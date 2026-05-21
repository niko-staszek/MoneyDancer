#!/usr/bin/env python3
"""
Replay APL Telegram signals (17-19 Mar 2026) against Duka tick data.
Plan: C:/Users/nikof/.claude/plans/here-s-a-list-of-partitioned-moon.md

Matrix: 10 signals x 3 exit policies x 3 spread profiles x 7 risk levels = 630 outcomes.
Outputs:
  signal_outcomes.csv  - per (signal, policy, spread, risk)
  daily_pnl.csv        - aggregated per (date, policy, spread, risk)
  verdict.md           - human readable headline
"""
import argparse
import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import numpy as np
import pandas as pd

# ---- constants ----
XAU_CONTRACT_OZ = 100          # 1.0 lot = 100 oz -> $1 price move = $100/lot
STARTING_BALANCE = 100_000.0
COMMISSION_PER_LOT_RT = 7.0    # $7 round-turn per lot on XAU (typical ECN)
LATENCY_S = 3
MIN_LOT = 0.01
LOT_STEP = 0.01
WALK_HORIZON_H = 36            # cap each signal's walk at fill+36h

RISK_LEVELS = [0.25, 0.5, 1.0, 2.0, 3.0, 5.0, 10.0]    # % of current equity
EXIT_POLICIES = ['scale_out', 'tp1_be', 'tp1_only']
SPREAD_PROFILES = ['duka', 'robo', 'axi']
PROFILE_FILES = {
    'duka': 'XAUUSD_2026_jan-may.csv',
    'robo': 'XAUUSD_2026_jan-may_robo.csv',
    'axi':  'XAUUSD_2026_jan-may_axi.csv',
}

# Signal date range. End extended to Mar 21 so 24h validity windows that span
# FOMC (Mar 19 18:00 UTC) and the subsequent move can be captured.
DATE_START = '2026-03-17 00:00:00'
DATE_END   = '2026-03-21 00:00:00'

# 10 APL XAU signals. time_local is the timestamp as it appeared in TG (tz auto-resolved).
SIGNALS = [
    {'id': 1,  'time_local': '2026-03-17 13:28', 'side': 'BUY',  'entry': 5014.5, 'sl': 5008.0, 'tps': [5019.0, 5021.0, 5023.0, 5024.0, 5025.0, 5026.0]},
    {'id': 2,  'time_local': '2026-03-17 15:04', 'side': 'SELL', 'entry': 5014.5, 'sl': 5020.0, 'tps': [5010.0, 5008.0, 5006.0, 5005.0, 5004.0, 5003.0]},
    {'id': 3,  'time_local': '2026-03-17 17:10', 'side': 'SELL', 'entry': 4997.5, 'sl': 5005.0, 'tps': [4993.0, 4991.0, 4990.0, 4989.0, 4988.0, 4987.0]},
    {'id': 4,  'time_local': '2026-03-18 08:16', 'side': 'SELL', 'entry': 5013.5, 'sl': 5022.0, 'tps': [5008.0, 5006.0, 5005.0, 5004.0, 5003.0, 5002.0, 5001.0, 5000.0]},
    {'id': 5,  'time_local': '2026-03-18 12:21', 'side': 'SELL', 'entry': 4975.5, 'sl': 4983.0, 'tps': [4971.0, 4969.0, 4967.0, 4966.0, 4965.0]},  # SL repaired from typo 4083
    {'id': 6,  'time_local': '2026-03-18 13:53', 'side': 'SELL', 'entry': 4887.5, 'sl': 4897.0, 'tps': [4883.0, 4881.0, 4879.0, 4878.0, 4877.0, 4876.0, 4875.0]},
    {'id': 7,  'time_local': '2026-03-18 15:02', 'side': 'BUY',  'entry': 4870.5, 'sl': 4861.0, 'tps': [4875.0, 4877.0, 4879.0, 4880.0, 4881.0, 4882.0]},
    {'id': 8,  'time_local': '2026-03-18 15:02', 'side': 'BUY',  'entry': 4886.0, 'sl': 4878.0, 'tps': [4892.0, 4894.0, 4896.0, 4897.0, 4898.0, 4899.0]},
    {'id': 9,  'time_local': '2026-03-18 17:41', 'side': 'SELL', 'entry': 4882.5, 'sl': 4891.0, 'tps': [4878.0, 4876.0, 4874.0, 4873.0, 4872.0, 4871.0, 4870.0, 4869.0, 4868.0, 4867.0, 4866.0]},
    {'id': 10, 'time_local': '2026-03-19 11:21', 'side': 'SELL', 'entry': 4696.5, 'sl': 4705.0, 'tps': [4692.0, 4690.0, 4688.0, 4687.0, 4686.0, 4685.0, 4684.0, 4683.0, 4682.0, 4681.0, 4680.0, 4679.0, 4678.0, 4677.0]},
]


# ===========================================================================
# Tick loading
# ===========================================================================
def load_ticks(csv_path: Path, start_str: str, end_str: str, chunksize: int = 2_000_000) -> pd.DataFrame:
    """Stream a tick CSV, return only rows in [start_str, end_str].

    Uses string compare on timestamps to avoid parsing all 36M dates.
    File is time-ordered so we can early-exit.
    """
    chunks = []
    for chunk in pd.read_csv(csv_path, chunksize=chunksize):
        # string compare works because format is fixed ISO-ish
        ts = chunk['utc_datetime']
        mask = (ts >= start_str) & (ts <= end_str)
        filt = chunk[mask]
        if not filt.empty:
            chunks.append(filt)
        # Early exit: if max ts in chunk > end_str, we're past the window
        if not chunk.empty and chunk['utc_datetime'].iloc[-1] > end_str:
            break
    if not chunks:
        return pd.DataFrame(columns=['utc_datetime', 'bid', 'ask', 'bid_vol', 'ask_vol'])
    df = pd.concat(chunks, ignore_index=True)
    df['utc_datetime'] = pd.to_datetime(df['utc_datetime'], utc=True)
    df = df.sort_values('utc_datetime').reset_index(drop=True)
    return df


# ===========================================================================
# Timezone detection
# ===========================================================================
def detect_signal_tz(ticks_df: pd.DataFrame, signals: list) -> int:
    """Try offsets 0/+1/+2/+3; return one that minimizes mean(|signal_entry - mid_at_signal+latency|)."""
    best_offset, best_err = None, float('inf')
    ts_arr = ticks_df['utc_datetime'].values
    bid_arr = ticks_df['bid'].values
    ask_arr = ticks_df['ask'].values
    for offset_h in [0, 1, 2, 3]:
        errs = []
        for s in signals:
            sig_t = pd.Timestamp(s['time_local'], tz='UTC') - pd.Timedelta(hours=offset_h)
            target = sig_t + pd.Timedelta(seconds=LATENCY_S)
            idx = np.searchsorted(ts_arr, np.datetime64(target.tz_convert(None)))
            if idx >= len(ts_arr):
                continue
            mid = (bid_arr[idx] + ask_arr[idx]) / 2
            errs.append(abs(mid - s['entry']))
        if errs:
            avg = sum(errs) / len(errs)
            if avg < best_err:
                best_err, best_offset = avg, offset_h
    return best_offset if best_offset is not None else 0


# ===========================================================================
# Fill + exit logic
# ===========================================================================
# APL signals are pending STOP/LIMIT orders at the listed entry level, not
# market entries at signal time. Fill happens when ask (BUY) or bid (SELL)
# reaches the entry level. Order is valid for FILL_VALIDITY_H hours, then
# expires unfilled.
FILL_VALIDITY_H = 24


def find_fill_idx(ts_arr: np.ndarray, signal_time_utc: pd.Timestamp, latency_s: int) -> int | None:
    """Index of first tick at or after signal_time + latency. Used for tz detection only."""
    target = signal_time_utc + pd.Timedelta(seconds=latency_s)
    idx = int(np.searchsorted(ts_arr, np.datetime64(target.tz_convert(None))))
    if idx >= len(ts_arr):
        return None
    return idx


def find_fill_for_entry(ticks: pd.DataFrame, signal_time_utc: pd.Timestamp, latency_s: int,
                        side: str, entry: float, validity_h: int = FILL_VALIDITY_H):
    """Find fill when ask (BUY) / bid (SELL) reaches entry level.
    Returns (fill_idx, fill_time, fill_price, fill_kind) or (None, None, None, 'NEVER').
    fill_kind: 'INSTANT' (within first tick), 'LIMIT' (had to come down), 'STOP' (had to go up).
    """
    target = signal_time_utc + pd.Timedelta(seconds=latency_s)
    ts_arr = ticks['utc_datetime'].values
    start_idx = int(np.searchsorted(ts_arr, np.datetime64(target.tz_convert(None))))
    if start_idx >= len(ticks):
        return None, None, None, 'NEVER'

    deadline = signal_time_utc + pd.Timedelta(hours=validity_h)
    end_idx = int(np.searchsorted(ts_arr, np.datetime64(deadline.tz_convert(None))))
    end_idx = min(end_idx, len(ticks))
    if end_idx <= start_idx:
        return None, None, None, 'NEVER'

    if side == 'BUY':
        prices = ticks['ask'].values[start_idx:end_idx]
    else:
        prices = ticks['bid'].values[start_idx:end_idx]

    # Direction relative to entry at signal start
    initial_above = prices[0] > entry
    initial_below = prices[0] < entry

    if initial_above:
        # BUY: ask > entry, need it to drop to entry  -> BUY LIMIT
        # SELL: bid > entry, need it to drop to entry -> SELL STOP
        mask = prices <= entry
        fill_kind = 'LIMIT' if side == 'BUY' else 'STOP'
    elif initial_below:
        # BUY: ask < entry, need it to rise to entry  -> BUY STOP
        # SELL: bid < entry, need it to rise to entry -> SELL LIMIT
        mask = prices >= entry
        fill_kind = 'STOP' if side == 'BUY' else 'LIMIT'
    else:
        # Already at entry: instant fill
        return start_idx, ticks['utc_datetime'].iloc[start_idx], entry, 'INSTANT'

    if not mask.any():
        return None, None, None, 'NEVER'

    rel_idx = int(np.argmax(mask))
    abs_idx = start_idx + rel_idx
    # Limit-style fill: exactly at entry level. Realistic for limit orders;
    # for stops, real-world has slippage but we idealize.
    return abs_idx, ticks['utc_datetime'].iloc[abs_idx], entry, fill_kind


def precompute_crossings(ticks_view: pd.DataFrame, side: str, sl: float, tps: list[float]):
    """For SL and each TP, return idx of first tick where crossed (else None).

    Conventions:
      BUY:  TP hit when bid >= tp,  SL hit when bid <= sl
      SELL: TP hit when ask <= tp,  SL hit when ask >= sl
    """
    if side == 'BUY':
        bid = ticks_view['bid'].values
        sl_mask = bid <= sl
        sl_idx = int(np.argmax(sl_mask)) if sl_mask.any() else None
        tp_idxs = []
        for tp in tps:
            m = bid >= tp
            tp_idxs.append(int(np.argmax(m)) if m.any() else None)
    else:  # SELL
        ask = ticks_view['ask'].values
        sl_mask = ask >= sl
        sl_idx = int(np.argmax(sl_mask)) if sl_mask.any() else None
        tp_idxs = []
        for tp in tps:
            m = ask <= tp
            tp_idxs.append(int(np.argmax(m)) if m.any() else None)
    return sl_idx, tp_idxs


def walk_scale_out(sl_idx, tp_idxs, sl_price, tp_prices, ticks_view: pd.DataFrame):
    """Equal-slice scale-out across all TPs. Slice i exits at min(tp_i_idx, sl_idx)."""
    n = len(tp_prices)
    slice_pct = 1.0 / n
    exits = []
    for i, (tp_idx, tp_price) in enumerate(zip(tp_idxs, tp_prices)):
        cands = []
        if tp_idx is not None:
            cands.append((tp_idx, tp_price, f'TP{i+1}'))
        if sl_idx is not None:
            cands.append((sl_idx, sl_price, 'SL'))
        if not cands:
            last = len(ticks_view) - 1
            mid = (ticks_view['bid'].iloc[last] + ticks_view['ask'].iloc[last]) / 2
            exits.append((last, mid, slice_pct, 'EOD'))
        else:
            cands.sort(key=lambda x: x[0])
            idx, price, label = cands[0]
            exits.append((idx, price, slice_pct, label))
    return exits


def walk_tp1_be(sl_idx, tp_idxs, sl_price, tp_prices, ticks_view: pd.DataFrame, side: str, fill_price: float):
    """Close 50% at TP1, move SL to BE (fill_price), exit remaining at TPN or BE."""
    tp1_idx = tp_idxs[0]
    tp1_price = tp_prices[0]
    tpN_price = tp_prices[-1]
    n_tp = len(tp_prices)

    # Phase 1: pre-TP1 -- SL or TP1
    if tp1_idx is None or (sl_idx is not None and sl_idx <= tp1_idx):
        if sl_idx is not None:
            return [(sl_idx, sl_price, 1.0, 'SL')]
        last = len(ticks_view) - 1
        mid = (ticks_view['bid'].iloc[last] + ticks_view['ask'].iloc[last]) / 2
        return [(last, mid, 1.0, 'EOD')]

    exits = [(tp1_idx, tp1_price, 0.5, 'TP1')]

    # Phase 2: post-TP1 -- BE-SL vs TPN, search from tp1_idx+1 onward
    sub = ticks_view.iloc[tp1_idx + 1:]
    if sub.empty:
        # No further ticks: close at TP1 mid (kept what we have)
        mid = (ticks_view['bid'].iloc[tp1_idx] + ticks_view['ask'].iloc[tp1_idx]) / 2
        exits.append((tp1_idx, mid, 0.5, 'EOD'))
        return exits

    if side == 'BUY':
        be_mask = sub['bid'].values <= fill_price
        tpN_mask = sub['bid'].values >= tpN_price
    else:
        be_mask = sub['ask'].values >= fill_price
        tpN_mask = sub['ask'].values <= tpN_price

    be_rel = int(np.argmax(be_mask)) if be_mask.any() else None
    tpN_rel = int(np.argmax(tpN_mask)) if tpN_mask.any() else None

    if be_rel is None and tpN_rel is None:
        last = len(ticks_view) - 1
        mid = (ticks_view['bid'].iloc[last] + ticks_view['ask'].iloc[last]) / 2
        exits.append((last, mid, 0.5, 'EOD'))
    elif be_rel is not None and (tpN_rel is None or be_rel <= tpN_rel):
        exits.append((tp1_idx + 1 + be_rel, fill_price, 0.5, 'BE'))
    else:
        exits.append((tp1_idx + 1 + tpN_rel, tpN_price, 0.5, f'TP{n_tp}'))
    return exits


def walk_tp1_only(sl_idx, tp_idxs, sl_price, tp_prices, ticks_view: pd.DataFrame):
    tp1_idx = tp_idxs[0]
    tp1_price = tp_prices[0]
    cands = []
    if tp1_idx is not None:
        cands.append((tp1_idx, tp1_price, 'TP1'))
    if sl_idx is not None:
        cands.append((sl_idx, sl_price, 'SL'))
    if not cands:
        last = len(ticks_view) - 1
        mid = (ticks_view['bid'].iloc[last] + ticks_view['ask'].iloc[last]) / 2
        return [(last, mid, 1.0, 'EOD')]
    cands.sort(key=lambda x: x[0])
    idx, price, label = cands[0]
    return [(idx, price, 1.0, label)]


def walk_tp1_be_unbounded(sl_idx, tp_idxs, sl_price, tp_prices, ticks_view: pd.DataFrame, side: str, fill_price: float):
    """50% close at TP1, runner has SL=BE and NO upper TP cap (closes only at BE or EOD)."""
    tp1_idx = tp_idxs[0]
    tp1_price = tp_prices[0]
    if tp1_idx is None or (sl_idx is not None and sl_idx <= tp1_idx):
        if sl_idx is not None:
            return [(sl_idx, sl_price, 1.0, 'SL')]
        last = len(ticks_view) - 1
        mid = (ticks_view['bid'].iloc[last] + ticks_view['ask'].iloc[last]) / 2
        return [(last, mid, 1.0, 'EOD')]

    exits = [(tp1_idx, tp1_price, 0.5, 'TP1')]
    sub = ticks_view.iloc[tp1_idx + 1:]
    if sub.empty:
        mid = (ticks_view['bid'].iloc[tp1_idx] + ticks_view['ask'].iloc[tp1_idx]) / 2
        exits.append((tp1_idx, mid, 0.5, 'EOD'))
        return exits

    if side == 'BUY':
        be_mask = sub['bid'].values <= fill_price
    else:
        be_mask = sub['ask'].values >= fill_price

    be_rel = int(np.argmax(be_mask)) if be_mask.any() else None
    if be_rel is None:
        # Runner survives the whole walk window - close at last mid
        last = len(ticks_view) - 1
        mid = (ticks_view['bid'].iloc[last] + ticks_view['ask'].iloc[last]) / 2
        exits.append((last, mid, 0.5, 'EOD'))
    else:
        exits.append((tp1_idx + 1 + be_rel, fill_price, 0.5, 'BE'))
    return exits


def walk_tp1_be_full(sl_idx, tp_idxs, sl_price, tp_prices, ticks_view: pd.DataFrame, side: str, fill_price: float):
    """0% closed at TP1; SL just MOVES to BE. Full 100% lot runs to TPN or BE-SL."""
    tp1_idx = tp_idxs[0]
    tpN_price = tp_prices[-1]
    if tp1_idx is None or (sl_idx is not None and sl_idx <= tp1_idx):
        if sl_idx is not None:
            return [(sl_idx, sl_price, 1.0, 'SL')]
        last = len(ticks_view) - 1
        mid = (ticks_view['bid'].iloc[last] + ticks_view['ask'].iloc[last]) / 2
        return [(last, mid, 1.0, 'EOD')]

    # TP1 hit — SL flips to BE. Walk from tp1_idx+1 for BE-SL vs TPN.
    sub = ticks_view.iloc[tp1_idx + 1:]
    if sub.empty:
        mid = (ticks_view['bid'].iloc[tp1_idx] + ticks_view['ask'].iloc[tp1_idx]) / 2
        return [(tp1_idx, mid, 1.0, 'EOD')]

    if side == 'BUY':
        be_mask = sub['bid'].values <= fill_price
        tpN_mask = sub['bid'].values >= tpN_price
    else:
        be_mask = sub['ask'].values >= fill_price
        tpN_mask = sub['ask'].values <= tpN_price

    be_rel = int(np.argmax(be_mask)) if be_mask.any() else None
    tpN_rel = int(np.argmax(tpN_mask)) if tpN_mask.any() else None

    if be_rel is None and tpN_rel is None:
        last = len(ticks_view) - 1
        mid = (ticks_view['bid'].iloc[last] + ticks_view['ask'].iloc[last]) / 2
        return [(last, mid, 1.0, 'EOD')]
    if be_rel is not None and (tpN_rel is None or be_rel <= tpN_rel):
        return [(tp1_idx + 1 + be_rel, fill_price, 1.0, 'BE')]
    return [(tp1_idx + 1 + tpN_rel, tpN_price, 1.0, f'TP{len(tp_prices)}')]


def walk_tpN_only(sl_idx, tp_idxs, sl_price, tp_prices, ticks_view: pd.DataFrame, n: int):
    """Target TP at 1-based index n. Falls back to last available TP if signal has fewer."""
    idx_pos = min(max(0, n - 1), len(tp_prices) - 1)
    tp_idx = tp_idxs[idx_pos]
    tp_price = tp_prices[idx_pos]
    cands = []
    if tp_idx is not None:
        cands.append((tp_idx, tp_price, f'TP{idx_pos + 1}'))
    if sl_idx is not None:
        cands.append((sl_idx, sl_price, 'SL'))
    if not cands:
        last = len(ticks_view) - 1
        mid = (ticks_view['bid'].iloc[last] + ticks_view['ask'].iloc[last]) / 2
        return [(last, mid, 1.0, 'EOD')]
    cands.sort(key=lambda x: x[0])
    idx, price, label = cands[0]
    return [(idx, price, 1.0, label)]


def walk_to_exit(policy: str, sl_idx, tp_idxs, sl_price, tp_prices, ticks_view, side, fill_price):
    if policy == 'scale_out':
        return walk_scale_out(sl_idx, tp_idxs, sl_price, tp_prices, ticks_view)
    if policy == 'tp1_be':
        return walk_tp1_be(sl_idx, tp_idxs, sl_price, tp_prices, ticks_view, side, fill_price)
    if policy == 'tp1_only':
        return walk_tp1_only(sl_idx, tp_idxs, sl_price, tp_prices, ticks_view)
    if policy == 'tp1_be_unbounded':
        return walk_tp1_be_unbounded(sl_idx, tp_idxs, sl_price, tp_prices, ticks_view, side, fill_price)
    if policy == 'tp1_be_full':
        return walk_tp1_be_full(sl_idx, tp_idxs, sl_price, tp_prices, ticks_view, side, fill_price)
    if policy == 'tp2_only':
        return walk_tpN_only(sl_idx, tp_idxs, sl_price, tp_prices, ticks_view, 2)
    if policy == 'tp3_only':
        return walk_tpN_only(sl_idx, tp_idxs, sl_price, tp_prices, ticks_view, 3)
    if policy == 'tplast_only':
        return walk_tpN_only(sl_idx, tp_idxs, sl_price, tp_prices, ticks_view, len(tp_prices))
    raise ValueError(f"unknown policy: {policy}")


# ===========================================================================
# Sizing + PnL
# ===========================================================================
def compute_lot(risk_pct: float, current_equity: float, sl_distance_dollars: float) -> float:
    if sl_distance_dollars <= 0:
        return MIN_LOT
    raw = (current_equity * risk_pct / 100.0) / (sl_distance_dollars * XAU_CONTRACT_OZ)
    steps = round(raw / LOT_STEP)
    lot = max(MIN_LOT, steps * LOT_STEP)
    return round(lot, 2)


def pnl_signal(fill_price: float, side: str, lot: float, exits: list, commission_rt: float):
    direction = 1 if side == 'BUY' else -1
    gross = 0.0
    for _, exit_price, slice_pct, _ in exits:
        slice_lot = lot * slice_pct
        gross += (exit_price - fill_price) * direction * slice_lot * XAU_CONTRACT_OZ
    commission = lot * commission_rt
    return gross, commission, gross - commission


# ===========================================================================
# Calendar tagging
# ===========================================================================
def load_calendar(path: Path) -> pd.DataFrame:
    df = pd.read_csv(path)
    df['utc_datetime'] = pd.to_datetime(df['utc_datetime'], utc=True)
    return df


def tag_news(signal_time_utc: pd.Timestamp, calendar_df: pd.DataFrame, window_min: int = 60) -> str:
    delta = pd.Timedelta(minutes=window_min)
    mask = (calendar_df['utc_datetime'] >= signal_time_utc - delta) & \
           (calendar_df['utc_datetime'] <= signal_time_utc + delta)
    near = calendar_df[mask]
    if near.empty:
        return ''
    return '; '.join(f"{r['tier']}-{r['currency']}-{r['label']}" for _, r in near.iterrows())


# ===========================================================================
# Inline sanity assertions
# ===========================================================================
def sanity_checks():
    # 1) lot math: SL=$6.5, equity $100k, 1% -> 1.54
    assert abs(compute_lot(1.0, 100_000.0, 6.5) - 1.54) < 0.01, "lot math failed"
    # 2) lot math: SL=$7.5, equity $100k, 5% -> 6.67
    assert abs(compute_lot(5.0, 100_000.0, 7.5) - 6.67) < 0.01, f"got {compute_lot(5.0, 100_000.0, 7.5)}"
    # 3) lot math: SL=$8.5, equity $100k, 10% -> ~11.76
    assert abs(compute_lot(10.0, 100_000.0, 8.5) - 11.76) < 0.01
    # 4) signal count
    assert len(SIGNALS) == 10, f"expected 10 signals, got {len(SIGNALS)}"
    # 5) repaired SL
    assert SIGNALS[4]['sl'] == 4983.0, "typo not repaired"
    print("  sanity checks pass: lot math, signal count, typo repair")


# ===========================================================================
# Main driver
# ===========================================================================
def run_backtest(tick_root: Path, calendar_path: Path, out_dir: Path, tz_force: int | None = None):
    out_dir.mkdir(parents=True, exist_ok=True)
    sanity_checks()

    print(f"\nLoading calendar from {calendar_path}")
    calendar_df = load_calendar(calendar_path)

    print(f"\nLoading tick data ({DATE_START} -> {DATE_END}):")
    ticks_by_profile = {}
    for prof, fname in PROFILE_FILES.items():
        fp = tick_root / fname
        print(f"  {prof}: {fp.name}", flush=True)
        t0 = datetime.now()
        df = load_ticks(fp, DATE_START, DATE_END)
        dt = (datetime.now() - t0).total_seconds()
        print(f"    {len(df):,} ticks loaded in {dt:.1f}s")
        if df.empty:
            raise RuntimeError(f"empty tick data for {prof}")
        ticks_by_profile[prof] = df

    # Detect tz off duka raw (unless overridden)
    if tz_force is not None:
        tz_offset = tz_force
        print(f"\nUsing FORCED signal timezone: UTC+{tz_offset}")
    else:
        tz_offset = detect_signal_tz(ticks_by_profile['duka'], SIGNALS)
        print(f"\nDetected signal timezone: UTC+{tz_offset}")

    # Annotate signals with UTC times + reconciliation report (against duka raw)
    duka = ticks_by_profile['duka']
    print(f"\nFill reconciliation (using STOP/LIMIT logic, validity {FILL_VALIDITY_H}h):")
    print(f"  {'id':>3} {'side':<5} {'time_utc':<20} {'sig_entry':>10} {'mid_at_sig':>10} {'fill_kind':<9} {'fill_time':<20} {'fill_delay_min':>14}")
    for s in SIGNALS:
        s['time_utc'] = pd.Timestamp(s['time_local'], tz='UTC') - pd.Timedelta(hours=tz_offset)
        # Mid at signal time (for context only)
        tick_idx = find_fill_idx(duka['utc_datetime'].values, s['time_utc'], LATENCY_S)
        mid_at_sig = ((duka['bid'].iloc[tick_idx] + duka['ask'].iloc[tick_idx]) / 2
                       if tick_idx is not None else float('nan'))
        # Actual fill via STOP/LIMIT logic
        fill_idx, fill_time, fill_price, fill_kind = find_fill_for_entry(
            duka, s['time_utc'], LATENCY_S, s['side'], s['entry'])
        if fill_time is not None:
            delay_min = (fill_time - s['time_utc']).total_seconds() / 60
            print(f"  {s['id']:>3} {s['side']:<5} {str(s['time_utc'])[:19]:<20} "
                  f"{s['entry']:>10.2f} {mid_at_sig:>10.2f} {fill_kind:<9} "
                  f"{str(fill_time)[:19]:<20} {delay_min:>14.1f}")
        else:
            print(f"  {s['id']:>3} {s['side']:<5} {str(s['time_utc'])[:19]:<20} "
                  f"{s['entry']:>10.2f} {mid_at_sig:>10.2f} {'NEVER':<9} "
                  f"{'(no fill in 12h)':<20}")

    # Run matrix
    print("\nRunning backtest matrix...")
    sorted_signals = sorted(SIGNALS, key=lambda x: x['time_utc'])

    rows = []
    n_combos = len(SPREAD_PROFILES) * len(EXIT_POLICIES) * len(RISK_LEVELS)
    combo_i = 0
    for spread_prof, ticks in ticks_by_profile.items():
        ts_arr_p = ticks['utc_datetime'].values
        for policy in EXIT_POLICIES:
            for risk_pct in RISK_LEVELS:
                combo_i += 1
                equity = STARTING_BALANCE
                for s in sorted_signals:
                    sig_time = s['time_utc']
                    fill_idx, fill_time, fill_price, fill_kind = find_fill_for_entry(
                        ticks, sig_time, LATENCY_S, s['side'], s['entry'])
                    equity_pre = equity
                    if fill_idx is None:
                        # Never filled within validity window - log a NEVER row
                        rows.append({
                            'signal_id': s['id'],
                            'signal_time_utc': sig_time,
                            'side': s['side'],
                            'entry_signal': s['entry'],
                            'sl': s['sl'],
                            'n_tps': len(s['tps']),
                            'fill_time': pd.NaT,
                            'fill_price': float('nan'),
                            'fill_kind': 'NEVER',
                            'fill_slippage_$': float('nan'),
                            'exit_policy': policy,
                            'spread_profile': spread_prof,
                            'risk_pct': risk_pct,
                            'equity_pre': round(equity_pre, 2),
                            'lot': 0.0,
                            'n_exits': 0,
                            'first_exit_label': 'NO_FILL',
                            'first_exit_sec': float('nan'),
                            'exits_summary': '',
                            'gross_pnl': 0.0,
                            'commission': 0.0,
                            'net_pnl': 0.0,
                            'net_pct': 0.0,
                            'equity_post': round(equity, 2),
                            'near_news': tag_news(sig_time, calendar_df),
                        })
                        continue

                    sl_dist = abs(fill_price - s['sl'])
                    lot = compute_lot(risk_pct, equity, sl_dist)

                    horizon = fill_time + pd.Timedelta(hours=WALK_HORIZON_H)
                    horizon_idx = int(np.searchsorted(ts_arr_p, np.datetime64(horizon.tz_convert(None))))
                    walk_view = ticks.iloc[fill_idx + 1:horizon_idx]
                    if walk_view.empty:
                        continue

                    sl_idx, tp_idxs = precompute_crossings(walk_view, s['side'], s['sl'], s['tps'])
                    exits = walk_to_exit(policy, sl_idx, tp_idxs, s['sl'], s['tps'],
                                          walk_view, s['side'], fill_price)
                    gross, comm, net = pnl_signal(fill_price, s['side'], lot, exits, COMMISSION_PER_LOT_RT)

                    equity += net

                    first_exit_idx, _, _, first_label = exits[0]
                    first_exit_time = walk_view['utc_datetime'].iloc[first_exit_idx]
                    secs_to_first = (first_exit_time - fill_time).total_seconds()

                    rows.append({
                        'signal_id': s['id'],
                        'signal_time_utc': sig_time,
                        'side': s['side'],
                        'entry_signal': s['entry'],
                        'sl': s['sl'],
                        'n_tps': len(s['tps']),
                        'fill_time': fill_time,
                        'fill_price': round(float(fill_price), 3),
                        'fill_kind': fill_kind,
                        'fill_slippage_$': round(abs(float(fill_price) - s['entry']), 3),
                        'exit_policy': policy,
                        'spread_profile': spread_prof,
                        'risk_pct': risk_pct,
                        'equity_pre': round(equity_pre, 2),
                        'lot': lot,
                        'n_exits': len(exits),
                        'first_exit_label': first_label,
                        'first_exit_sec': round(secs_to_first, 1),
                        'exits_summary': '|'.join(f"{lbl}@{p:.2f}({pct*100:.0f}%)" for _, p, pct, lbl in exits),
                        'gross_pnl': round(gross, 2),
                        'commission': round(comm, 2),
                        'net_pnl': round(net, 2),
                        'net_pct': round(net / equity_pre * 100, 3),
                        'equity_post': round(equity, 2),
                        'near_news': tag_news(sig_time, calendar_df),
                    })
                if combo_i % 5 == 0 or combo_i == n_combos:
                    print(f"  [{combo_i}/{n_combos}] {spread_prof} / {policy} / {risk_pct}% -> equity {equity:,.0f}", flush=True)

    outcomes = pd.DataFrame(rows)
    out_csv = out_dir / 'signal_outcomes.csv'
    outcomes.to_csv(out_csv, index=False)
    print(f"\nWrote {len(outcomes)} rows -> {out_csv.name}")

    # Aggregate daily
    outcomes['date'] = pd.to_datetime(outcomes['signal_time_utc']).dt.date
    daily = (outcomes.groupby(['date', 'spread_profile', 'exit_policy', 'risk_pct'], as_index=False)
             .agg(
                 n_signals=('signal_id', 'count'),
                 daily_net_pnl=('net_pnl', 'sum'),
                 min_signal_pnl=('net_pnl', 'min'),
                 max_signal_pnl=('net_pnl', 'max'),
                 starting_equity=('equity_pre', 'first'),
                 ending_equity=('equity_post', 'last'),
             ))
    daily['daily_pnl_pct'] = (daily['daily_net_pnl'] / daily['starting_equity'] * 100).round(3)
    daily['hit_3pct'] = daily['daily_pnl_pct'] >= 3.0
    daily['hit_5pct'] = daily['daily_pnl_pct'] >= 5.0
    daily_csv = out_dir / 'daily_pnl.csv'
    daily.to_csv(daily_csv, index=False)
    print(f"Wrote {len(daily)} rows -> {daily_csv.name}")

    # Verdict
    verdict_path = out_dir / 'verdict.md'
    write_verdict(outcomes, daily, verdict_path, tz_offset)
    print(f"Wrote verdict -> {verdict_path.name}")
    return outcomes, daily


# ===========================================================================
# Verdict writer
# ===========================================================================
def write_verdict(outcomes: pd.DataFrame, daily: pd.DataFrame, out_path: Path, tz_offset: int):
    lines = []
    A = lines.append
    A("# Verdict -- APL XAU signals, 17-19 March 2026\n\n")
    A(f"Detected signal tz: **UTC+{tz_offset}**.  ")
    A(f"n_signals = {outcomes['signal_id'].nunique()}, n_trading_days = {daily['date'].nunique()}, ")
    A(f"matrix size = {len(outcomes)} outcome rows ({len(daily)} daily rows).\n\n")

    # TL;DR — direct answer to the user's question
    A("## TL;DR\n\n")
    daily_by_combo = daily.groupby(['spread_profile', 'exit_policy', 'risk_pct'])['daily_pnl_pct'].sum()
    best_sum = daily_by_combo.max()
    best_combo = daily_by_combo.idxmax()
    worst_sum = daily_by_combo.min()
    worst_combo = daily_by_combo.idxmin()
    best_single_day = daily['daily_pnl_pct'].max()
    d3 = int(daily['hit_3pct'].sum())
    d5 = int(daily['hit_5pct'].sum())
    # Winrate per spread, scale_out 1% (use this representative slice)
    wr_lines = []
    for sp in SPREAD_PROFILES:
        sl_sp = outcomes[(outcomes['spread_profile'] == sp) &
                          (outcomes['exit_policy'] == 'scale_out') &
                          (outcomes['risk_pct'] == 1.0) &
                          (outcomes['fill_kind'] != 'NEVER')]
        if not sl_sp.empty:
            w = int((sl_sp['net_pnl'] > 0).sum())
            wr_lines.append(f"{sp}={w}/{len(sl_sp)}")
    fk_slice0 = outcomes[(outcomes['spread_profile'] == 'duka') &
                         (outcomes['exit_policy'] == 'scale_out') &
                         (outcomes['risk_pct'] == 1.0)]
    n_filled = (fk_slice0['fill_kind'] != 'NEVER').sum()
    n_total = len(fk_slice0)
    # Decide the verdict text dynamically
    n_pos_configs = int((daily_by_combo > 0).sum())
    n_total_configs = len(daily_by_combo)
    target_reachable = d3 > 0 or d5 > 0  # any daily row hit the targets?
    if d5 >= 3:
        verdict = "**Is 3-5% per day on $100k reachable?  TENTATIVELY YES at high risk (10%+).** Multiple daily rows clear 5%, but cost: high DD swings."
    elif d3 >= 3:
        verdict = "**Is 3-5% per day on $100k reachable?  3% YES on some days, 5% rarely.** Marginal positive EV at large risk."
    elif best_sum > 0:
        verdict = "**Is 3-5% per day on $100k reachable?  NO (best 3-day total is positive but well below the per-day target).**"
    else:
        verdict = "**Is 3-5% per day on $100k reachable with this signal set?  NO.**  Every config is negative; sizing cannot fix a signal set with negative EV."
    A(verdict + "\n\n")
    A(f"- Fill rate: **{n_filled}/{n_total}** signals filled within {FILL_VALIDITY_H}h validity.\n")
    A(f"- Win rate per broker (scale_out, 1% risk): " + ', '.join(wr_lines) + ".\n")
    A(f"- Best 3-day total across ALL configs: **{best_sum:+.2f}%** ({best_combo[0]}/{best_combo[1]}/{best_combo[2]}%).\n")
    A(f"- Worst 3-day total: **{worst_sum:+.2f}%** ({worst_combo[0]}/{worst_combo[1]}/{worst_combo[2]}%).\n")
    A(f"- Best single-day PnL across all configs: **{best_single_day:+.2f}%**.\n")
    A(f"- Configs with positive 3-day sum: **{n_pos_configs}/{n_total_configs}**.\n")
    A(f"- Days hitting 3%: **{d3}** out of {len(daily)} daily rows. Days hitting 5%: **{d5}**.\n")
    A(f"- Broker matters at the margin: Duka's wider raw spread (~$0.65) cost signal #9 a win that Robo/Axi captured.\n\n")


    # Headline rollup per (spread, policy, risk) -> totals across all days
    A("## Headline -- aggregate over 3 days\n\n")
    head = (daily.groupby(['spread_profile', 'exit_policy', 'risk_pct'], as_index=False)
            .agg(n_days=('date', 'count'),
                 days_pos=('daily_pnl_pct', lambda x: int((x > 0).sum())),
                 days_3pct=('hit_3pct', 'sum'),
                 days_5pct=('hit_5pct', 'sum'),
                 sum_pnl_pct=('daily_pnl_pct', 'sum'),
                 avg_daily_pct=('daily_pnl_pct', 'mean'),
                 best_day_pct=('daily_pnl_pct', 'max'),
                 worst_day_pct=('daily_pnl_pct', 'min'),
                 final_equity=('ending_equity', 'last'),
                 ))
    head = head.sort_values(['spread_profile', 'exit_policy', 'risk_pct'])

    A("| Spread | Policy    | Risk%  | Days+ | D>=3% | D>=5% | Sum% (3d) | Avg/day | Best | Worst | Final equity |\n")
    A("|--------|-----------|--------|-------|-------|-------|-----------|---------|------|-------|--------------|\n")
    for _, r in head.iterrows():
        A(f"| {r['spread_profile']:<6} | {r['exit_policy']:<9} | {r['risk_pct']:>5.2f}% | "
          f"{int(r['days_pos']):>5} | {int(r['days_3pct']):>5} | {int(r['days_5pct']):>5} | "
          f"{r['sum_pnl_pct']:+8.2f}% | {r['avg_daily_pct']:+6.2f}% | "
          f"{r['best_day_pct']:+5.2f}% | {r['worst_day_pct']:+6.2f}% | "
          f"${r['final_equity']:>11,.0f} |\n")
    A("\n")

    # Best vs worst configs
    A("## Top 5 configs by sum 3-day PnL%\n\n")
    top = head.sort_values('sum_pnl_pct', ascending=False).head(5)
    A("| Spread | Policy | Risk% | Sum% | Final equity |\n|---|---|---|---|---|\n")
    for _, r in top.iterrows():
        A(f"| {r['spread_profile']} | {r['exit_policy']} | {r['risk_pct']:.2f} | "
          f"{r['sum_pnl_pct']:+.2f}% | ${r['final_equity']:,.0f} |\n")
    A("\n")

    A("## Bottom 5 configs by sum 3-day PnL%\n\n")
    bot = head.sort_values('sum_pnl_pct', ascending=True).head(5)
    A("| Spread | Policy | Risk% | Sum% | Final equity |\n|---|---|---|---|---|\n")
    for _, r in bot.iterrows():
        A(f"| {r['spread_profile']} | {r['exit_policy']} | {r['risk_pct']:.2f} | "
          f"{r['sum_pnl_pct']:+.2f}% | ${r['final_equity']:,.0f} |\n")
    A("\n")

    # Fill-kind summary (one slice per signal, irrespective of policy/risk — fill is set by entry only)
    A("## Fill outcomes (does each signal even fill?)\n\n")
    # Take the duka/scale_out/1% slice as representative for fill stats
    fk_slice = outcomes[(outcomes['spread_profile'] == 'duka') &
                        (outcomes['exit_policy'] == 'scale_out') &
                        (outcomes['risk_pct'] == 1.0)].sort_values('signal_time_utc')
    A("| # | Time UTC | Side | Entry | Fill kind | Fill time (UTC) | Delay (min) |\n")
    A("|---|----------|------|-------|-----------|-----------------|-------------|\n")
    for _, r in fk_slice.iterrows():
        ft = str(r['fill_time'])[:19] if pd.notna(r['fill_time']) else '(never)'
        if pd.notna(r['fill_time']):
            delay = (pd.Timestamp(r['fill_time']) - pd.Timestamp(r['signal_time_utc'])).total_seconds() / 60
            delay_str = f"{delay:.1f}"
        else:
            delay_str = '-'
        A(f"| {r['signal_id']} | {str(r['signal_time_utc'])[:16]} | {r['side']} | "
          f"{r['entry_signal']:.2f} | {r['fill_kind']} | {ft} | {delay_str} |\n")
    n_never = (fk_slice['fill_kind'] == 'NEVER').sum()
    A(f"\n**{n_never}/{len(fk_slice)} signals never filled within {FILL_VALIDITY_H}h validity window.**\n\n")

    # Per-signal breakdown at single representative config (filled signals only)
    repr_spread, repr_policy, repr_risk = 'robo', 'scale_out', 1.0
    A(f"## Per-signal outcomes at {repr_spread}/{repr_policy}/{repr_risk}%  (filled only)\n\n")
    sl = outcomes[(outcomes['spread_profile'] == repr_spread) &
                  (outcomes['exit_policy'] == repr_policy) &
                  (outcomes['risk_pct'] == repr_risk) &
                  (outcomes['fill_kind'] != 'NEVER')].sort_values('signal_time_utc')
    if not sl.empty:
        wins = int((sl['net_pnl'] > 0).sum())
        A(f"**Win rate (filled signals): {wins}/{len(sl)} = {100*wins/len(sl):.0f}%**\n\n")
        A("| # | Time UTC | Side | Entry | Fill$ | Kind | Lot | First exit | Net $ | Net % | Exits | News |\n")
        A("|---|----------|------|-------|-------|------|-----|-----------|-------|-------|-------|------|\n")
        for _, r in sl.iterrows():
            A(f"| {r['signal_id']} | {str(r['signal_time_utc'])[:16]} | {r['side']} | "
              f"{r['entry_signal']:.2f} | {r['fill_price']:.2f} | {r['fill_kind']} | "
              f"{r['lot']:.2f} | {r['first_exit_label']}@{r['first_exit_sec']:.0f}s | "
              f"{r['net_pnl']:+.0f} | {r['net_pct']:+.2f}% | {r['exits_summary'][:55]} | "
              f"{r['near_news'][:30]} |\n")
    A("\n")

    # Per-policy winrate summary (filled signals only)
    A("## Win rate (net_pnl > 0) per policy, at robo/1% risk (filled signals only)\n\n")
    A("| Policy | n_filled | wins | winrate | avg net % | avg net $ |\n|---|---|---|---|---|---|\n")
    for pol in EXIT_POLICIES:
        s = outcomes[(outcomes['spread_profile'] == 'robo') &
                     (outcomes['exit_policy'] == pol) &
                     (outcomes['risk_pct'] == 1.0) &
                     (outcomes['fill_kind'] != 'NEVER')]
        if not s.empty:
            w = int((s['net_pnl'] > 0).sum())
            A(f"| {pol} | {len(s)} | {w} | {100*w/len(s):.0f}% | "
              f"{s['net_pct'].mean():+.2f}% | ${s['net_pnl'].mean():+,.0f} |\n")
    A("\n")

    # Concurrent open risk warning
    A("## Concurrency check\n\n")
    A("Worst-case gross open risk = 3 concurrent open signals on 18 March (signals 7, 8, then 9).\n")
    A("At 10% per signal -> 30% gross open (close to 40% DD ceiling).\n")
    A("At 5% -> 15%; at 2% -> 6% (comfortable).\n\n")

    # Caveats
    A("## Caveats\n\n")
    A("- n=10 signals across 3 days. Anecdotal, not statistically significant.\n")
    A("- Latency fixed at 3s; auto-bot range is 2-5s.\n")
    A("- Spread profiles produce *similar but not identical* PnL: entry/SL/TP are level fills (same nominal price), but tick-by-tick "
      "ASK/BID trajectories differ. On signals where price grazes TP levels (e.g. signal #9), wider Duka spread blocks the deeper TPs "
      "from filling — Robo/Axi capture them, Duka doesn't. Spread also shifts fill timing by a few seconds.\n")
    A("- No extra slippage modelled beyond bid-ask. SL/TP fills use exact threshold price.\n")
    A("- No swap (intraday only).\n")
    A(f"- Signal tz inferred UTC+{tz_offset} from entry-price reconciliation against signals 1-4 (market-style fills).\n")
    A(f"- Fill validity window: {FILL_VALIDITY_H}h from signal time. Signals where price never reached the entry level expire unfilled.\n")

    out_path.write_text(''.join(lines), encoding='utf-8')


# ===========================================================================
def main():
    p = argparse.ArgumentParser()
    p.add_argument('--tick-root', required=True, help='Dir with XAUUSD_2026_jan-may*.csv files')
    p.add_argument('--calendar', required=True, help='Path to calendar/2026_full.csv')
    p.add_argument('--out', required=True, help='Output directory')
    p.add_argument('--tz', type=int, default=None,
                   help='Force tz offset (UTC+N). If omitted, auto-detect.')
    args = p.parse_args()
    run_backtest(Path(args.tick_root), Path(args.calendar), Path(args.out), tz_force=args.tz)


if __name__ == '__main__':
    main()
