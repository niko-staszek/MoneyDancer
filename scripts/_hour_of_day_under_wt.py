"""S2.C.1.1 — Hour-of-day P&L map under WT.

For each of 17 WT cells, group out-deals by hour-of-day, compute sum profit and counts.
Aggregate across cells to identify consistent bad hours.
"""
from __future__ import annotations
import csv
import sys
from collections import defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
RUNS = REPO / "runs"

CELLS = [
    ("jan25", "S3.2b-WT-5k-jan25-2wk"),
    ("feb25", "S3.2b-WT-5k-feb25-2wk"),
    ("mar25", "S3.2b-WT-5k-mar25-2wk"),
    ("apr25", "S3.2b-WT-5k-apr25-2wk"),
    ("may25", "S3.2b-WT-5k-may25-2wk"),
    ("jun25", "S3.2b-WT-5k-jun25-2wk"),
    ("jul25", "S3.2b-WT-5k-jul25-2wk"),
    ("aug25", "S3.2b-WT-5k-aug25-2wk"),
    ("sep25", "S3.2b-WT-5k-sep25-2wk"),
    ("oct25", "S3.2b-WT-5k-oct25-2wk"),
    ("nov25", "S3.2b-WT-5k-nov25-2wk"),
    ("dec25", "S3.2b-WT-5k-dec25-2wk"),
    ("jan26", "S3.2b-WT-5k-jan26-2wk"),
    ("feb26", "S3.2b-WT-5k-feb26-2wk"),
    ("mar26", "S3.2b-WT-5k-mar26-2wk"),
    ("apr26", "S3.2b-WT-5k-apr26-2wk"),
    ("may26", "S3.2b-WT-5k-may26-2wk"),
]


def analyze_cell(folder: Path) -> dict:
    """Return: {hour: {profit, wins, losses, total}}"""
    trades = folder / "trades.csv"
    if not trades.exists():
        return {}
    by_hour: dict[int, dict] = defaultdict(lambda: {"profit": 0.0, "wins": 0, "losses": 0, "total": 0})
    with trades.open(encoding="utf-8", errors="ignore") as f:
        rdr = csv.DictReader(f)
        for row in rdr:
            if row.get("direction") != "out":
                continue
            ts = row.get("time", "")
            if len(ts) < 13:
                continue
            try:
                hr = int(ts[11:13])
                profit = float(row.get("profit", "0"))
            except (ValueError, TypeError):
                continue
            by_hour[hr]["profit"] += profit
            by_hour[hr]["total"] += 1
            if profit > 0:
                by_hour[hr]["wins"] += 1
            elif profit < 0:
                by_hour[hr]["losses"] += 1
    return by_hour


def main() -> int:
    cell_hours: dict[str, dict] = {}
    for label, folder_name in CELLS:
        cell_hours[label] = analyze_cell(RUNS / folder_name)

    # Aggregate across cells
    agg = defaultdict(lambda: {"profit": 0.0, "wins": 0, "losses": 0, "total": 0, "cells_neg": 0, "cells_pos": 0, "cells_trading": 0})
    for cell_label, hours in cell_hours.items():
        for hr in range(24):
            h = hours.get(hr)
            if h is None or h["total"] == 0:
                continue
            agg[hr]["profit"] += h["profit"]
            agg[hr]["wins"] += h["wins"]
            agg[hr]["losses"] += h["losses"]
            agg[hr]["total"] += h["total"]
            agg[hr]["cells_trading"] += 1
            if h["profit"] < 0:
                agg[hr]["cells_neg"] += 1
            elif h["profit"] > 0:
                agg[hr]["cells_pos"] += 1

    print(f"{'HH':>3} {'profit$':>10} {'trades':>7} {'wins':>5} {'losses':>5} {'win%':>5} {'cells_pos/neg/total':>20}")
    for hr in range(24):
        a = agg.get(hr)
        if a is None:
            print(f"{hr:>3}  no trades")
            continue
        if a["total"] == 0:
            continue
        win_pct = (a["wins"] / a["total"] * 100) if a["total"] else 0
        print(f"{hr:>3} {a['profit']:>10.0f} {a['total']:>7} {a['wins']:>5} {a['losses']:>5} {win_pct:>4.0f}% "
              f"{a['cells_pos']:>4}/{a['cells_neg']:>2}/{a['cells_trading']:>2}")

    # Flag bad hours
    print("\n=== Candidate bad hours (sum profit < 0 AND negative in >=10/17 cells) ===")
    for hr in range(24):
        a = agg.get(hr)
        if a is None or a["total"] == 0:
            continue
        if a["profit"] < 0 and a["cells_neg"] >= 10:
            print(f"  HH={hr}: ${a['profit']:.0f} aggregate, negative in {a['cells_neg']}/{a['cells_trading']} cells")
    print("\n=== Marginal hours (sum profit < +$50 OR negative in >=8 cells) ===")
    for hr in range(24):
        a = agg.get(hr)
        if a is None or a["total"] == 0:
            continue
        if a["profit"] < 50 or a["cells_neg"] >= 8:
            print(f"  HH={hr}: ${a['profit']:.0f} aggregate, negative in {a['cells_neg']}/{a['cells_trading']} cells")

    return 0


if __name__ == "__main__":
    sys.exit(main())
