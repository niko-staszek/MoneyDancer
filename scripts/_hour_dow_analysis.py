"""Per-hour-of-day and per-day-of-week breakdown of basket close P&L.

Walks every trades.csv in runs/, aggregates OUT-deals by (DOW, hour),
reports mean profit + trade count + win rate per bucket.

Server time = broker time (RoboForex-Pro = EET = UTC+2 winter, UTC+3 summer).
"""
import csv
import glob
import sys
from collections import defaultdict
from datetime import datetime

ROOT = sys.argv[1] if len(sys.argv) > 1 else "runs"
patterns = [
    f"{ROOT}/S2.0a-OOSv2-5k-*-2wk-rails-on/trades.csv",
    f"{ROOT}/S2.0a-5k-*-rails-on/trades.csv",
    f"{ROOT}/S2.0a-5k-*-2wk-rails-on/trades.csv",
]

files = []
for p in patterns:
    files.extend(glob.glob(p))
files = sorted(set(files))
print(f"Analyzing {len(files)} trade files...\n")

DOW_NAMES = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
# (hour, dow) -> [profits]
by_hour = defaultdict(list)
by_dow_hour = defaultdict(list)
by_dow = defaultdict(list)

total_out = 0
for f in files:
    try:
        with open(f) as fp:
            for r in csv.DictReader(fp):
                if r["direction"] != "out": continue
                try:
                    p = float(r["profit"])
                    dt = datetime.strptime(r["time"], "%Y.%m.%d %H:%M:%S")
                except: continue
                by_hour[dt.hour].append(p)
                by_dow[dt.weekday()].append(p)
                by_dow_hour[(dt.weekday(), dt.hour)].append(p)
                total_out += 1
    except Exception as e:
        print(f"skip {f}: {e}")

print(f"Total OUT deals: {total_out:,}\n")

def fmt_row(profits, label):
    if not profits:
        return f"  {label:<8}    n=0"
    n = len(profits)
    s = sum(profits)
    avg = s / n
    wins = sum(1 for p in profits if p > 0)
    return f"  {label:<8}  n={n:>6}  sum=${s:>+10.2f}  mean=${avg:>+8.3f}  win%={wins/n*100:>5.1f}%"

print("=== By HOUR of day (all DOW) ===")
for h in sorted(by_hour.keys()):
    print(fmt_row(by_hour[h], f"H{h:02d}:00"))

print("\n=== By DAY of week (all hours) ===")
for d in sorted(by_dow.keys()):
    print(fmt_row(by_dow[d], DOW_NAMES[d]))

print("\n=== Top 10 best (DOW × hour) buckets, n>=50 ===")
buckets = []
for (d, h), profits in by_dow_hour.items():
    if len(profits) < 50: continue
    buckets.append((d, h, sum(profits), len(profits), sum(profits)/len(profits)))
buckets.sort(key=lambda x: -x[2])
print(f"  {'DOW':<5} {'hour':>5} {'n':>6} {'sum$':>12} {'mean$':>10}")
for d, h, s, n, m in buckets[:10]:
    print(f"  {DOW_NAMES[d]:<5} {h:>5}  {n:>6} {s:>+12.2f} {m:>+10.3f}")

print("\n=== Top 10 worst (DOW × hour) buckets, n>=50 ===")
print(f"  {'DOW':<5} {'hour':>5} {'n':>6} {'sum$':>12} {'mean$':>10}")
for d, h, s, n, m in buckets[-10:]:
    print(f"  {DOW_NAMES[d]:<5} {h:>5}  {n:>6} {s:>+12.2f} {m:>+10.3f}")
