"""Find the worst drawdown windows in a trades.csv.

Walks the balance time-series, identifies peak->trough drops, and lists
the trades within each top-N drawdown.
"""
import sys
import csv
from pathlib import Path
from datetime import datetime

trades_path = Path(sys.argv[1])
rows = []
with trades_path.open() as f:
    reader = csv.DictReader(f)
    for r in reader:
        rows.append(r)

# Build (time, balance, deal_idx) series from OUT deals (balance updates on close)
balance_series = []
for i, r in enumerate(rows):
    if r["direction"] == "out":
        balance_series.append((r["time"], float(r["balance"]), i))

# Find top drawdown windows: scan for peak->trough drops
peak = balance_series[0][1] if balance_series else 0
peak_t = balance_series[0][0] if balance_series else ""
peak_i = 0
dds = []
for j, (t, b, idx) in enumerate(balance_series):
    if b > peak:
        peak = b; peak_t = t; peak_i = j
    dd_amt = peak - b
    if dd_amt > 0:
        dds.append({"trough_time": t, "trough_bal": b, "peak_time": peak_t,
                    "peak_bal": peak, "dd_amt": dd_amt, "dd_pct": dd_amt/peak*100,
                    "trough_j": j, "peak_j": peak_i})

# Filter to "deepest within a drawdown phase": consolidate consecutive drops
# Keep only local trough (next deal is higher than trough)
local_troughs = []
for k in range(len(dds)):
    is_local = (k == len(dds)-1) or (dds[k+1]["trough_bal"] > dds[k]["trough_bal"])
    if is_local:
        local_troughs.append(dds[k])

# Sort by DD amount, take top 8
top = sorted(local_troughs, key=lambda x: -x["dd_amt"])[:8]
print(f"  {'#':<3} {'peak':>10} {'trough':>10} {'dd $':>10} {'dd %':>7} {'peak_time':<20} {'trough_time':<20} {'duration':<12}")
for k, d in enumerate(top, 1):
    # duration
    pt = datetime.strptime(d["peak_time"], "%Y.%m.%d %H:%M:%S")
    tt = datetime.strptime(d["trough_time"], "%Y.%m.%d %H:%M:%S")
    dur = tt - pt
    print(f"  {k:<3} {d['peak_bal']:>10.2f} {d['trough_bal']:>10.2f} {d['dd_amt']:>10.2f} {d['dd_pct']:>6.2f}% {d['peak_time']:<20} {d['trough_time']:<20} {str(dur):<12}")

# For the deepest, list its trades
if top:
    d = top[0]
    print(f"\n--- WORST DD: peak ${d['peak_bal']:.2f} -> trough ${d['trough_bal']:.2f} (-${d['dd_amt']:.2f}) ---")
    print(f"--- {d['peak_time']} -> {d['trough_time']} ---")
    # Show OUT deals in this window
    print(f"  {'time':<20} {'side':<5} {'lot':>6} {'price':>10} {'profit':>10} {'balance':>10}")
    pj = d["peak_j"]
    tj = d["trough_j"]
    for j in range(pj, tj+1):
        t, b, idx = balance_series[j]
        r = rows[idx]
        # only show losing ones for brevity
        prof = float(r["profit"])
        print(f"  {r['time']:<20} {r['type']:<5} {r['volume']:>6} {float(r['price']):>10.2f} {prof:>+10.2f} {float(r['balance']):>10.2f}")
