"""Quick distribution stats on Dukascopy spreads (in MQL 'points' units).

For 2-digit gold target symbol, 1 point = 0.01 USD. Spread in points = (ask - bid) / 0.01.
We sample the big CSV (every Nth line) to stay fast on 3.2GB.
"""

from __future__ import annotations

import csv
import statistics
import sys
from pathlib import Path


CSV = Path(
    r"C:\Users\nikof\Documents\GitHub\MoneyDancer\.claude\worktrees\reverent-panini-6271e7"
    r"\data\duka\XAUUSD_2026_jan-may.csv"
)

# Sample every N lines (= every N ticks).
SAMPLE_EVERY = 50

# Restrict to January only by date prefix (UTC).
DATE_PREFIX = "2026-01"


def main() -> int:
    spreads_pts: list[float] = []
    with CSV.open("r", encoding="utf-8") as f:
        r = csv.reader(f)
        next(r)  # header
        for i, row in enumerate(r):
            if i % SAMPLE_EVERY != 0:
                continue
            if not row[0].startswith(DATE_PREFIX):
                # Stop reading once we leave January
                if row[0] > "2026-02":
                    break
                continue
            try:
                bid = float(row[1])
                ask = float(row[2])
            except ValueError:
                continue
            spread_usd = ask - bid
            spread_pts = spread_usd / 0.01  # 2-digit gold → 1 point = $0.01
            if 0 < spread_pts < 10000:
                spreads_pts.append(spread_pts)

    spreads_pts.sort()
    n = len(spreads_pts)
    if n == 0:
        print("no samples")
        return 1

    def pct(p: float) -> float:
        idx = int(n * p)
        idx = min(idx, n - 1)
        return spreads_pts[idx]

    print(f"Samples (Jan 2026, every {SAMPLE_EVERY}th tick): {n:,}")
    print(f"  min:   {spreads_pts[0]:.1f} pts")
    print(f"  p10:   {pct(0.10):.1f}")
    print(f"  p25:   {pct(0.25):.1f}")
    print(f"  p50:   {pct(0.50):.1f}  (median)")
    print(f"  p75:   {pct(0.75):.1f}")
    print(f"  p90:   {pct(0.90):.1f}")
    print(f"  p95:   {pct(0.95):.1f}")
    print(f"  p99:   {pct(0.99):.1f}")
    print(f"  max:   {spreads_pts[-1]:.1f}")
    print(f"  mean:  {statistics.fmean(spreads_pts):.1f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
