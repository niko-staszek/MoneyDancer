"""S2.C.9 — Per-(DOW, regime, hour) profitability aggregation.

Joins per-cell trades.csv (from MT5 report.htm) with per-cell regime trace
(MoneyDancer_regime_*.csv written by RegimeTrace.mqh when UseRegimeTrace=true)
to produce a cross-cell DOW × regime × hour heatmap.

Usage:
  python scripts/_s2c9_regime_breakdown.py CELL1 CELL2 ...
  python scripts/_s2c9_regime_breakdown.py --all-h1   # all 17 H1 cells

Each cell needs:
  runs/<cell>/trades.csv                     — extracted from report.htm
  runs/<cell>/MoneyDancer_regime_*.csv       — written by EA when trace ON

Output:
  - per-(DOW, regime, hour) sum profit + count
  - per-(DOW, regime, hour) flagged as "consistently bad" if:
      * negative aggregate AND
      * negative in >=N/M cells (default 60% threshold)
"""
from __future__ import annotations
import csv
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
RUNS = REPO / "runs"

REGIME_LABELS = {-1: "BEAR", 0: "RANGE", 1: "BULL"}
DOW_LABELS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]


def load_trades(cell_dir: Path) -> dict[int, dict]:
    """Returns ticket → {time, profit, dir} (only out-deals)."""
    trades_path = cell_dir / "trades.csv"
    if not trades_path.exists():
        return {}
    out = {}
    with trades_path.open(encoding="utf-8", errors="ignore") as f:
        for row in csv.DictReader(f):
            if row.get("direction") != "out":
                continue
            try:
                ticket = int(row["order"])
                ts = datetime.strptime(row["time"][:19], "%Y.%m.%d %H:%M:%S")
                profit = float(row.get("profit", 0))
                # type: 0=buy, 1=sell — out-deal direction is opposite of position dir
                # we want POSITION dir, which is the opposite of the out-deal type
                out_type = row.get("type", "")
                pos_dir = -1 if out_type == "buy" else 1
                out[ticket] = {"time": ts, "profit": profit, "dir": pos_dir}
            except (KeyError, ValueError):
                continue
    return out


def load_regime_trace(cell_dir: Path) -> dict[int, dict]:
    """Returns ticket → regime at OPEN time."""
    for candidate in cell_dir.glob("MoneyDancer_regime_*.csv"):
        out = {}
        with candidate.open(encoding="utf-8", errors="ignore") as f:
            for row in csv.DictReader(f):
                if row.get("event") != "open":
                    continue
                try:
                    ticket = int(row["ticket"])
                    out[ticket] = {
                        "regime": int(row["regime"]),
                        "slope":  int(row["slope"]),
                    }
                except (KeyError, ValueError):
                    continue
        return out
    return {}


def aggregate(cells: list[tuple[str, Path]]) -> dict:
    """key = (dow, regime, hour) → {profit_sum, n_trades, n_cells_negative}."""
    cell_keyed = defaultdict(lambda: defaultdict(float))  # cell → key → profit
    cell_keyed_n = defaultdict(lambda: defaultdict(int))

    for label, cell_dir in cells:
        trades = load_trades(cell_dir)
        regime = load_regime_trace(cell_dir)
        if not trades:
            print(f"  WARN: {label}: no trades.csv (extract first via extract_trades_from_report.py)")
            continue
        if not regime:
            print(f"  WARN: {label}: no regime trace (was UseRegimeTrace=false?)")
            continue
        matched = 0
        for ticket, t in trades.items():
            r = regime.get(ticket)
            if r is None:
                continue
            key = (t["time"].weekday(), r["regime"], t["time"].hour)
            cell_keyed[label][key] += t["profit"]
            cell_keyed_n[label][key] += 1
            matched += 1
        print(f"  {label}: {matched}/{len(trades)} trades matched to regime trace")

    # Aggregate across cells
    agg = defaultdict(lambda: {"profit_sum": 0.0, "n_trades": 0, "n_cells_active": 0, "n_cells_negative": 0})
    for label, key_map in cell_keyed.items():
        for key, profit in key_map.items():
            agg[key]["profit_sum"] += profit
            agg[key]["n_trades"] += cell_keyed_n[label][key]
            agg[key]["n_cells_active"] += 1
            if profit < 0:
                agg[key]["n_cells_negative"] += 1

    return agg


def report(agg: dict, n_total_cells: int, neg_threshold_pct: float = 0.6) -> None:
    # Sort by profit ascending — worst first
    ranked = sorted(agg.items(), key=lambda kv: kv[1]["profit_sum"])

    print()
    print("=== Worst (DOW, regime, hour) combinations ===")
    print(f"{'DOW':<4} {'Regime':<6} {'HH':<3} {'profit_sum':>12} {'trades':>8} {'cells_act':>10} {'cells_neg':>10}")
    flagged = []
    for (dow, regime, hour), v in ranked[:30]:
        if v["profit_sum"] >= 0:
            continue
        cells_neg_pct = (v["n_cells_negative"] / v["n_cells_active"]) if v["n_cells_active"] else 0
        is_flagged = (cells_neg_pct >= neg_threshold_pct and v["n_cells_active"] >= 5)
        flag = "  <-- FLAG" if is_flagged else ""
        print(f"{DOW_LABELS[dow]:<4} {REGIME_LABELS.get(regime, '?'):<6} {hour:<3} "
              f"{v['profit_sum']:>12.2f} {v['n_trades']:>8} {v['n_cells_active']:>10} "
              f"{v['n_cells_negative']:>10}{flag}")
        if is_flagged:
            flagged.append((dow, regime, hour))

    print()
    print("=== Flagged blocking candidates ===")
    if not flagged:
        print("  (none meet threshold — consistent with the 'path-dependence dominates' finding)")
    else:
        print(f"  {len(flagged)} (DOW, regime, hour) combinations flagged.")
        print("  Configure as `HourBlockListByRegimeDOW` (new input) and sample-test on 5 cells.")


def main():
    if len(sys.argv) < 2:
        print("Usage: python scripts/_s2c9_regime_breakdown.py CELL1 CELL2 ... | --all-h1")
        return 1

    args = sys.argv[1:]
    if "--all-h1" in args:
        h1_cells = [
            "STEP-5k-jan25-2wk", "STEP-5k-feb25-2wk", "BM-STEP-5k-mar25-2wk",
            "STEP-5k-apr25-2wk", "STEP-5k-may25-2wk", "STEP-5k-jun25-2wk",
            "STEP-5k-jul25-2wk", "STEP-5k-aug25-2wk", "STEP-5k-sep25-2wk",
            "STEP-5k-oct25-2wk", "STEP-5k-nov25-2wk", "BM-STEP-5k-dec25-2wk",
            "BM-STEP-5k-jan26-2wk", "STEP-5k-feb26-2wk", "STEP-5k-mar26-2wk",
            "BM-STEP-5k-apr26-2wk", "STEP-5k-may26-2wk",
        ]
        cells = [(c, RUNS / c) for c in h1_cells if (RUNS / c).exists()]
    else:
        cells = [(c, RUNS / c) for c in args]

    print(f"Aggregating {len(cells)} cells...")
    agg = aggregate(cells)
    report(agg, n_total_cells=len(cells))
    return 0


if __name__ == "__main__":
    sys.exit(main())
