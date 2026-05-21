"""Per-cell mechanism analysis using deals + log files.

Goal: identify what makes monster cells (Dec25 +191%) different from weak ones (Jan26 +0.6%).
"""
from __future__ import annotations
import csv
import re
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
RUNS = REPO / "runs"

CELLS = [
    ("jan25", "S3.2b-WT-5k-jan25-2wk", 32.8),
    ("feb25", "S3.2b-WT-5k-feb25-2wk", 25.0),
    ("mar25", "S3.2b-WT-5k-mar25-2wk", 3.3),
    ("apr25", "S3.2b-WT-5k-apr25-2wk", 177.3),
    ("may25", "S3.2b-WT-5k-may25-2wk", 3.9),
    ("jun25", "S3.2b-WT-5k-jun25-2wk", 6.9),
    ("jul25", "S3.2b-WT-5k-jul25-2wk", 9.1),
    ("aug25", "S3.2b-WT-5k-aug25-2wk", 34.7),
    ("sep25", "S3.2b-WT-5k-sep25-2wk", 65.7),
    ("oct25", "S3.2b-WT-5k-oct25-2wk", 49.4),
    ("nov25", "S3.2b-WT-5k-nov25-2wk", 82.3),
    ("dec25", "S3.2b-WT-5k-dec25-2wk", 191.0),
    ("jan26", "S3.2b-WT-5k-jan26-2wk", 0.6),
    ("feb26", "S3.2b-WT-5k-feb26-2wk", 45.9),
    ("mar26", "S3.2b-WT-5k-mar26-2wk", 59.6),
    ("apr26", "S3.2b-WT-5k-apr26-2wk", 184.6),
    ("may26", "S3.2b-WT-5k-may26-2wk", 112.3),
]

TS_FMT = "%Y.%m.%d %H:%M:%S"


def parse_log_events(log_path: Path, start_marker: str) -> dict:
    """Parse a UTF-16 MT5 tester log. Find the section after start_marker (a Tester line)
    and count basket-SL events, friday-flatten events, etc.
    """
    if not log_path.exists():
        return {"basket_sl": 0, "friday_flatten": 0, "all_time_dd_kill": 0}

    try:
        raw = log_path.read_bytes()
    except Exception:
        return {"basket_sl": 0, "friday_flatten": 0, "all_time_dd_kill": 0}

    # Strip null bytes (UTF-16 BE/LE comes out as alternating null + ascii)
    text = raw.decode("utf-16", errors="ignore") if raw[:2] in (b"\xff\xfe", b"\xfe\xff") else raw.decode("utf-8", errors="ignore")
    # Some files have null bytes inline; strip them
    text = text.replace("\x00", "")

    # Find the last occurrence of the start_marker — that's our run
    pos = text.rfind(start_marker)
    if pos < 0:
        section = text
    else:
        section = text[pos:]

    # Count events
    sl_count = len(re.findall(r"\[S1\.0\] basket SL fired", section))
    fr_count = len(re.findall(r"\[S1\.7\] Friday flatten", section))
    dd_count = len(re.findall(r"\[S1\.6\] all-time DD kill", section))
    return {"basket_sl": sl_count, "friday_flatten": fr_count, "all_time_dd_kill": dd_count}


def analyze(cell: str, folder: Path, net_pct: float) -> dict:
    trades_path = folder / "trades.csv"
    log_path = folder / "20260518.log"
    # log file name varies by date — pick whichever .log is in the folder
    if not log_path.exists():
        candidates = list(folder.glob("*.log"))
        if candidates:
            log_path = candidates[0]

    if not trades_path.exists():
        return {"cell": cell, "error": "no trades.csv"}

    # Parse trade-level metrics
    n_in = 0
    n_out = 0
    total_profit = 0.0
    in_times_by_lot: list = []
    in_deals: list = []
    out_deals: list = []
    first_ts: str | None = None
    last_ts: str | None = None

    with trades_path.open(encoding="utf-8", errors="ignore") as f:
        rdr = csv.DictReader(f)
        for row in rdr:
            ts = row.get("time", "")
            if first_ts is None:
                first_ts = ts
            last_ts = ts
            direction = row.get("direction", "")
            try:
                volume = float(row.get("volume", "0"))
                profit = float(row.get("profit", "0"))
            except (ValueError, TypeError):
                continue
            if direction == "in":
                n_in += 1
                in_deals.append({"ts": ts, "volume": volume})
            elif direction == "out":
                n_out += 1
                total_profit += profit
                out_deals.append({"ts": ts, "volume": volume, "profit": profit})

    # Holding time estimation: simple FIFO pairing
    # Average difference between in-time and out-time for matched positions
    holding_secs = []
    for i, (in_d, out_d) in enumerate(zip(in_deals, out_deals)):
        try:
            t_in = datetime.strptime(in_d["ts"], TS_FMT)
            t_out = datetime.strptime(out_d["ts"], TS_FMT)
            delta = (t_out - t_in).total_seconds()
            if 0 < delta < 86400 * 7:  # sanity: < 1 week
                holding_secs.append(delta)
        except Exception:
            pass

    avg_hold_min = (sum(holding_secs) / len(holding_secs) / 60.0) if holding_secs else 0
    median_hold_min = (sorted(holding_secs)[len(holding_secs) // 2] / 60.0) if holding_secs else 0

    # Profit distribution
    profits = [d["profit"] for d in out_deals if d["profit"] != 0]
    n_profitable = sum(1 for p in profits if p > 0)
    n_losers = sum(1 for p in profits if p < 0)
    sum_winners = sum(p for p in profits if p > 0)
    sum_losers = sum(p for p in profits if p < 0)
    win_rate = (n_profitable / len(profits) * 100) if profits else 0

    # Active trade days (distinct dates with at least one in-deal)
    days_active = len(set(d["ts"][:10] for d in in_deals))

    # Day distribution
    day_in = defaultdict(int)
    for d in in_deals:
        day = d["ts"][:10]
        day_in[day] += 1

    # Log-derived events
    log_events = parse_log_events(log_path, "testing of Experts")

    return {
        "cell": cell,
        "net_pct": net_pct,
        "n_in": n_in,
        "n_out": n_out,
        "total_profit": total_profit,
        "win_rate_pct": win_rate,
        "winners_sum": sum_winners,
        "losers_sum": abs(sum_losers),
        "avg_hold_min": avg_hold_min,
        "median_hold_min": median_hold_min,
        "days_active": days_active,
        "trades_per_day": n_in / days_active if days_active else 0,
        "basket_sl_fires": log_events["basket_sl"],
        "friday_flatten_events": log_events["friday_flatten"],
        "dd_kill_events": log_events["all_time_dd_kill"],
    }


def main() -> int:
    results = []
    for cell, folder_name, net_pct in CELLS:
        folder = RUNS / folder_name
        results.append(analyze(cell, folder, net_pct))

    print(f"{'cell':<6} {'net%':>6} {'in':>5} {'out':>5} {'win%':>5} {'win$':>7} {'loss$':>7} {'PF':>5} {'avg_hold':>8} {'med_hold':>8} {'days':>4} {'tr/day':>6} {'SL':>3} {'Fr':>3}")
    for r in results:
        if "error" in r:
            print(f"{r['cell']:<6}  ERROR: {r['error']}")
            continue
        pf = (r["winners_sum"] / r["losers_sum"]) if r["losers_sum"] > 0 else 99.0
        print(
            f"{r['cell']:<6} {r['net_pct']:>5.1f}% {r['n_in']:>5} {r['n_out']:>5} "
            f"{r['win_rate_pct']:>4.0f}% {r['winners_sum']:>7.0f} {r['losers_sum']:>7.0f} "
            f"{pf:>5.2f} {r['avg_hold_min']:>7.1f}m {r['median_hold_min']:>7.1f}m "
            f"{r['days_active']:>4} {r['trades_per_day']:>5.0f} {r['basket_sl_fires']:>3} {r['friday_flatten_events']:>3}"
        )

    # Aggregate insights
    print()
    print("=== Aggregate insights ===")
    print(f"Total cells: {len(results)}")
    sorted_by_net = sorted(results, key=lambda r: r.get("net_pct", 0), reverse=True)
    top5 = sorted_by_net[:5]
    bot5 = sorted_by_net[-5:]

    def avg(rs, k):
        vals = [r[k] for r in rs if k in r]
        return sum(vals) / len(vals) if vals else 0

    print(f"\nTOP 5 cells ({[r['cell'] for r in top5]}):")
    print(f"  avg trades_per_day: {avg(top5, 'trades_per_day'):.0f}")
    print(f"  avg avg_hold_min:   {avg(top5, 'avg_hold_min'):.1f}")
    print(f"  avg win_rate%:      {avg(top5, 'win_rate_pct'):.1f}")
    print(f"  avg basket_SLs:     {avg(top5, 'basket_sl_fires'):.1f}")
    print(f"  avg days_active:    {avg(top5, 'days_active'):.1f}")

    print(f"\nBOTTOM 5 cells ({[r['cell'] for r in bot5]}):")
    print(f"  avg trades_per_day: {avg(bot5, 'trades_per_day'):.0f}")
    print(f"  avg avg_hold_min:   {avg(bot5, 'avg_hold_min'):.1f}")
    print(f"  avg win_rate%:      {avg(bot5, 'win_rate_pct'):.1f}")
    print(f"  avg basket_SLs:     {avg(bot5, 'basket_sl_fires'):.1f}")
    print(f"  avg days_active:    {avg(bot5, 'days_active'):.1f}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
