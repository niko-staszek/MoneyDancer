"""News-event safety classification (Sprint 2 deferred task #21).

For each calendar event, find WT trades within [event-30min, event+90min] window
and compute aggregate P&L. Classify events as SAFE/UNSAFE based on historical
profitability.
"""
from __future__ import annotations
import csv
import re
import sys
from collections import defaultdict
from datetime import datetime, timedelta
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

CELLS = [
    ("S3.2b-WT-5k-jan25-2wk", "2025-01-01", "2025-01-14"),
    ("S3.2b-WT-5k-feb25-2wk", "2025-02-01", "2025-02-14"),
    ("S3.2b-WT-5k-mar25-2wk", "2025-03-01", "2025-03-14"),
    ("S3.2b-WT-5k-apr25-2wk", "2025-04-01", "2025-04-14"),
    ("S3.2b-WT-5k-may25-2wk", "2025-05-01", "2025-05-14"),
    ("S3.2b-WT-5k-jun25-2wk", "2025-06-01", "2025-06-14"),
    ("S3.2b-WT-5k-jul25-2wk", "2025-07-01", "2025-07-14"),
    ("S3.2b-WT-5k-aug25-2wk", "2025-08-01", "2025-08-14"),
    ("S3.2b-WT-5k-sep25-2wk", "2025-09-01", "2025-09-14"),
    ("S3.2b-WT-5k-oct25-2wk", "2025-10-01", "2025-10-14"),
    ("S3.2b-WT-5k-nov25-2wk", "2025-11-01", "2025-11-14"),
    ("S3.2b-WT-5k-dec25-2wk", "2025-12-01", "2025-12-14"),
    ("S3.2b-WT-5k-jan26-2wk", "2026-01-01", "2026-01-14"),
    ("S3.2b-WT-5k-feb26-2wk", "2026-02-01", "2026-02-14"),
    ("S3.2b-WT-5k-mar26-2wk", "2026-03-01", "2026-03-14"),
    ("S3.2b-WT-5k-apr26-2wk", "2026-04-01", "2026-04-14"),
    ("S3.2b-WT-5k-may26-2wk", "2026-05-01", "2026-05-14"),
]

# Window: 30 min before, 90 min after the event
PRE_MIN = 30
POST_MIN = 90


def load_calendar(path: Path) -> list:
    """Parse the calendar CSV. Returns [(dt, currency, tier, label, semantic_group)]."""
    events = []
    with path.open(encoding="utf-8") as f:
        rdr = csv.DictReader(f)
        for row in rdr:
            try:
                # "2025-01-10T13:30:00Z"
                dt_str = row["utc_datetime"].rstrip("Z")
                dt = datetime.strptime(dt_str, "%Y-%m-%dT%H:%M:%S")
            except (KeyError, ValueError):
                continue
            currency = row.get("currency", "").strip()
            tier = row.get("tier", "").strip()
            label = row.get("label", "").strip()
            # Semantic group: take first word(s) of label
            grp = semantic_group(label)
            events.append((dt, currency, tier, label, grp))
    return events


def semantic_group(label: str) -> str:
    """Group event labels into semantic families."""
    s = label.upper()
    if "NFP" in s or "NONFARM" in s or "PAYROLL" in s:
        return "NFP"
    if "FOMC" in s or "FED RATE" in s or "INTEREST RATE" in s and "USD" in label.upper():
        return "FOMC"
    if "CPI" in s:
        return "CPI"
    if "PCE" in s or "CORE PCE" in s:
        return "PCE"
    if "ECB" in s or "DRAGHI" in s or "LAGARDE" in s:
        return "ECB"
    if "BOE" in s or "BAILEY" in s or "BANK OF ENGLAND" in s:
        return "BoE"
    if "GDP" in s:
        return "GDP"
    if "PPI" in s:
        return "PPI"
    if "RETAIL" in s and "SALES" in s:
        return "RETAIL_SALES"
    if "JOBLESS" in s or "CLAIMS" in s:
        return "JOBLESS"
    if "JACKSON HOLE" in s:
        return "JACKSON_HOLE"
    if "POWELL" in s:
        return "POWELL"
    # Fallback: first 2 words
    parts = label.split()[:2]
    return "_".join(p.upper().strip("-_") for p in parts) or "OTHER"


def load_trades_for_cell(folder: Path) -> list:
    """Return [(ts_datetime, profit)] for all out-deals."""
    trades_csv = folder / "trades.csv"
    if not trades_csv.exists():
        return []
    out_trades = []
    with trades_csv.open(encoding="utf-8", errors="ignore") as f:
        rdr = csv.DictReader(f)
        for row in rdr:
            if row.get("direction") != "out":
                continue
            try:
                # "2025.01.13 23:59:59"
                ts = datetime.strptime(row.get("time", "")[:19], "%Y.%m.%d %H:%M:%S")
                profit = float(row.get("profit", "0"))
            except (ValueError, KeyError):
                continue
            out_trades.append((ts, profit))
    return out_trades


def main() -> int:
    # Load all events from both years
    cal_2025 = load_calendar(REPO / "data" / "calendar" / "2025_full.csv")
    cal_2026 = load_calendar(REPO / "data" / "calendar" / "2026_full.csv")
    all_events = cal_2025 + cal_2026
    print(f"Loaded {len(all_events)} calendar events ({len(cal_2025)} 2025 + {len(cal_2026)} 2026)", file=sys.stderr)

    # Load all trades from WT cells
    cell_trades = {}
    for cell_folder, _, _ in CELLS:
        cell_trades[cell_folder] = load_trades_for_cell(REPO / "runs" / cell_folder)

    # For each event, find matching trades from all cells
    event_results = []  # list of (event_dt, label, grp, currency, tier, num_trades, sum_profit)
    for event_dt, currency, tier, label, grp in all_events:
        win_start = event_dt - timedelta(minutes=PRE_MIN)
        win_end = event_dt + timedelta(minutes=POST_MIN)
        sum_profit = 0.0
        n_trades = 0
        for cell_folder, _, _ in CELLS:
            for ts, profit in cell_trades.get(cell_folder, []):
                if win_start <= ts <= win_end:
                    sum_profit += profit
                    n_trades += 1
        if n_trades > 0:
            event_results.append((event_dt, label, grp, currency, tier, n_trades, sum_profit))

    # Group by semantic_group
    grp_agg = defaultdict(lambda: {"events": 0, "trades": 0, "profit": 0.0, "neg_events": 0, "pos_events": 0})
    for event_dt, label, grp, currency, tier, n_trades, sum_profit in event_results:
        g = grp_agg[grp]
        g["events"] += 1
        g["trades"] += n_trades
        g["profit"] += sum_profit
        if sum_profit < 0:
            g["neg_events"] += 1
        elif sum_profit > 0:
            g["pos_events"] += 1

    print(f"\n{'group':<20} {'events':>7} {'trades':>7} {'profit$':>10} {'pos/neg':>10} {'verdict':>10}")
    sorted_groups = sorted(grp_agg.items(), key=lambda kv: kv[1]["profit"])
    for grp, g in sorted_groups:
        avg = g["profit"] / g["events"] if g["events"] else 0
        verdict = "SAFE" if g["profit"] > 0 and g["events"] >= 5 else (
            "UNSAFE" if g["profit"] < 0 and g["events"] >= 5 else "UNKNOWN"
        )
        print(f"{grp:<20} {g['events']:>7} {g['trades']:>7} {g['profit']:>10.0f} "
              f"{g['pos_events']:>4}/{g['neg_events']:>3} {verdict:>10}")

    # Top 10 individual worst event-instances
    print("\n=== TOP 10 WORST INDIVIDUAL EVENTS ===")
    event_results_sorted = sorted(event_results, key=lambda r: r[6])
    for r in event_results_sorted[:10]:
        dt, label, grp, currency, tier, n_trades, sum_profit = r
        print(f"  {dt.isoformat()} {currency} {tier} {label[:50]:<50} -> ${sum_profit:.0f} ({n_trades} trades)")

    # Top 10 best
    print("\n=== TOP 10 BEST INDIVIDUAL EVENTS ===")
    for r in event_results_sorted[-10:][::-1]:
        dt, label, grp, currency, tier, n_trades, sum_profit = r
        print(f"  {dt.isoformat()} {currency} {tier} {label[:50]:<50} -> +${sum_profit:.0f} ({n_trades} trades)")

    return 0


if __name__ == "__main__":
    sys.exit(main())
