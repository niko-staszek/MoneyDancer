"""Orchestrate all 5 F0 runs sequentially.

Runs each user-provided .set against XAUUSD on MT5 Strategy Tester for the same
date window. Uses scripts/f0_runner.py under the hood. Reports timing + report
landing per run. Writes a summary index at runs/F0-batch-summary.txt.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import time
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
SET_ROOT = Path(r"C:\Users\nikof\Documents\GitHub\MoneyDancer")

# (run_id, deposit, set_filename)
RUNS: list[tuple[str, float, str]] = [
    ("F0-test1.3a-scalper", 100000, "TEST 1.3a.set"),
    ("F0-test13a-fastscalper", 100000, "TEST 13a M30+.set"),
    ("F0-35k-pyramid", 35000, "#GOLD capital-35k, h 1- 22, m15.set"),
    ("F0-3k-heavy-pyramid", 3000, "#GOLD capital-3k, h5-19, m1, sl,multix3.set"),
    ("F0-5k-heavy-grid", 5000, "# GOLD cap 5k dd 4100 - hard scal, mix time, range burst zone.set"),
]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--from-date", default="2026.01.01")
    ap.add_argument("--to-date", default="2026.03.31")
    ap.add_argument("--symbol", default="XAUUSD")
    ap.add_argument("--period", default="M5")
    ap.add_argument("--leverage", type=int, default=500)
    ap.add_argument("--timeout", type=int, default=3600, help="per-run timeout seconds")
    ap.add_argument("--only", default=None, help="comma-separated run-ids to limit to")
    ap.add_argument("--suffix", default="", help="appended to each run-id (e.g. '-duka')")
    ap.add_argument(
        "--input-override", action="append", default=[],
        help="Override an EA input across ALL runs in the batch. KEY=VALUE. Repeatable.",
    )
    args = ap.parse_args()

    only = set(args.only.split(",")) if args.only else None

    summary_path = REPO_ROOT / "runs" / "F0-batch-summary.txt"
    summary_path.parent.mkdir(parents=True, exist_ok=True)
    summary_path.write_text(
        f"F0 batch — started {time.strftime('%Y-%m-%d %H:%M:%S')}\n"
        f"window: {args.from_date} → {args.to_date}\n"
        f"symbol: {args.symbol}  period: {args.period}\n\n",
        encoding="utf-8",
    )

    overall_start = time.time()
    for run_id, deposit, set_filename in RUNS:
        full_id = run_id + args.suffix
        if only and full_id not in only and run_id not in only:
            continue
        set_path = SET_ROOT / set_filename
        if not set_path.exists():
            line = f"[{full_id}] SKIP — .set not found: {set_path}\n"
            print(line, end="")
            with open(summary_path, "a", encoding="utf-8") as f:
                f.write(line)
            continue

        run_start = time.time()
        cmd = [
            sys.executable,
            str(REPO_ROOT / "scripts" / "f0_runner.py"),
            "--set-file", str(set_path),
            "--run-id", full_id,
            "--deposit", str(deposit),
            "--from-date", args.from_date,
            "--to-date", args.to_date,
            "--symbol", args.symbol,
            "--period", args.period,
            "--leverage", str(args.leverage),
            "--timeout", str(args.timeout),
        ]
        for ov in args.input_override:
            cmd.extend(["--input-override", ov])
        print(f"\n[batch] === {full_id} (deposit ${deposit:g}) ===")
        rc = subprocess.call(cmd, cwd=REPO_ROOT)
        elapsed = time.time() - run_start

        # Check if report landed
        report_path = REPO_ROOT / "runs" / full_id
        has_report = any(
            p.suffix in (".htm", ".html") for p in report_path.glob("*")
        ) if report_path.exists() else False

        line = (
            f"[{full_id}] rc={rc} elapsed={elapsed:.0f}s "
            f"report={'YES' if has_report else 'NO'} deposit=${deposit:g}\n"
        )
        print(line, end="")
        with open(summary_path, "a", encoding="utf-8") as f:
            f.write(line)

    total = time.time() - overall_start
    final = f"\n[batch] total elapsed {total:.0f}s ({total/60:.1f} min)\n"
    print(final, end="")
    with open(summary_path, "a", encoding="utf-8") as f:
        f.write(final)
    return 0


if __name__ == "__main__":
    sys.exit(main())
