"""Find the worst basket-closes in a trades.csv and characterize them.

A "basket close" is a cluster of `out` deals at ~the same timestamp that
flatten a series. We group out-deals by series-key (TBbN / TBsN) and
compute the net basket PnL when the series goes back to zero positions.
"""
import sys
import csv
from collections import defaultdict
from pathlib import Path

trades_path = Path(sys.argv[1])
rows = []
with trades_path.open() as f:
    reader = csv.DictReader(f)
    for r in reader:
        rows.append(r)

# Extract series key from comment ("TBb7|D=3" -> "TBb7")
def series_key(cmt):
    import re
    m = re.match(r"(TB[bs]\d+)", cmt)
    return m.group(1) if m else None

# Aggregate per series: total P&L and timing
series_pnl = defaultdict(lambda: {"profit": 0.0, "first": None, "last": None,
                                   "in_count": 0, "out_count": 0,
                                   "max_lot": 0.0, "total_lot": 0.0,
                                   "first_price": None, "last_price": None})
for r in rows:
    sk = series_key(r["comment"])
    if not sk: continue
    s = series_pnl[sk]
    s["profit"] += float(r["profit"])
    if r["direction"] == "in":
        s["in_count"] += 1
        lot = float(r["volume"])
        s["max_lot"] = max(s["max_lot"], lot)
        s["total_lot"] += lot
    else:
        s["out_count"] += 1
    t = r["time"]
    if s["first"] is None: s["first"] = t; s["first_price"] = float(r["price"])
    s["last"] = t
    s["last_price"] = float(r["price"])

# Sort by profit (worst first)
worst = sorted(series_pnl.items(), key=lambda x: x[1]["profit"])[:10]
print(f"  {'series':<10} {'profit':>10} {'in':>4} {'out':>4} {'max_lot':>8} {'total_lot':>10} {'price_chg_pts':>14} {'first':<20} {'last':<20}")
for sk, s in worst:
    pct = (s["last_price"] - s["first_price"]) / 0.01  # 2-digit pts
    print(f"  {sk:<10} {s['profit']:>+10.2f} {s['in_count']:>4} {s['out_count']:>4} {s['max_lot']:>8.2f} {s['total_lot']:>10.2f} {pct:>+14.0f} {s['first']:<20} {s['last']:<20}")

print()
print(f"Total series: {len(series_pnl)}")
print(f"Profitable: {sum(1 for s in series_pnl.values() if s['profit']>0)}")
print(f"Losing: {sum(1 for s in series_pnl.values() if s['profit']<0)}")
print(f"Cum: {sum(s['profit'] for s in series_pnl.values()):+.2f}")
