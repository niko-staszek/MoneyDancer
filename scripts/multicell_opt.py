#!/usr/bin/env python3
"""Multi-cell robustness grid: score each candidate config by its WORST cell across
IS+OOS, not a single cell (the single-cell optimizer overfit — 1.5/10/6/40 was great
on mar25, lost OOS). A config is only 'robust' if it clears the 1.5%/day gate and stays
profitable on EVERY cell, including the hard ones (jun25, mar26, may26).

    python scripts/multicell_opt.py

Idempotent (skips a cell whose trades.csv exists). Serial (one tester at a time).
"""
import subprocess, sys, itertools
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from detune_metrics import ulcer_index, max_dd_pct, daily_avg_pct, losing_basket_count

WT = Path(__file__).resolve().parents[1]
PRESET = "mt5/2.0/MoneyDancer_2.0/presets/XAUUSD_2.0_STEP_ship.set"
EXPERT = r"MoneyDancer_2.0\MoneyDancer_2.0.ex5"
DEPOSIT = 100000.0
FIXED = {"MaxOrdersDir": "10", "StepPoints": "40"}     # carried from R1/R2
GRID = {"LotMultiplier": ["1.0", "1.5", "2.0", "2.5"], "MaxBasketLossPct": ["6", "8"]}

# (cell -> (from,to)); mix of IS-good, IS-bad, OOS-bad (the binding constraints)
CELLS = {
    "mar25": ("2025.03.01", "2025.03.14"), "sep25": ("2025.09.01", "2025.09.14"),
    "jun25": ("2025.06.01", "2025.06.14"),
    "mar26": ("2026.03.01", "2026.03.14"), "may26": ("2026.05.01", "2026.05.14"),
}

def sym(cell):
    return "XAUUSD.duk_robo_2025" if cell.endswith("25") else "XAUUSD.duk_robo"

def candidates():
    keys = list(GRID)
    for combo in itertools.product(*GRID.values()):
        cfg = dict(FIXED); cfg.update(dict(zip(keys, combo)))
        yield cfg

def cfg_tag(cfg):
    return f"lm{cfg['LotMultiplier']}-bl{cfg['MaxBasketLossPct']}"

def eval_cell(cfg, cell):
    frm, to = CELLS[cell]
    rid = f"MC-{cfg_tag(cfg)}-{cell}"
    rd = WT / "runs" / rid; tc = rd / "trades.csv"
    if not (tc.exists() and tc.stat().st_size > 50):
        cmd = [sys.executable, str(WT / "scripts" / "f0_runner.py"),
               "--set-file", PRESET, "--run-id", rid, "--symbol", sym(cell),
               "--period", "M5", "--model", "0", "--from-date", frm, "--to-date", to,
               "--deposit", str(int(DEPOSIT)), "--expert", EXPERT, "--timeout", "3000"]
        for k, v in cfg.items():
            cmd += ["--input-override", f"{k}={v}"]
        subprocess.run(cmd, cwd=str(WT))
        rpt = rd / f"{rid}-report.htm"
        if not rpt.exists():
            return None
        subprocess.run([sys.executable, str(WT / "scripts" / "extract_trades_from_report.py"),
                        "--report", str(rpt), "--out", str(tc)])
        for lg in rd.glob("*.log"):
            try: lg.unlink()
            except OSError: pass
    if not (tc.exists() and tc.stat().st_size > 50):
        return None
    import pandas as pd
    df = pd.read_csv(tc)
    da = daily_avg_pct(df, DEPOSIT)
    return {"dailyavg": round(da, 2), "ulcer": round(ulcer_index(df["balance"]), 2),
            "maxDD": round(max_dd_pct(df["balance"]), 2),
            "net": round(df[df["direction"] == "out"]["profit"].sum(), 0)}

def main():
    import numpy as np
    summary = []
    for cfg in candidates():
        per = {c: eval_cell(cfg, c) for c in CELLS}
        ok = {c: m for c, m in per.items() if m}
        if not ok:
            continue
        das = [m["dailyavg"] for m in ok.values()]
        summary.append({
            "cfg": cfg_tag(cfg),
            "worst_da": min(das), "mean_da": round(float(np.mean(das)), 2),
            "max_DD": max(m["maxDD"] for m in ok.values()),
            "mean_ulcer": round(float(np.mean([m["ulcer"] for m in ok.values()])), 2),
            "cells_gate": sum(1 for d in das if d >= 1.5), "n": len(ok),
            "cells_profit": sum(1 for m in ok.values() if m["net"] > 0),
            "per": {c: m["dailyavg"] for c, m in ok.items()}})
    # robust = highest worst-cell daily-avg (maximin)
    summary.sort(key=lambda s: s["worst_da"], reverse=True)
    print("\n=== MULTI-CELL ROBUSTNESS (sorted by worst-cell %/day) ===")
    print(f"cells: {list(CELLS)}")
    h = ["cfg", "worst_da", "mean_da", "max_DD", "mean_ulcer", "cells_gate", "cells_profit", "n"]
    print(" ".join(f"{x:>11}" for x in h))
    for s in summary:
        print(" ".join(f"{str(s[x]):>11}" for x in h))
    print("\nper-cell %/day:")
    for s in summary:
        print(f"  {s['cfg']:>10}: {s['per']}")
    robust = [s for s in summary if s["worst_da"] >= 1.5 and s["cells_profit"] == s["n"]]
    print(f"\nROBUST configs (worst-cell >=1.5%/day AND profitable on all {len(CELLS)} cells): "
          f"{[s['cfg'] for s in robust] or 'NONE -> path-dependence confirmed'}")

if __name__ == "__main__":
    main()
