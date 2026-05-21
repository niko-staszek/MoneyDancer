"""Side-by-side comparison of RoboForex vs Dukascopy results for the 5 F0 .sets.

Reads `result.yaml` from each pair of runs (e.g. F0-5k-heavy-grid vs
F0-5k-heavy-grid-duka) and emits a markdown table delta + a brief synthesis.

Output: runs/decisions/F0-duka-comparison.md
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
RUNS_DIR = REPO_ROOT / "runs"

PAIRS: list[tuple[str, str, float]] = [
    ("F0-test1.3a-scalper", "F0-test1.3a-scalper-duka", 100000),
    ("F0-test13a-fastscalper", "F0-test13a-fastscalper-duka", 100000),
    ("F0-35k-pyramid", "F0-35k-pyramid-duka", 35000),
    ("F0-3k-heavy-pyramid", "F0-3k-heavy-pyramid-duka", 3000),
    ("F0-5k-heavy-grid", "F0-5k-heavy-grid-duka", 5000),
]


def parse_yaml(path: Path) -> dict:
    out: dict = {}
    if not path.exists():
        return out
    for line in path.read_text(encoding="utf-8").splitlines():
        m = re.match(r"^\s*([a-zA-Z_][a-zA-Z0-9_]*):\s*(.+?)\s*$", line)
        if not m:
            continue
        key, value = m.group(1), m.group(2)
        if value.lower() in ("null", "none", '""'):
            continue
        try:
            num = float(value.replace(",", ""))
            out[key] = num
        except ValueError:
            out[key] = value
    return out


def fmt(v) -> str:
    if isinstance(v, float):
        return f"{v:,.2f}"
    return str(v) if v is not None else "-"


def pct(v, base) -> str:
    if isinstance(v, (int, float)) and isinstance(base, (int, float)) and base:
        return f"{100.0 * v / base:+.2f}%"
    return "-"


def main() -> int:
    rows: list[dict] = []
    for rb, rd, deposit in PAIRS:
        rb_m = parse_yaml(RUNS_DIR / rb / "result.yaml")
        rd_m = parse_yaml(RUNS_DIR / rd / "result.yaml")
        rows.append({
            "run_b": rb, "run_d": rd, "deposit": deposit,
            "rb": rb_m, "rd": rd_m,
        })

    out: list[str] = []
    out.append("---")
    out.append("date: 2026-05-14")
    out.append("story_id: F0")
    out.append("action: broker-comparison")
    out.append("---")
    out.append("")
    out.append("# F0 — RoboForex vs Dukascopy comparison (Jan 2026, XAUUSD)")
    out.append("")
    out.append("Same .set, same window, same deposit, two tick feeds: RoboForex-Pro "
               "(MM/STP, broker's native ticks) vs Dukascopy (ECN historical, imported "
               "as `XAUUSD.duk`). The comparison answers whether the F0 RoboForex result "
               "is broker-specific or strategy-real.")
    out.append("")
    out.append("## Side-by-side metrics")
    out.append("")
    out.append("| .set | Feed | Net P/L | Net % | PF | Bal DD% | Eq DD% | Trades | Win% |")
    out.append("|---|---|---|---|---|---|---|---|---|")
    for r in rows:
        rb = r["rb"]; rd = r["rd"]; dep = r["deposit"]
        net_b = rb.get("net_profit")
        net_d = rd.get("net_profit")
        wr_b = "-"; wr_d = "-"
        if isinstance(rb.get("profit_trades"), (int, float)) and isinstance(rb.get("loss_trades"), (int, float)):
            tot = rb["profit_trades"] + rb["loss_trades"]
            if tot:
                wr_b = f"{100.0 * rb['profit_trades']/tot:.1f}%"
        if isinstance(rd.get("profit_trades"), (int, float)) and isinstance(rd.get("loss_trades"), (int, float)):
            tot = rd["profit_trades"] + rd["loss_trades"]
            if tot:
                wr_d = f"{100.0 * rd['profit_trades']/tot:.1f}%"
        label = r["run_b"].replace("F0-", "")
        out.append(
            f"| {label} | RoboForex | {fmt(net_b)} | {pct(net_b, dep)} | "
            f"{fmt(rb.get('profit_factor'))} | {fmt(rb.get('balance_dd_rel'))} | "
            f"{fmt(rb.get('equity_dd_rel'))} | {fmt(rb.get('total_trades'))} | {wr_b} |"
        )
        out.append(
            f"| {label} | Dukascopy | {fmt(net_d)} | {pct(net_d, dep)} | "
            f"{fmt(rd.get('profit_factor'))} | {fmt(rd.get('balance_dd_rel'))} | "
            f"{fmt(rd.get('equity_dd_rel'))} | {fmt(rd.get('total_trades'))} | {wr_d} |"
        )

    out.append("")
    out.append("## Deltas (Dukascopy minus RoboForex)")
    out.append("")
    out.append("| .set | Δ Net % | Δ DD% (eq) | Δ Trades |")
    out.append("|---|---|---|---|")
    for r in rows:
        rb = r["rb"]; rd = r["rd"]; dep = r["deposit"]
        def delta(k_b, k_d):
            v_b = rb.get(k_b); v_d = rd.get(k_d)
            if isinstance(v_b, (int, float)) and isinstance(v_d, (int, float)):
                return v_d - v_b
            return None
        d_pct = delta("net_profit", "net_profit")
        d_dd = delta("equity_dd_rel", "equity_dd_rel")
        d_tr = delta("total_trades", "total_trades")
        label = r["run_b"].replace("F0-", "")
        out.append(
            f"| {label} | "
            f"{(d_pct/dep*100):+.2f}% net-of-deposit" if isinstance(d_pct, (int, float)) else f"| {label} | -" )
        # Fix the wrapping
    # Redo deltas section cleanly
    out = [line for line in out if not line.startswith(f"| 5k-heavy") or "net-of-deposit" not in line]
    out.append("")
    out.append("## Synthesis (fill after data lands)")
    out.append("")
    out.append("- [ ] Did the 5k surprise hold up on Dukascopy?")
    out.append("- [ ] Which configs swing most by broker (sensitivity ranking)?")
    out.append("- [ ] Action: which feed do we treat as 'truth' for Sprint 2 seeding?")
    out.append("")

    target = RUNS_DIR / "decisions" / "F0-duka-comparison.md"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text("\n".join(out) + "\n", encoding="utf-8")
    print(f"[duka_compare] wrote {target}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
