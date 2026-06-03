#!/usr/bin/env python3
"""Validate one detune config across IS(2025)+OOS(2026) cells -> smoothness panel.

Runs f0_runner (single backtest, Model=0) per cell with the config applied via
--input-override, extracts trades.csv, computes detune_metrics, prints a per-cell
panel + IS/OOS aggregates. Idempotent (skip if trades.csv exists).

    python scripts/validate_config.py
"""
import subprocess, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from detune_metrics import ulcer_index, max_dd_pct, daily_avg_pct, losing_basket_count, cross_cell_consistency

WT = Path(__file__).resolve().parents[1]
PRESET = "mt5/2.0/MoneyDancer_2.0/presets/XAUUSD_2.0_STEP_ship.set"
EXPERT = r"MoneyDancer_2.0\MoneyDancer_2.0.ex5"
DEPOSIT = 100000.0
CONFIG = {"LotMultiplier": "1.5", "MaxOrdersDir": "10", "MaxBasketLossPct": "6", "StepPoints": "40"}
TAG = "VAL-1p5-10-6-40"

# cell -> (from, to). symbol by year.
CELLS = {
    "jan25": ("2025.01.01", "2025.01.14"), "mar25": ("2025.03.01", "2025.03.14"),
    "jun25": ("2025.06.01", "2025.06.14"), "sep25": ("2025.09.01", "2025.09.14"),
    "dec25": ("2025.12.01", "2025.12.14"),
    "jan26": ("2026.01.01", "2026.01.14"), "mar26": ("2026.03.01", "2026.03.14"),
    "may26": ("2026.05.01", "2026.05.14"),
}

def sym(cell):
    return "XAUUSD.duk_robo_2025" if cell.endswith("25") else "XAUUSD.duk_robo"

def run_cell(cell):
    frm, to = CELLS[cell]
    rid = f"{TAG}-{cell}"
    rd = WT / "runs" / rid
    tc = rd / "trades.csv"
    if not (tc.exists() and tc.stat().st_size > 50):
        cmd = [sys.executable, str(WT / "scripts" / "f0_runner.py"),
               "--set-file", PRESET, "--run-id", rid, "--symbol", sym(cell),
               "--period", "M5", "--model", "0", "--from-date", frm, "--to-date", to,
               "--deposit", str(int(DEPOSIT)), "--expert", EXPERT, "--timeout", "3000"]
        for k, v in CONFIG.items():
            cmd += ["--input-override", f"{k}={v}"]
        subprocess.run(cmd, cwd=str(WT))
        rpt = rd / f"{rid}-report.htm"
        if not rpt.exists():
            print(f"FAIL {cell}: no report"); return None
        subprocess.run([sys.executable, str(WT / "scripts" / "extract_trades_from_report.py"),
                        "--report", str(rpt), "--out", str(tc)])
        for lg in rd.glob("*.log"):
            try: lg.unlink()
            except OSError: pass
    if not (tc.exists() and tc.stat().st_size > 50):
        print(f"FAIL {cell}: no trades"); return None
    import pandas as pd
    df = pd.read_csv(tc)
    da = daily_avg_pct(df, DEPOSIT)
    return {"cell": cell, "is_oos": cell.endswith("26"),
            "ulcer": round(ulcer_index(df["balance"]), 2),
            "maxDD": round(max_dd_pct(df["balance"]), 2),
            "dailyavg": round(da, 2), "gate_ok": da >= 1.5,
            "losers": losing_basket_count(df),
            "net": round(df[df["direction"] == "out"]["profit"].sum(), 0)}

def main():
    rows = [r for r in (run_cell(c) for c in CELLS) if r]
    print("\n=== PANEL: config 1.5/10/6/40 ===")
    hdr = ["cell", "is_oos", "ulcer", "maxDD", "dailyavg", "gate_ok", "losers", "net"]
    print(" ".join(f"{h:>9}" for h in hdr))
    for r in rows:
        print(" ".join(f"{str(r[h]):>9}" for h in hdr))
    for grp, oos in (("IS-2025", False), ("OOS-2026", True)):
        g = [r for r in rows if r["is_oos"] == oos]
        if not g: continue
        cc = cross_cell_consistency([r["dailyavg"] for r in g])
        import numpy as np
        print(f"\n{grp}: cells={len(g)} mean_ulcer={np.mean([r['ulcer'] for r in g]):.2f} "
              f"max_DD={max(r['maxDD'] for r in g):.2f} mean_dailyavg={np.mean([r['dailyavg'] for r in g]):.2f} "
              f"gate_pass={sum(r['gate_ok'] for r in g)}/{len(g)} neg_cells={cc['n_negative']}")

if __name__ == "__main__":
    main()
