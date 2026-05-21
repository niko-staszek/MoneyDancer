"""Build a master index of all per-run trades.csv files.

Concatenates them with a run_id column so we can do cross-run analysis from
one file. Each row of every per-run trades.csv stays intact; just a new
leading column is added.

Output: runs/trades_master.csv + a one-page runs/trades_index.md summary.
"""

from __future__ import annotations

import csv
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
RUNS_DIR = REPO_ROOT / "runs"


def main() -> int:
    rows_total = 0
    out_csv = RUNS_DIR / "trades_master.csv"
    summary: list[dict] = []

    # Discover all per-run trades.csv files
    per_run: list[Path] = []
    for d in sorted(RUNS_DIR.iterdir()):
        if not d.is_dir():
            continue
        f = d / "trades.csv"
        if f.exists():
            per_run.append(f)

    if not per_run:
        print("[index] no trades.csv files found")
        return 1

    # Common header (run_id + original deal columns)
    common = [
        "run_id", "time", "deal", "symbol", "type", "direction",
        "volume", "price", "order",
        "commission", "swap", "profit", "balance",
        "comment",
    ]
    with out_csv.open("w", newline="", encoding="utf-8") as fout:
        w = csv.DictWriter(fout, fieldnames=common)
        w.writeheader()
        for src in per_run:
            run_id = src.parent.name
            n_rows = 0
            t_in = t_out = 0
            profit_sum = 0.0
            first_ts = last_ts = None
            with src.open("r", encoding="utf-8") as fin:
                r = csv.DictReader(fin)
                for row in r:
                    row["run_id"] = run_id
                    w.writerow(row)
                    n_rows += 1
                    dirn = row.get("direction", "")
                    if dirn == "in":
                        t_in += 1
                    elif dirn == "out":
                        t_out += 1
                        try:
                            profit_sum += float(row.get("profit", "0"))
                        except ValueError:
                            pass
                    ts = row.get("time", "")
                    if first_ts is None or ts < first_ts:
                        first_ts = ts
                    if last_ts is None or ts > last_ts:
                        last_ts = ts
            rows_total += n_rows
            summary.append({
                "run_id": run_id,
                "deals": n_rows,
                "in": t_in,
                "out": t_out,
                "profit_sum": profit_sum,
                "first_ts": first_ts,
                "last_ts": last_ts,
            })

    print(f"[index] wrote {rows_total:,} rows to {out_csv}")

    # Write markdown summary
    out_md = RUNS_DIR / "trades_index.md"
    lines: list[str] = []
    lines.append("# F0 trade artifacts — master index")
    lines.append("")
    lines.append(f"Generated from {len(per_run)} per-run `trades.csv` files. Master CSV: `runs/trades_master.csv`. Use it for cross-run analysis (calendar/event overlay, regime detection, hour-of-day heatmaps, etc.).")
    lines.append("")
    lines.append("| Run | Total deals | in | out | Σ profit | First ts | Last ts |")
    lines.append("|---|---|---|---|---|---|---|")
    for s in summary:
        lines.append(
            f"| {s['run_id']} | {s['deals']:,} | {s['in']:,} | {s['out']:,} | "
            f"{s['profit_sum']:+,.2f} | {s['first_ts']} | {s['last_ts']} |"
        )
    lines.append("")
    lines.append("## Schema")
    lines.append("")
    lines.append("Columns:")
    lines.append("- `run_id`     — F0-* identifier")
    lines.append("- `time`       — broker-server time `YYYY.MM.DD HH:MM:SS`")
    lines.append("- `deal`       — MT5 deal id (sequential within run)")
    lines.append("- `symbol`     — `XAUUSD` or `XAUUSD.duk`")
    lines.append("- `type`       — `buy` or `sell`")
    lines.append("- `direction`  — `in` (opening) or `out` (closing)")
    lines.append("- `volume`     — lot size")
    lines.append("- `price`      — fill price")
    lines.append("- `order`      — order id (links in/out deals)")
    lines.append("- `commission` / `swap` / `profit` / `balance` — currency in account ccy (USD)")
    lines.append("- `comment`    — EA tag, e.g. `TBb1`, `TBs727`, `tp 4584.43`, `TBs761|D=3`")
    lines.append("")
    lines.append("## Useful next-step queries")
    lines.append("")
    lines.append("- **Calendar overlay**: `scripts/overlay_calendar.py --trades runs/<run_id>/trades.csv --calendar data/calendar/Q1_2026.csv --out runs/<run_id>/event_impact.csv`")
    lines.append("- **Per-hour PnL**: aggregate `out` rows by `time[11:13]` (hour) → mean/sum profit")
    lines.append("- **Per-day equity**: aggregate `out` rows by `time[:10]` (date) → cumulative `balance`")
    lines.append("- **Basket-life distribution**: group by `comment` prefix (`TBb`, `TBs`) → time delta from first `in` to last `out`")
    lines.append("- **Martingale-depth distribution**: comments with `|D=N` are Scenario-D adds at depth N")
    out_md.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"[index] wrote summary to {out_md}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
