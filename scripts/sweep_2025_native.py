#!/usr/bin/env python3
"""Sweep the #GOLD 35k set NATIVE on MoneyDancer 1.2 across all of 2025 (12 monthly 2wk
cells). Tests whether the +65% 2026 result generalizes, or is 2026-regime-specific.
Serial, idempotent, prints metrics table."""
import subprocess, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from detune_metrics import ulcer_index, max_dd_pct, daily_avg_pct, losing_basket_count
import pandas as pd

WT = Path(__file__).resolve().parents[1]
DEP = 35000
SETF = "gold35k_native.set"
EXPERT = r"MoneyDancer_1.2\MoneyDancer_1.2.ex5"
SYM = "XAUUSD.duk_robo_2025"

CELLS = {
    "jan25": ("2025.01.06", "2025.01.17"), "feb25": ("2025.02.03", "2025.02.14"),
    "mar25": ("2025.03.03", "2025.03.14"), "apr25": ("2025.04.07", "2025.04.18"),
    "may25": ("2025.05.05", "2025.05.16"), "jun25": ("2025.06.02", "2025.06.13"),
    "jul25": ("2025.07.07", "2025.07.18"), "aug25": ("2025.08.04", "2025.08.15"),
    "sep25": ("2025.09.08", "2025.09.19"), "oct25": ("2025.10.06", "2025.10.17"),
    "nov25": ("2025.11.03", "2025.11.14"), "dec25": ("2025.12.01", "2025.12.12"),
}

def run(cell):
    frm, to = CELLS[cell]; rid = f"NAT12-2025-{cell}"
    rd = WT / "runs" / rid; tc = rd / "trades.csv"
    if not (tc.exists() and tc.stat().st_size > 50):
        subprocess.run([sys.executable, str(WT/"scripts"/"f0_runner.py"), "--set-file", str(WT/SETF),
                        "--run-id", rid, "--symbol", SYM, "--period", "M15", "--model", "0",
                        "--from-date", frm, "--to-date", to, "--deposit", str(DEP),
                        "--expert", EXPERT, "--timeout", "5400"], cwd=str(WT))
        rpt = rd / f"{rid}-report.htm"
        if rpt.exists():
            subprocess.run([sys.executable, str(WT/"scripts"/"extract_trades_from_report.py"),
                            "--report", str(rpt), "--out", str(tc)])
        for lg in rd.glob("*.log"):
            try: lg.unlink()
            except OSError: pass
    if not (tc.exists() and tc.stat().st_size > 50):
        return None
    d = pd.read_csv(tc); o = d[d.direction == "out"]
    if not len(o):
        return {"deals": 0, "ret%": 0.0}
    return {"deals": len(o), "ret%": round(o.profit.sum()/DEP*100, 1),
            "maxDD%": round(max_dd_pct(d.balance), 1), "ulcer": round(ulcer_index(d.balance), 1),
            "dailyavg%": round(daily_avg_pct(d, DEP), 2), "losers": losing_basket_count(d)}

def main():
    import numpy as np
    res = {}
    for c in CELLS:
        print(f"--- {c} ---"); res[c] = run(c)
    print("\n=== NATIVE 1.2 across 2025 ===")
    h = ["cell", "deals", "ret%", "maxDD%", "ulcer", "dailyavg%", "losers"]
    print(" ".join(f"{x:>9}" for x in h))
    rets = []
    for c, m in res.items():
        if not m:
            print(f"{c:>9}  NO REPORT"); continue
        print(" ".join(f"{str(m.get(k,'') if k!='cell' else c):>9}" for k in h))
        rets.append(m.get("ret%", 0.0))
    if rets:
        print(f"\n2025 summary: {len(rets)} cells | total ret% {sum(rets):.1f} | mean {np.mean(rets):.2f} "
              f"| neg cells {sum(1 for r in rets if r<0)} | active(>5 deals) "
              f"{sum(1 for m in res.values() if m and m.get('deals',0)>5)}/{len(rets)}")

if __name__ == "__main__":
    main()
