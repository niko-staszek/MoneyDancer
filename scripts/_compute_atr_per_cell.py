"""Compute M15 ATR for each of the 17 WT cells.

Optimized: single pass per CSV, partition into cell buckets simultaneously.
"""
from __future__ import annotations
import csv
import sys
from datetime import datetime, timedelta
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

CELLS_2025 = [
    ("jan25", "2025-01-01", "2025-01-15"),
    ("feb25", "2025-02-01", "2025-02-15"),
    ("mar25", "2025-03-01", "2025-03-15"),
    ("apr25", "2025-04-01", "2025-04-15"),
    ("may25", "2025-05-01", "2025-05-15"),
    ("jun25", "2025-06-01", "2025-06-15"),
    ("jul25", "2025-07-01", "2025-07-15"),
    ("aug25", "2025-08-01", "2025-08-15"),
    ("sep25", "2025-09-01", "2025-09-15"),
    ("oct25", "2025-10-01", "2025-10-15"),
    ("nov25", "2025-11-01", "2025-11-15"),
    ("dec25", "2025-12-01", "2025-12-15"),
]
CELLS_2026 = [
    ("jan26", "2026-01-01", "2026-01-15"),
    ("feb26", "2026-02-01", "2026-02-15"),
    ("mar26", "2026-03-01", "2026-03-15"),
    ("apr26", "2026-04-01", "2026-04-15"),
    ("may26", "2026-05-01", "2026-05-15"),
]


def m15_key(ts_str: str) -> str:
    """Bucket ts to M15 — keep as string for fast hash."""
    # "2025-01-02 23:14:55.455" -> "2025-01-02 23:00:00" (15-min bucket)
    minute = int(ts_str[14:16])
    bucketed_minute = (minute // 15) * 15
    return ts_str[:14] + f"{bucketed_minute:02d}:00"


def process_csv(csv_path: Path, cells: list, out: dict) -> None:
    """Single pass. For each cell, accumulate M15 OHLC bars."""
    # cells: list of (label, from_str, to_str)
    cell_ranges = []
    for label, f, t in cells:
        cell_ranges.append((label, f"{f} 00:00:00", f"{t} 00:00:00"))

    # bars[label] = dict[bucket_key -> [o, h, l, c]]
    bars = {label: {} for label, _, _ in cells}

    with csv_path.open(encoding="utf-8") as f:
        rdr = csv.reader(f)
        next(rdr, None)  # header
        for row in rdr:
            if len(row) < 3:
                continue
            ts = row[0]
            if not ts:
                continue
            # Quick range check
            in_any_cell = None
            for label, from_s, to_s in cell_ranges:
                if from_s <= ts < to_s:
                    in_any_cell = label
                    break
            if in_any_cell is None:
                continue
            try:
                bid = float(row[1])
                ask = float(row[2])
            except (ValueError, IndexError):
                continue
            mid = (bid + ask) / 2.0
            bucket = m15_key(ts)
            b = bars[in_any_cell].get(bucket)
            if b is None:
                bars[in_any_cell][bucket] = [mid, mid, mid, mid]
            else:
                b[1] = max(b[1], mid)
                b[2] = min(b[2], mid)
                b[3] = mid

    # Compute ATR per cell
    for label, _, _ in cells:
        cell_bars = bars[label]
        sorted_keys = sorted(cell_bars.keys())
        if len(sorted_keys) < 15:
            out[label] = {"n_bars": len(sorted_keys), "mean_atr_pts": 0, "p10": 0, "p25": 0, "p50": 0, "p75": 0, "min": 0, "max": 0}
            continue
        trs = []
        for i, k in enumerate(sorted_keys):
            o, h, l, c = cell_bars[k]
            if i == 0:
                tr = h - l
            else:
                prev_c = cell_bars[sorted_keys[i - 1]][3]
                tr = max(h - l, abs(h - prev_c), abs(l - prev_c))
            trs.append(tr)
        period = 14
        atrs = []
        for i in range(period - 1, len(trs)):
            window = trs[i - period + 1: i + 1]
            atrs.append(sum(window) / period)
        atr_pts = [a * 100 for a in atrs]  # _Point=0.01 for XAUUSD 2-digit
        atr_pts_sorted = sorted(atr_pts)
        n = len(atr_pts_sorted)
        out[label] = {
            "n_bars": len(sorted_keys),
            "mean_atr_pts": sum(atr_pts) / n,
            "p10": atr_pts_sorted[max(0, n // 10)],
            "p25": atr_pts_sorted[n // 4],
            "p50": atr_pts_sorted[n // 2],
            "p75": atr_pts_sorted[3 * n // 4],
            "min": atr_pts_sorted[0],
            "max": atr_pts_sorted[-1],
        }


def main() -> int:
    results = {}
    print("Processing 2025 ticks...", file=sys.stderr)
    process_csv(REPO / "data" / "duka" / "XAUUSD_2025_robo.csv", CELLS_2025, results)
    print("Processing 2026 ticks...", file=sys.stderr)
    process_csv(REPO / "data" / "duka" / "XAUUSD_2026_jan-may_robo.csv", CELLS_2026, results)

    print(f"{'cell':<6} {'bars':>5} {'mean':>6} {'p10':>5} {'p25':>5} {'p50':>5} {'p75':>5} {'min':>5} {'max':>6}")
    for label, _, _ in CELLS_2025 + CELLS_2026:
        r = results.get(label)
        if not r:
            print(f"{label}:  MISSING")
            continue
        print(
            f"{label:<6} {r['n_bars']:>5} "
            f"{r['mean_atr_pts']:>6.0f} {r['p10']:>5.0f} {r['p25']:>5.0f} "
            f"{r['p50']:>5.0f} {r['p75']:>5.0f} {r['min']:>5.0f} {r['max']:>6.0f}"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
