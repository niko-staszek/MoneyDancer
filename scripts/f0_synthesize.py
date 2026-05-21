"""Synthesize the F0 memo after all 5 batch runs complete.

For each of the 5 runs:
  1. Locate the report.htm in runs/<run_id>/.
  2. Parse it via parse_mt5_report.py → result.yaml + raw.json.
  3. Filter the tester log to the run's date window, extract trade events.
  4. Overlay trade events against the Q1 2026 calendar.
  5. Compute per-run scorecard.

Then write a synthesized memo to runs/decisions/F0-empirical-2026-Q1.md.
"""

from __future__ import annotations

import csv
import datetime as dt
import json
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
RUNS_DIR = REPO_ROOT / "runs"
LOG_PATH = Path(
    r"C:\Users\nikof\AppData\Roaming\MetaQuotes\Terminal"
    r"\5FFA568149E88FCD5B44D926DCFEAA79\Tester\logs\20260514.log"
)
TESTER_FILES = Path(
    r"C:\Users\nikof\AppData\Roaming\MetaQuotes\Terminal"
    r"\5FFA568149E88FCD5B44D926DCFEAA79\MQL5\Files"
)

# Must match f0_batch.py RUNS
RUNS: list[tuple[str, float, str, str]] = [
    ("F0-test1.3a-scalper", 100000, "TEST 1.3a.set", "tight scalper, per-DOW windows"),
    ("F0-test13a-fastscalper", 100000, "TEST 13a M30+.set", "fast scalper, no cooldown"),
    ("F0-35k-pyramid", 35000, "#GOLD capital-35k, h 1- 22, m15.set", "mid grid + pyramid"),
    ("F0-3k-heavy-pyramid", 3000, "#GOLD capital-3k, h5-19, m1, sl,multix3.set", "heavy grid + pyramid + SL=515"),
    ("F0-5k-heavy-grid", 5000, "# GOLD cap 5k dd 4100 - hard scal, mix time, range burst zone.set", "heavy grid, mult 4.0"),
]


def find_report(run_id: str) -> Path | None:
    """Look in runs/<run_id> first, then MQL5/Files."""
    for p in (RUNS_DIR / run_id, TESTER_FILES):
        if not p.exists():
            continue
        for f in p.glob(f"{run_id}*.htm"):
            return f
    return None


def parse_report(run_id: str, report_path: Path, deposit: float) -> dict:
    out_yaml = RUNS_DIR / run_id / "result.yaml"
    cmd = [
        sys.executable,
        str(REPO_ROOT / "scripts" / "parse_mt5_report.py"),
        "--report", str(report_path),
        "--run-id", run_id,
        "--story-id", "F0",
        "--deposit", str(deposit),
        "--from-date", "2026.01.01",
        "--to-date", "2026.03.31",
        "--out", str(out_yaml),
    ]
    subprocess.call(cmd)
    raw = (out_yaml.with_suffix(".raw.json"))
    if raw.exists():
        return json.loads(raw.read_text(encoding="utf-8"))
    return {}


def extract_trades_for_run(run_id: str, from_date: str, to_date: str) -> Path:
    """Run parse_tester_log.py against the daily log, then filter by date."""
    full_csv = RUNS_DIR / run_id / "trades_all.csv"
    if not LOG_PATH.exists():
        return full_csv
    subprocess.call([
        sys.executable,
        str(REPO_ROOT / "scripts" / "parse_tester_log.py"),
        "--log", str(LOG_PATH),
        "--out", str(full_csv),
    ])
    # Filter to date window
    filtered = RUNS_DIR / run_id / "trades.csv"
    if full_csv.exists():
        with full_csv.open("r", encoding="utf-8") as fin, filtered.open("w", newline="", encoding="utf-8") as fout:
            r = csv.DictReader(fin)
            w = csv.DictWriter(fout, fieldnames=r.fieldnames or [])
            w.writeheader()
            for row in r:
                dt_str = row.get("sim_dt", "")
                if from_date.replace(".", "") <= dt_str.replace(".", "")[:10] <= to_date.replace(".", ""):
                    w.writerow(row)
    return filtered


def run_overlay(run_id: str, trades_csv: Path) -> Path:
    out = RUNS_DIR / run_id / "event_impact.csv"
    cal = REPO_ROOT / "data" / "calendar" / "Q1_2026.csv"
    if not trades_csv.exists() or not cal.exists():
        return out
    subprocess.call([
        sys.executable,
        str(REPO_ROOT / "scripts" / "overlay_calendar.py"),
        "--trades", str(trades_csv),
        "--calendar", str(cal),
        "--out", str(out),
        "--tier-filter", "T1",
    ])
    return out


def fmt_pct(v) -> str:
    if isinstance(v, (int, float)):
        return f"{v:.2f}"
    return str(v) if v else "-"


def fmt_money(v) -> str:
    if isinstance(v, (int, float)):
        sign = "-" if v < 0 else ""
        return f"{sign}${abs(v):,.2f}"
    return str(v) if v else "-"


def fmt_pct_of(v, base) -> str:
    if isinstance(v, (int, float)) and isinstance(base, (int, float)) and base:
        return f"{100.0 * v / base:.2f}%"
    return "-"


def write_memo(per_run: list[dict]) -> Path:
    out = RUNS_DIR / "decisions" / "F0-empirical-2026-Q1.md"
    out.parent.mkdir(parents=True, exist_ok=True)
    lines: list[str] = []
    lines.append("---")
    lines.append("date: 2026-05-14")
    lines.append("story_id: F0")
    lines.append("action: empirical")
    lines.append("evidence_runs:")
    for r in per_run:
        lines.append(f"  - {r['run_id']}")
    lines.append("---")
    lines.append("")
    lines.append("# F0 — Empirical 2026-Q1 runs on user's 5 .set files")
    lines.append("")
    lines.append("Window: **2026-01-01 → 2026-03-31** (XAUUSD, MT5 Strategy Tester, "
                 "every-tick-based-on-real-ticks, 40ms execution delay, RoboForex-Pro).")
    lines.append("")
    lines.append("## Per-run scorecard")
    lines.append("")
    lines.append("| Run | Deposit | Net P/L | Profit Factor | Max DD ($) | Max DD %eq | Trades | TP/SL win |")
    lines.append("|---|---|---|---|---|---|---|---|")
    for r in per_run:
        m = r.get("metrics", {})
        deposit = r["deposit"]
        net = m.get("net_profit")
        pf = m.get("profit_factor")
        ddmax = m.get("equity_dd_max") or m.get("balance_dd_max")
        ddrel = m.get("equity_dd_rel") or m.get("balance_dd_rel")
        trades = m.get("total_trades") or m.get("total_deals")
        wins = m.get("profit_trades")
        losses = m.get("loss_trades")
        win_pct = "-"
        if isinstance(wins, (int, float)) and isinstance(losses, (int, float)) and (wins + losses) > 0:
            win_pct = f"{100.0 * wins / (wins + losses):.1f}%"
        lines.append(
            f"| {r['run_id']} | {fmt_money(deposit)} | {fmt_money(net)} | "
            f"{fmt_pct(pf)} | {fmt_money(ddmax)} | {fmt_pct_of(ddmax, deposit) if not isinstance(ddrel,(int,float)) else fmt_pct(ddrel)+'%'} | "
            f"{int(trades) if isinstance(trades,(int,float)) else '-'} | {win_pct} |"
        )
    lines.append("")
    lines.append("## Notes per run")
    lines.append("")
    for r in per_run:
        lines.append(f"### {r['run_id']}")
        lines.append(f"- **Architecture**: {r['notes']}")
        lines.append(f"- **Source .set**: `{r['set_file']}`")
        m = r.get("metrics", {})
        ddmax = m.get("equity_dd_max") or m.get("balance_dd_max") or 0
        net = m.get("net_profit") or 0
        if isinstance(ddmax, (int, float)) and isinstance(net, (int, float)) and ddmax > 0:
            recovery = net / ddmax if ddmax else None
            lines.append(f"- **Net / Max-DD ratio (recovery proxy)**: {recovery:.2f}" if recovery else "")
        # Event impact summary
        event_csv = RUNS_DIR / r["run_id"] / "event_impact.csv"
        if event_csv.exists():
            with event_csv.open("r", encoding="utf-8") as f:
                rows = list(csv.DictReader(f))
            top = sorted(rows, key=lambda x: int(x.get("total_in_window", 0)), reverse=True)[:3]
            lines.append("- **Top-3 high-impact events by trade activity**:")
            for ev in top:
                lines.append(f"  - {ev['event_broker']}  {ev['label']}: total={ev['total_in_window']} "
                             f"(pre buy/sell={ev['pre_buy']}/{ev['pre_sell']}; "
                             f"post buy/sell={ev['post_buy']}/{ev['post_sell']}; "
                             f"TPs={ev['tp_in_post']} SLs={ev['sl_in_post']})")
        lines.append("")

    lines.append("## Synthesis")
    lines.append("")
    lines.append("_(filled in by hand after reading per-run notes; key questions:)_")
    lines.append("")
    lines.append("1. Which architecture lane (heavy grid vs tight scalper) survives Q1 2026 better on UPI / max-DD?")
    lines.append("2. Which calendar events caused the worst basket-DD impact across configs?")
    lines.append("3. Did the after-hour profit-lock at 14:30 actually fire on the configs that have it (35k, 3k, TEST 1.3a)?")
    lines.append("4. Are any of the 5 configs *worth seeding* into Sprint 2 recipe discovery, or do we start cleaner?")
    lines.append("5. Is `TEST 1.3a`'s SL_Points=7500 alone sufficient as catastrophe-SL, or does basket-equity-SL (locked) add meaningful tail protection?")
    lines.append("")
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"[synth] wrote memo: {out}")
    return out


def main() -> int:
    per_run: list[dict] = []
    for run_id, deposit, set_file, notes in RUNS:
        info: dict = {
            "run_id": run_id,
            "deposit": deposit,
            "set_file": set_file,
            "notes": notes,
        }
        report = find_report(run_id)
        if report is None:
            print(f"[synth] {run_id}: no report.htm found, skipping")
            per_run.append(info)
            continue
        info["report_path"] = str(report)
        metrics = parse_report(run_id, report, deposit)
        info["metrics"] = metrics
        trades_csv = extract_trades_for_run(run_id, "2026.01.01", "2026.03.31")
        info["trades_csv"] = str(trades_csv)
        run_overlay(run_id, trades_csv)
        per_run.append(info)
    write_memo(per_run)
    return 0


if __name__ == "__main__":
    sys.exit(main())
