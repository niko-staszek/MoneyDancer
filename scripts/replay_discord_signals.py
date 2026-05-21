#!/usr/bin/env python3
"""
Discord-export signal replay EA.

Inputs:
  - C:/Users/nikof/Documents/GitHub/signals/signals1.csv (200 signals, Mar-May)
  - C:/Users/nikof/Documents/GitHub/signals/tnfx.csv     (15 signals, Mar-Apr)

Pipeline:
  1. Parse Discord chat export -> structured signal list (tz from each timestamp)
  2. Typo guard: wrong-side SL, absurd SL distance, attempt 1-digit auto-repair
  3. Cancellation rule: opposite-direction within Δt minutes + small entry diff
     -> cancel earlier signal, use later
  4. Replay each surviving signal against Duka tick data (raw + Robo + Axi)
     using STOP/LIMIT pending-order logic from replay_telegram_signals
  5. Sizing discovery: sweep risk %, find combo that maximizes daily return
     subject to DD ceiling

Outputs (per-file):
  runs/signals_discord/<file_stem>/signal_outcomes.csv
  runs/signals_discord/<file_stem>/daily_pnl.csv
  runs/signals_discord/<file_stem>/verdict.md
  runs/signals_discord/comparison.md
"""
import argparse
import re
import sys
from collections import defaultdict
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).parent))
from replay_telegram_signals import (  # type: ignore
    load_ticks,
    find_fill_for_entry,
    precompute_crossings,
    walk_to_exit,
    compute_lot,
    pnl_signal,
    load_calendar,
    tag_news,
    XAU_CONTRACT_OZ,
    COMMISSION_PER_LOT_RT,
    LATENCY_S,
    FILL_VALIDITY_H,
    WALK_HORIZON_H,
    MIN_LOT,
    LOT_STEP,
    STARTING_BALANCE,
)

# Output encoding for Windows console (emoji-safe)
sys.stdout.reconfigure(encoding='utf-8', errors='replace')

# ===========================================================================
# Config
# ===========================================================================
SIGNALS_DIR_DEFAULT = Path('C:/Users/nikof/Documents/GitHub/signals')
TICK_ROOT_DEFAULT = Path('data/duka')
CALENDAR_DEFAULT = Path('data/calendar/2026_full.csv')
OUT_DEFAULT = Path('runs/signals_discord')

PROFILE_FILES = {
    'duka': 'XAUUSD_2026_jan-may.csv',
    'robo': 'XAUUSD_2026_jan-may_robo.csv',
    'axi':  'XAUUSD_2026_jan-may_axi.csv',
}

EXIT_POLICIES = ['scale_out', 'tp1_be', 'tp1_only']
SPREAD_PROFILES = ['duka', 'robo', 'axi']

# Extended risk sweep for "max daily return" discovery
RISK_LEVELS = [0.1, 0.25, 0.5, 1.0, 2.0, 3.0, 5.0, 7.5, 10.0, 15.0, 20.0]

# Memory rule: DD ceiling for filtering acceptable configs
DD_CEILING_PCT = 40.0

# Cancellation rule defaults
CANCEL_WINDOW_MIN = 10.0           # within 10 min -> potential cancellation
CANCEL_ENTRY_DIFF_PCT = 2.0        # within 2 % of price -> "minimal change"

# Typo detection
SL_DISTANCE_MULTIPLIER_MAX = 5.0   # SL distance > 5x median for provider -> suspect
ABSURD_SL_DISTANCE_PCT = 5.0       # SL > 5 % of price -> always suspect (XAU at 5000 -> 250)


# ===========================================================================
# Discord CSV parser
# ===========================================================================
ROW_START = re.compile(r'^"(\d{18,20}),"')


def split_discord_records(text: str) -> list[str]:
    """Split a DiscordChatExporter CSV into per-message records.
    Each record starts with a quoted AuthorID (18-20 digits) followed by `,`.
    """
    lines = text.splitlines()
    records, cur = [], []
    for ln in lines[1:]:  # skip header
        if ROW_START.match(ln):
            if cur:
                records.append('\n'.join(cur))
            cur = [ln]
        else:
            cur.append(ln)
    if cur:
        records.append('\n'.join(cur))
    return records


SYMBOLS = ['XAUUSD', 'BTCUSD', 'ETHUSD', 'EURUSD', 'GBPUSD', 'EURAUD', 'USDJPY', 'XAGUSD']

# Entry / SL / TP line patterns (tolerant of "ENTRY:" / "Entry:" / etc.)
RE_ENTRY = re.compile(r'(?:ENTRY|Entry)[\s:]*([0-9]+\.?[0-9]*)', re.IGNORECASE)
RE_SL    = re.compile(r'\bSL[\s:]*([0-9]+\.?[0-9]*)', re.IGNORECASE)
RE_TP    = re.compile(r'\bTP(\d+)[\s:]*([0-9]+\.?[0-9]*)', re.IGNORECASE)
RE_BUY   = re.compile(r'(BUY|🟢)', re.IGNORECASE)
RE_SELL  = re.compile(r'(SELL|🔴)', re.IGNORECASE)
RE_DATE  = re.compile(r'"(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+)([+-]\d{2}:\d{2})"')
RE_AUTHOR = re.compile(r'"\d+","([^"]+)"')


@dataclass
class ParsedSignal:
    msg_idx: int                    # index within source file
    source_file: str
    author: str
    time_utc: pd.Timestamp          # UTC, with tz info
    symbol: str
    side: str                       # 'BUY' or 'SELL'
    entry: float
    sl: float
    tps: list[float]
    raw: str = ''                   # original text for debugging
    # Audit trail
    typo_action: str = ''           # 'ok' | 'repaired-sl' | 'rejected-bad-sl'
    cancel_status: str = ''         # 'ok' | 'canceled-by-N' | 'cancels-N'
    skip_reason: str = ''


def parse_discord_signal(record: str, idx: int, source: str) -> ParsedSignal | None:
    """Extract a ParsedSignal from one Discord chat record. Returns None if not a tradable signal."""
    # Author
    a = RE_AUTHOR.search(record)
    author = a.group(1) if a else 'unknown'
    # Date + tz
    d = RE_DATE.search(record)
    if not d:
        return None
    # Pandas can parse the trailing offset
    time_utc = pd.to_datetime(d.group(1) + d.group(2), utc=True)
    # Symbol
    sym = None
    for s in SYMBOLS:
        if s in record:
            sym = s
            break
    if sym is None:
        return None
    # Side - SELL takes precedence (red emoji is unambiguous)
    is_sell = bool(RE_SELL.search(record))
    is_buy = bool(RE_BUY.search(record))
    # "SELL" word vs "🟢 BUY" emoji - if both somehow appear, take the one that matches the symbol header
    # Look for symbol-paired side first
    pair_m = re.search(r'(BUY|SELL)', record, re.IGNORECASE)
    if is_sell and is_buy:
        side = pair_m.group(1).upper() if pair_m else 'SELL'
    elif is_sell:
        side = 'SELL'
    elif is_buy:
        side = 'BUY'
    else:
        return None
    # Entry
    e = RE_ENTRY.search(record)
    if not e:
        return None
    entry = float(e.group(1))
    # SL
    sl = RE_SL.search(record)
    if not sl:
        return None
    sl_val = float(sl.group(1))
    # TPs (collect all, sorted by index)
    tp_matches = RE_TP.findall(record)
    if not tp_matches:
        return None
    tps_by_idx = sorted([(int(i), float(v)) for i, v in tp_matches], key=lambda x: x[0])
    tps = [v for _, v in tps_by_idx]
    return ParsedSignal(
        msg_idx=idx, source_file=source, author=author,
        time_utc=time_utc, symbol=sym, side=side,
        entry=entry, sl=sl_val, tps=tps,
        raw=record[:200],
    )


def parse_discord_csv(path: Path) -> list[ParsedSignal]:
    text = path.read_text(encoding='utf-8', errors='replace')
    records = split_discord_records(text)
    signals = []
    for i, r in enumerate(records):
        s = parse_discord_signal(r, i, path.name)
        if s is not None:
            signals.append(s)
    return signals


# ===========================================================================
# Typo detection + auto-repair
# ===========================================================================
def _flip_one_digit(n: float, target_dist: float, ref_price: float) -> float | None:
    """Try replacing each digit of `n` with each other digit; return the variant whose
    |variant - ref_price| is closest to `target_dist`. Returns None if no improvement.
    """
    s = f'{n:.1f}'
    best = None
    best_err = abs(abs(n - ref_price) - target_dist)
    initial_err = best_err
    for pos in range(len(s)):
        if not s[pos].isdigit():
            continue
        for new in '0123456789':
            if new == s[pos]:
                continue
            cand_s = s[:pos] + new + s[pos+1:]
            try:
                cand = float(cand_s)
            except ValueError:
                continue
            cand_dist = abs(cand - ref_price)
            err = abs(cand_dist - target_dist)
            if err < best_err and cand_dist < target_dist * 3:  # don't choose absurd
                best_err = err
                best = cand
    if best is None or best_err >= initial_err * 0.5:
        return None
    return best


def typo_check_and_repair(signals: list[ParsedSignal]) -> tuple[list[ParsedSignal], dict]:
    """Apply typo detection + auto-repair per provider.

    Rules:
    - Per-provider median SL distance + median entry price computed from clean signals
    - Wrong-side SL (SELL with SL<entry, BUY with SL>entry): try 1-digit fix on SL;
      reject if no valid fix
    - Absurd-distance SL but RIGHT side: try 1-digit fix; if no fix, KEEP as wide-stop
    - Entry price > 30% off median entry: reject (probably wrong instrument/typo)
    """
    # Per (author, symbol) median SL distance and median entry from clean signals
    by_key_sl = defaultdict(list)
    by_key_entry = defaultdict(list)
    for s in signals:
        key = (s.author, s.symbol)
        wrong_side = (s.side == 'BUY' and s.sl >= s.entry) or (s.side == 'SELL' and s.sl <= s.entry)
        absurd = abs(s.sl - s.entry) > s.entry * ABSURD_SL_DISTANCE_PCT / 100
        if not wrong_side and not absurd:
            by_key_sl[key].append(abs(s.sl - s.entry))
        by_key_entry[key].append(s.entry)
    median_sl = {k: float(np.median(d)) for k, d in by_key_sl.items() if d}
    median_entry = {k: float(np.median(e)) for k, e in by_key_entry.items() if e}

    stats = {'ok': 0, 'repaired-sl': 0, 'kept-wide-sl': 0,
             'rejected-bad-sl': 0, 'rejected-bad-entry': 0, 'no-baseline': 0}
    out = []
    for s in signals:
        key = (s.author, s.symbol)
        med_sl = median_sl.get(key)
        med_e = median_entry.get(key)

        # Entry sanity: > 30 % off median entry -> reject
        if med_e is not None and abs(s.entry - med_e) > med_e * 0.30:
            s.typo_action = 'rejected-bad-entry'
            s.skip_reason = f'entry {s.entry} >30% off median {med_e:.0f}'
            stats['rejected-bad-entry'] += 1
            out.append(s)
            continue

        if med_sl is None:
            s.typo_action = 'no-baseline'
            stats['no-baseline'] += 1
            out.append(s)
            continue

        sl_dist = abs(s.sl - s.entry)
        wrong_side = (s.side == 'BUY' and s.sl >= s.entry) or (s.side == 'SELL' and s.sl <= s.entry)
        absurd = sl_dist > med_sl * SL_DISTANCE_MULTIPLIER_MAX or sl_dist > s.entry * ABSURD_SL_DISTANCE_PCT / 100

        if not wrong_side and not absurd:
            s.typo_action = 'ok'
            stats['ok'] += 1
            out.append(s)
            continue

        # Attempt 1-digit repair targeting the median distance
        repaired = _flip_one_digit(s.sl, med_sl, s.entry)
        if repaired is not None:
            ok_side = (s.side == 'BUY' and repaired < s.entry) or (s.side == 'SELL' and repaired > s.entry)
            if ok_side:
                old_sl = s.sl
                s.sl = repaired
                s.typo_action = f'repaired-sl:{old_sl}->{repaired}'
                stats['repaired-sl'] += 1
                out.append(s)
                continue

        # No fix found
        if wrong_side:
            # Wrong-side is unambiguous error -> reject
            s.typo_action = 'rejected-bad-sl'
            s.skip_reason = f'wrong-side SL (entry={s.entry}, sl={s.sl})'
            stats['rejected-bad-sl'] += 1
        else:
            # Wide but right-side -> keep as-is (legitimate wider stop)
            s.typo_action = f'kept-wide-sl (dist={sl_dist:.0f} vs median {med_sl:.0f})'
            stats['kept-wide-sl'] += 1
        out.append(s)
    return out, stats


# ===========================================================================
# Cancellation logic
# ===========================================================================
def apply_cancellations(signals: list[ParsedSignal]) -> dict:
    """For each signal s[i], if a later signal s[j] is opposite-direction, same symbol/author,
    within CANCEL_WINDOW_MIN minutes, and entry within CANCEL_ENTRY_DIFF_PCT of s[i].entry,
    mark s[i] as 'canceled-by-j'. s[j] stays active (cancels-i).
    Operates per author+symbol stream chronologically.
    """
    stats = {'canceled': 0, 'cancels': 0, 'kept': 0}
    by_stream = defaultdict(list)
    for s in signals:
        by_stream[(s.author, s.symbol)].append(s)
    for key, stream in by_stream.items():
        stream.sort(key=lambda s: s.time_utc)
        for i in range(len(stream)):
            if stream[i].skip_reason:  # already rejected
                continue
            for j in range(i + 1, len(stream)):
                if stream[j].skip_reason:
                    continue
                dt_min = (stream[j].time_utc - stream[i].time_utc).total_seconds() / 60
                if dt_min > CANCEL_WINDOW_MIN:
                    break  # stream is sorted - no later match within window
                if stream[j].side == stream[i].side:
                    continue
                # Opposite direction within window
                entry_diff_pct = abs(stream[j].entry - stream[i].entry) / stream[i].entry * 100
                if entry_diff_pct > CANCEL_ENTRY_DIFF_PCT:
                    continue
                # Cancel i, j stays
                stream[i].cancel_status = f'canceled-by-{stream[j].msg_idx}'
                stream[i].skip_reason = f'canceled by later opposite signal idx={stream[j].msg_idx}'
                stream[j].cancel_status = f'cancels-{stream[i].msg_idx}' if not stream[j].cancel_status else stream[j].cancel_status
                stats['canceled'] += 1
                stats['cancels'] += 1
                break
    for s in signals:
        if not s.skip_reason:
            stats['kept'] += 1
    return stats


# ===========================================================================
# Backtest matrix
# ===========================================================================
def run_one_file(signals: list[ParsedSignal], ticks_by_profile: dict, calendar_df: pd.DataFrame) -> pd.DataFrame:
    """Run the full (signal x policy x spread x risk) matrix for a list of signals.
    Returns the outcomes dataframe.
    """
    # Only run XAU signals (no tick data for others)
    xau = [s for s in signals if s.symbol == 'XAUUSD' and not s.skip_reason]
    xau.sort(key=lambda s: s.time_utc)

    rows = []
    n_combos = len(SPREAD_PROFILES) * len(EXIT_POLICIES) * len(RISK_LEVELS)
    combo_i = 0
    for spread_prof, ticks in ticks_by_profile.items():
        ts_arr_p = ticks['utc_datetime'].values
        for policy in EXIT_POLICIES:
            for risk_pct in RISK_LEVELS:
                combo_i += 1
                equity = STARTING_BALANCE
                for s in xau:
                    fill_idx, fill_time, fill_price, fill_kind = find_fill_for_entry(
                        ticks, s.time_utc, LATENCY_S, s.side, s.entry)
                    equity_pre = equity
                    if fill_idx is None:
                        rows.append({
                            'msg_idx': s.msg_idx, 'source': s.source_file, 'author': s.author,
                            'signal_time_utc': s.time_utc, 'symbol': s.symbol, 'side': s.side,
                            'entry_signal': s.entry, 'sl': s.sl, 'n_tps': len(s.tps),
                            'fill_time': pd.NaT, 'fill_price': float('nan'), 'fill_kind': 'NEVER',
                            'exit_policy': policy, 'spread_profile': spread_prof, 'risk_pct': risk_pct,
                            'equity_pre': round(equity_pre, 2), 'lot': 0.0, 'n_exits': 0,
                            'first_exit_label': 'NO_FILL', 'first_exit_sec': float('nan'),
                            'exits_summary': '', 'gross_pnl': 0.0, 'commission': 0.0,
                            'net_pnl': 0.0, 'net_pct': 0.0, 'equity_post': round(equity, 2),
                            'near_news': tag_news(s.time_utc, calendar_df),
                            'typo_action': s.typo_action, 'cancel_status': s.cancel_status,
                        })
                        continue

                    sl_dist = abs(fill_price - s.sl)
                    lot = compute_lot(risk_pct, equity, sl_dist)
                    horizon = fill_time + pd.Timedelta(hours=WALK_HORIZON_H)
                    horizon_idx = int(np.searchsorted(ts_arr_p, np.datetime64(horizon.tz_convert(None))))
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
                        'msg_idx': s.msg_idx, 'source': s.source_file, 'author': s.author,
                        'signal_time_utc': s.time_utc, 'symbol': s.symbol, 'side': s.side,
                        'entry_signal': s.entry, 'sl': s.sl, 'n_tps': len(s.tps),
                        'fill_time': fill_time, 'fill_price': round(float(fill_price), 3),
                        'fill_kind': fill_kind,
                        'exit_policy': policy, 'spread_profile': spread_prof, 'risk_pct': risk_pct,
                        'equity_pre': round(equity_pre, 2), 'lot': lot,
                        'n_exits': len(exits), 'first_exit_label': first_label,
                        'first_exit_sec': round(secs_to_first, 1),
                        'exits_summary': '|'.join(f"{lbl}@{p:.2f}({pct*100:.0f}%)" for _, p, pct, lbl in exits[:6]),
                        'gross_pnl': round(gross, 2), 'commission': round(comm, 2),
                        'net_pnl': round(net, 2), 'net_pct': round(net / equity_pre * 100, 3),
                        'equity_post': round(equity, 2),
                        'near_news': tag_news(s.time_utc, calendar_df),
                        'typo_action': s.typo_action, 'cancel_status': s.cancel_status,
                    })
                if combo_i % 10 == 0 or combo_i == n_combos:
                    print(f"  [{combo_i}/{n_combos}] {spread_prof}/{policy}/{risk_pct}% -> equity {equity:,.0f}", flush=True)

    return pd.DataFrame(rows)


# ===========================================================================
# Sizing discovery
# ===========================================================================
def discover_optimal_sizing(daily: pd.DataFrame) -> pd.DataFrame:
    """For each (spread, policy, risk_pct), compute the daily-return distribution and the
    cumulative DD. Return a ranked summary highlighting max-daily-return configs subject
    to DD ceiling.
    """
    grp = daily.groupby(['spread_profile', 'exit_policy', 'risk_pct'])

    out = []
    for key, g in grp:
        sp, pol, rk = key
        n_days = len(g)
        avg = g['daily_pnl_pct'].mean()
        med = g['daily_pnl_pct'].median()
        sd = g['daily_pnl_pct'].std()
        d_pos = int((g['daily_pnl_pct'] > 0).sum())
        d_3 = int((g['daily_pnl_pct'] >= 3.0).sum())
        d_5 = int((g['daily_pnl_pct'] >= 5.0).sum())
        # Cumulative equity-curve DD (use ending_equity day by day, sorted by date)
        g_sorted = g.sort_values('date')
        eq = g_sorted['ending_equity'].values
        if len(eq) > 0:
            peak = np.maximum.accumulate(eq)
            dd = (peak - eq) / peak * 100
            max_dd = float(dd.max())
        else:
            max_dd = 0.0
        final_eq = float(eq[-1]) if len(eq) else STARTING_BALANCE
        total_return = (final_eq / STARTING_BALANCE - 1) * 100
        sharpe = avg / sd * np.sqrt(252) if sd and sd > 0 else 0.0
        out.append({
            'spread_profile': sp, 'exit_policy': pol, 'risk_pct': rk,
            'n_days': n_days, 'avg_daily_pct': round(avg, 3),
            'median_daily_pct': round(med, 3), 'std_daily_pct': round(sd, 3),
            'days_pos': d_pos, 'days_ge_3pct': d_3, 'days_ge_5pct': d_5,
            'max_dd_pct': round(max_dd, 2), 'total_return_pct': round(total_return, 2),
            'final_equity': round(final_eq, 2), 'sharpe_proxy': round(sharpe, 2),
            'within_dd_ceiling': max_dd <= DD_CEILING_PCT,
        })
    return pd.DataFrame(out)


# ===========================================================================
# Verdict writer
# ===========================================================================
def write_verdict(outcomes: pd.DataFrame, daily: pd.DataFrame, sizing: pd.DataFrame,
                  out_path: Path, source_label: str, typo_stats: dict, cancel_stats: dict,
                  total_signals_parsed: int, audit: pd.DataFrame | None = None):
    lines, A = [], lambda s: lines.append(s)
    A(f"# Discord signal replay - {source_label}\n\n")
    A(f"## Pipeline summary\n\n")
    A(f"- Signals parsed: {total_signals_parsed}\n")
    A(f"- Typo check: ok={typo_stats['ok']}, repaired-SL={typo_stats['repaired-sl']}, "
      f"rejected-bad-SL={typo_stats['rejected-bad-sl']}, no-baseline={typo_stats['no-baseline']}\n")
    A(f"- Cancellation: canceled={cancel_stats['canceled']}, kept={cancel_stats['kept']}\n")
    n_xau = int(outcomes['symbol'].eq('XAUUSD').sum() // (len(SPREAD_PROFILES) * len(EXIT_POLICIES) * len(RISK_LEVELS))) if not outcomes.empty else 0
    A(f"- XAU signals replayed: {n_xau}\n\n")

    if outcomes.empty:
        A("**No signals to replay. Verdict empty.**\n")
        out_path.write_text(''.join(lines), encoding='utf-8')
        return

    # Fill stats
    duka_scale1 = outcomes[(outcomes['spread_profile'] == 'duka') &
                           (outcomes['exit_policy'] == 'scale_out') &
                           (outcomes['risk_pct'] == 1.0)]
    n_filled = int((duka_scale1['fill_kind'] != 'NEVER').sum())
    n_total = len(duka_scale1)
    n_winners = int((duka_scale1[duka_scale1['fill_kind'] != 'NEVER']['net_pnl'] > 0).sum())

    # ==== TL;DR ====
    A("## TL;DR\n\n")
    best_combo = sizing.loc[sizing['within_dd_ceiling']].sort_values('total_return_pct', ascending=False).head(1)
    if not best_combo.empty:
        bc = best_combo.iloc[0]
        A(f"**Best config within {DD_CEILING_PCT}% DD ceiling**: "
          f"{bc['spread_profile']}/{bc['exit_policy']}/{bc['risk_pct']}% risk -> "
          f"total return **{bc['total_return_pct']:+.2f}%** over {bc['n_days']} days, "
          f"max DD **{bc['max_dd_pct']:.2f}%**, avg daily **{bc['avg_daily_pct']:+.3f}%**.\n")
    best_overall = sizing.sort_values('total_return_pct', ascending=False).head(1)
    if not best_overall.empty:
        bo = best_overall.iloc[0]
        A(f"**Best total return (any DD)**: "
          f"{bo['spread_profile']}/{bo['exit_policy']}/{bo['risk_pct']}% -> "
          f"total **{bo['total_return_pct']:+.2f}%**, max DD **{bo['max_dd_pct']:.2f}%**.\n")
    best_avg_daily = sizing.loc[sizing['within_dd_ceiling']].sort_values('avg_daily_pct', ascending=False).head(1)
    if not best_avg_daily.empty:
        bad = best_avg_daily.iloc[0]
        A(f"**Best avg daily (within DD ceiling)**: {bad['spread_profile']}/{bad['exit_policy']}/{bad['risk_pct']}% -> "
          f"avg daily **{bad['avg_daily_pct']:+.3f}%**, days>=3%: {bad['days_ge_3pct']}/{bad['n_days']}.\n")

    A(f"\n- Fill rate (scale_out/1%): **{n_filled}/{n_total}** signals\n")
    A(f"- Filled winrate (scale_out, duka, 1%): **{n_winners}/{n_filled} = {100*n_winners/max(n_filled,1):.0f}%**\n")
    A(f"- {len(sizing)} configurations tested\n\n")

    # ==== Top configs by total return (within DD ceiling) ====
    A(f"## Top 10 configs by total return (within {DD_CEILING_PCT}% DD ceiling)\n\n")
    A("| Spread | Policy | Risk% | Days | Avg/day | Days+ | D>=3% | D>=5% | Max DD | Total Ret | Final | Sharpe |\n")
    A("|---|---|---|---|---|---|---|---|---|---|---|---|\n")
    safe = sizing[sizing['within_dd_ceiling']].sort_values('total_return_pct', ascending=False).head(10)
    for _, r in safe.iterrows():
        A(f"| {r['spread_profile']} | {r['exit_policy']} | {r['risk_pct']:.2f} | {r['n_days']} | "
          f"{r['avg_daily_pct']:+.3f}% | {r['days_pos']} | {r['days_ge_3pct']} | {r['days_ge_5pct']} | "
          f"{r['max_dd_pct']:.2f}% | {r['total_return_pct']:+.2f}% | ${r['final_equity']:,.0f} | {r['sharpe_proxy']:.2f} |\n")

    # ==== Top configs by avg daily return (within DD ceiling) ====
    A(f"\n## Top 10 configs by avg daily return (within DD ceiling)\n\n")
    A("| Spread | Policy | Risk% | Avg/day | Median/day | Max DD | Total Ret | Days>=3% | Sharpe |\n")
    A("|---|---|---|---|---|---|---|---|---|\n")
    by_avg = sizing[sizing['within_dd_ceiling']].sort_values('avg_daily_pct', ascending=False).head(10)
    for _, r in by_avg.iterrows():
        A(f"| {r['spread_profile']} | {r['exit_policy']} | {r['risk_pct']:.2f} | "
          f"{r['avg_daily_pct']:+.3f}% | {r['median_daily_pct']:+.3f}% | {r['max_dd_pct']:.2f}% | "
          f"{r['total_return_pct']:+.2f}% | {r['days_ge_3pct']} | {r['sharpe_proxy']:.2f} |\n")

    # ==== Top configs by Sharpe (within DD ceiling) ====
    A(f"\n## Top 10 configs by Sharpe (within DD ceiling)\n\n")
    A("| Spread | Policy | Risk% | Sharpe | Avg/day | Std/day | Max DD | Total Ret |\n")
    A("|---|---|---|---|---|---|---|---|\n")
    by_sh = sizing[sizing['within_dd_ceiling']].sort_values('sharpe_proxy', ascending=False).head(10)
    for _, r in by_sh.iterrows():
        A(f"| {r['spread_profile']} | {r['exit_policy']} | {r['risk_pct']:.2f} | "
          f"{r['sharpe_proxy']:.2f} | {r['avg_daily_pct']:+.3f}% | {r['std_daily_pct']:.3f}% | "
          f"{r['max_dd_pct']:.2f}% | {r['total_return_pct']:+.2f}% |\n")

    # ==== Risk sensitivity (single policy, single spread) ====
    A(f"\n## Risk sensitivity (robo/scale_out)\n\n")
    A("| Risk% | Avg/day | Total Ret | Max DD | Days+ | D>=3% | Sharpe | Within ceiling |\n")
    A("|---|---|---|---|---|---|---|---|\n")
    for _, r in sizing[(sizing['spread_profile'] == 'robo') &
                        (sizing['exit_policy'] == 'scale_out')].sort_values('risk_pct').iterrows():
        ok = '✓' if r['within_dd_ceiling'] else '✗'
        A(f"| {r['risk_pct']:.2f} | {r['avg_daily_pct']:+.3f}% | {r['total_return_pct']:+.2f}% | "
          f"{r['max_dd_pct']:.2f}% | {r['days_pos']} | {r['days_ge_3pct']} | {r['sharpe_proxy']:.2f} | {ok} |\n")

    # ==== Typo + cancellation audit (from audit.csv, includes skipped signals) ====
    if audit is not None and not audit.empty:
        typo_rep = audit[audit['typo_action'].fillna('').str.contains('repaired')]
        typo_rej = audit[audit['typo_action'] == 'rejected-bad-sl']
        cancels = audit[audit['cancel_status'].fillna('').str.startswith('canceled-by')]
        A(f"\n## Typo + cancellation audit\n\n")
        A(f"### Repaired SLs ({len(typo_rep)})\n\n")
        if not typo_rep.empty:
            for _, r in typo_rep.iterrows():
                A(f"- msg #{r['msg_idx']} {str(r['time_utc'])[:16]} {r['side']} entry {r['entry']} -> {r['typo_action']}\n")
        A(f"\n### Rejected (couldn't repair) ({len(typo_rej)})\n\n")
        if not typo_rej.empty:
            for _, r in typo_rej.iterrows():
                A(f"- msg #{r['msg_idx']} {str(r['time_utc'])[:16]} {r['side']} entry {r['entry']} sl {r['sl']}\n")
        A(f"\n### Canceled by later opposite signal ({len(cancels)})\n\n")
        if not cancels.empty:
            for _, r in cancels.iterrows():
                A(f"- msg #{r['msg_idx']} {str(r['time_utc'])[:16]} {r['side']} entry {r['entry']}: {r['cancel_status']}\n")

    out_path.write_text(''.join(lines), encoding='utf-8')


# ===========================================================================
# Per-file driver
# ===========================================================================
def process_file(signal_path: Path, ticks_by_profile: dict, calendar_df: pd.DataFrame, out_root: Path):
    print(f"\n{'='*70}\nProcessing {signal_path.name}\n{'='*70}")
    raw = parse_discord_csv(signal_path)
    print(f"  parsed {len(raw)} signals")

    sig_with_typo, typo_stats = typo_check_and_repair(raw)
    print(f"  typo check: {typo_stats}")

    cancel_stats = apply_cancellations(sig_with_typo)
    print(f"  cancellations: {cancel_stats}")

    surviving = [s for s in sig_with_typo if not s.skip_reason]
    n_xau = sum(1 for s in surviving if s.symbol == 'XAUUSD')
    n_other = len(surviving) - n_xau
    print(f"  surviving: {len(surviving)} total -> {n_xau} XAU (replayed) + {n_other} other (skipped, no tick data)")

    if n_xau == 0:
        print(f"  no XAU signals - skipping")
        return None, None

    out_dir = out_root / signal_path.stem
    out_dir.mkdir(parents=True, exist_ok=True)

    # Audit CSV: every parsed signal with its typo/cancel status
    audit_rows = []
    for s in sig_with_typo:
        audit_rows.append({
            'msg_idx': s.msg_idx, 'time_utc': s.time_utc, 'author': s.author,
            'symbol': s.symbol, 'side': s.side, 'entry': s.entry, 'sl': s.sl,
            'n_tps': len(s.tps), 'tps': '|'.join(f"{t:.2f}" for t in s.tps),
            'typo_action': s.typo_action, 'cancel_status': s.cancel_status,
            'skip_reason': s.skip_reason,
        })
    audit = pd.DataFrame(audit_rows)
    audit.to_csv(out_dir / 'audit.csv', index=False)
    print(f"  wrote {len(audit)} audit rows -> audit.csv")

    print(f"  running matrix ({len(SPREAD_PROFILES)*len(EXIT_POLICIES)*len(RISK_LEVELS)} configs x {n_xau} signals)...")
    outcomes = run_one_file(sig_with_typo, ticks_by_profile, calendar_df)
    outcomes.to_csv(out_dir / 'signal_outcomes.csv', index=False)
    print(f"  wrote {len(outcomes)} rows -> signal_outcomes.csv")

    # Daily aggregation
    outcomes['date'] = pd.to_datetime(outcomes['signal_time_utc']).dt.date
    daily = (outcomes.groupby(['date', 'spread_profile', 'exit_policy', 'risk_pct'], as_index=False)
             .agg(n_signals=('msg_idx', 'count'),
                  daily_net_pnl=('net_pnl', 'sum'),
                  starting_equity=('equity_pre', 'first'),
                  ending_equity=('equity_post', 'last')))
    daily['daily_pnl_pct'] = (daily['daily_net_pnl'] / daily['starting_equity'] * 100).round(3)
    daily.to_csv(out_dir / 'daily_pnl.csv', index=False)
    print(f"  wrote {len(daily)} daily rows -> daily_pnl.csv")

    sizing = discover_optimal_sizing(daily)
    sizing.to_csv(out_dir / 'sizing_discovery.csv', index=False)
    print(f"  wrote {len(sizing)} sizing rows -> sizing_discovery.csv")

    write_verdict(outcomes, daily, sizing, out_dir / 'verdict.md',
                  source_label=signal_path.name,
                  typo_stats=typo_stats, cancel_stats=cancel_stats,
                  total_signals_parsed=len(raw),
                  audit=audit)
    print(f"  wrote verdict.md")
    return outcomes, sizing


# ===========================================================================
# Comparison writer
# ===========================================================================
def write_comparison(per_file: dict, out_path: Path):
    lines, A = [], lambda s: lines.append(s)
    A("# Provider comparison\n\n")
    A("| Provider | Best avg/day (within DD) | Best total return (within DD) | Best Sharpe (within DD) |\n")
    A("|---|---|---|---|\n")
    for name, (_, sizing) in per_file.items():
        if sizing is None or sizing.empty:
            A(f"| {name} | n/a | n/a | n/a |\n")
            continue
        safe = sizing[sizing['within_dd_ceiling']]
        if safe.empty:
            safe = sizing  # fall back to all
        bad = safe.sort_values('avg_daily_pct', ascending=False).iloc[0]
        bt = safe.sort_values('total_return_pct', ascending=False).iloc[0]
        bs = safe.sort_values('sharpe_proxy', ascending=False).iloc[0]
        A(f"| {name} | {bad['avg_daily_pct']:+.3f}% ({bad['spread_profile']}/{bad['exit_policy']}/{bad['risk_pct']}%) "
          f"DD={bad['max_dd_pct']:.1f}% | "
          f"{bt['total_return_pct']:+.2f}% ({bt['spread_profile']}/{bt['exit_policy']}/{bt['risk_pct']}%) | "
          f"{bs['sharpe_proxy']:.2f} ({bs['spread_profile']}/{bs['exit_policy']}/{bs['risk_pct']}%) |\n")
    out_path.write_text(''.join(lines), encoding='utf-8')
    print(f"\nWrote {out_path}")


# ===========================================================================
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--signals-dir', type=Path, default=SIGNALS_DIR_DEFAULT)
    ap.add_argument('--tick-root', type=Path, default=TICK_ROOT_DEFAULT)
    ap.add_argument('--calendar', type=Path, default=CALENDAR_DEFAULT)
    ap.add_argument('--out', type=Path, default=OUT_DEFAULT)
    ap.add_argument('--files', nargs='+', default=['signals1.csv', 'tnfx.csv'])
    args = ap.parse_args()

    # Pre-parse signals from each file to determine date range
    print("Pre-parsing signals to determine tick load range...")
    all_signals_by_file = {}
    min_t, max_t = None, None
    for f in args.files:
        p = args.signals_dir / f
        sigs = parse_discord_csv(p)
        all_signals_by_file[f] = sigs
        for s in sigs:
            if min_t is None or s.time_utc < min_t:
                min_t = s.time_utc
            if max_t is None or s.time_utc > max_t:
                max_t = s.time_utc
    if min_t is None:
        print("ERROR: no signals parsed")
        return
    # Pad load range a bit
    load_start = (min_t - pd.Timedelta(days=1)).strftime('%Y-%m-%d %H:%M:%S')
    load_end   = (max_t + pd.Timedelta(days=2)).strftime('%Y-%m-%d %H:%M:%S')
    print(f"  signals span {min_t} -> {max_t}")
    print(f"  loading ticks {load_start} -> {load_end}")

    print(f"\nLoading calendar...")
    calendar_df = load_calendar(args.calendar)

    print(f"\nLoading tick data:")
    ticks_by_profile = {}
    for prof, fname in PROFILE_FILES.items():
        fp = args.tick_root / fname
        print(f"  {prof}: {fp.name}", flush=True)
        t0 = datetime.now()
        df = load_ticks(fp, load_start, load_end)
        dt = (datetime.now() - t0).total_seconds()
        print(f"    {len(df):,} ticks loaded in {dt:.1f}s")
        if df.empty:
            raise RuntimeError(f"empty tick data for {prof}")
        ticks_by_profile[prof] = df

    per_file = {}
    for f in args.files:
        p = args.signals_dir / f
        result = process_file(p, ticks_by_profile, calendar_df, args.out)
        per_file[f] = result

    write_comparison(per_file, args.out / 'comparison.md')


if __name__ == '__main__':
    main()
