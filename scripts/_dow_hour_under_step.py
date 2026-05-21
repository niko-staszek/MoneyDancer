"""DOW × hour P&L map under STEP variant (first-half cells only — STEP results).

Group out-deals by (day-of-week, hour-of-day). Identify if Monday/Friday have
systematically bad hours that should be DOW-specific blocked.
"""
from __future__ import annotations
import csv
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
RUNS = REPO / "runs"

# STEP first-half cells (have trades.csv from full sweep)
CELLS = [
    ("jan25", "STEP-5k-jan25-2wk"),
    ("feb25", "STEP-5k-feb25-2wk"),
    ("mar25", "BM-STEP-5k-mar25-2wk"),
    ("apr25", "STEP-5k-apr25-2wk"),
    ("may25", "STEP-5k-may25-2wk"),
    ("jun25", "STEP-5k-jun25-2wk"),
    ("jul25", "STEP-5k-jul25-2wk"),
    ("aug25", "STEP-5k-aug25-2wk"),
    ("sep25", "STEP-5k-sep25-2wk"),
    ("oct25", "STEP-5k-oct25-2wk"),
    ("nov25", "STEP-5k-nov25-2wk"),
    ("dec25", "BM-STEP-5k-dec25-2wk"),
    ("jan26", "BM-STEP-5k-jan26-2wk"),
    ("feb26", "STEP-5k-feb26-2wk"),
    ("mar26", "STEP-5k-mar26-2wk"),
    ("apr26", "BM-STEP-5k-apr26-2wk"),
    ("may26", "STEP-5k-may26-2wk"),
]

DOWS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]


def load_or_extract_trades(folder: Path):
    trades = folder / "trades.csv"
    if not trades.exists():
        # Try to extract from report
        report = list(folder.glob("*-report.htm"))
        if report:
            import subprocess
            subprocess.run(
                ["python", str(REPO / "scripts" / "extract_trades_from_report.py"),
                 "--report", str(report[0]), "--out", str(trades)],
                capture_output=True
            )
    if not trades.exists():
        return None
    return trades


def main() -> int:
    # agg[(dow, hour)] = {profit, n, wins, losses, cells_with_data, cells_neg}
    agg = defaultdict(lambda: {"profit": 0.0, "n": 0, "wins": 0, "losses": 0})
    # per_cell_dow_hour[(cell, dow, hour)] = profit
    per_cell_dow_hour = defaultdict(float)

    for label, folder_name in CELLS:
        folder = RUNS / folder_name
        trades_path = load_or_extract_trades(folder)
        if trades_path is None:
            continue
        with trades_path.open(encoding="utf-8", errors="ignore") as f:
            rdr = csv.DictReader(f)
            for row in rdr:
                if row.get("direction") != "out":
                    continue
                ts = row.get("time", "")
                if len(ts) < 13:
                    continue
                try:
                    dt = datetime.strptime(ts[:19], "%Y.%m.%d %H:%M:%S")
                    profit = float(row.get("profit", "0"))
                except (ValueError, TypeError):
                    continue
                dow = dt.weekday()  # 0=Mon..6=Sun
                hr = dt.hour
                agg[(dow, hr)]["profit"] += profit
                agg[(dow, hr)]["n"] += 1
                if profit > 0:
                    agg[(dow, hr)]["wins"] += 1
                elif profit < 0:
                    agg[(dow, hr)]["losses"] += 1
                per_cell_dow_hour[(label, dow, hr)] += profit

    # Print DOW × hour table
    print("=== DOW × hour aggregate (out-deals profit$ across 17 STEP cells) ===")
    header = "HH " + "  ".join(f"{d:>7}" for d in DOWS[:5])  # Mon-Fri only (no Sat/Sun in tester)
    print(header)
    for hr in range(24):
        row = [f"{hr:2d}"]
        for d in range(5):  # Mon-Fri
            cell = agg.get((d, hr))
            if cell is None:
                row.append("       ")
            else:
                row.append(f"{cell['profit']:>7.0f}")
        print(" ".join(row))

    # Identify DOW-specific bad hours
    print("\n=== Candidate DOW × hour BLOCKS (sum profit < 0 AND neg in >=10 cells) ===")
    flagged = []
    for d in range(5):
        for hr in range(24):
            cell = agg.get((d, hr))
            if cell is None or cell["n"] == 0:
                continue
            # Count cells where this (DOW, hour) was negative
            cells_neg = 0
            cells_active = 0
            for label, _ in CELLS:
                p = per_cell_dow_hour.get((label, d, hr), None)
                # If no key, no trades — skip from "active" count
                key_present = (label, d, hr) in per_cell_dow_hour
                if not key_present:
                    continue
                cells_active += 1
                if p < 0:
                    cells_neg += 1
            if cell["profit"] < 0 and cells_neg >= 10:
                flagged.append((d, hr, cell["profit"], cells_neg, cells_active))
                print(f"  {DOWS[d]} HH={hr}: ${cell['profit']:.0f} aggregate, neg in {cells_neg}/{cells_active} cells")

    if not flagged:
        print("  (no DOW × hour combination clearly bad across cells)")

    return 0


if __name__ == "__main__":
    sys.exit(main())
