#!/usr/bin/env python3
"""Run all the author's #GOLD sets NATIVE on MoneyDancer 1.2 (no translation - 1.2 IS
their scheme). MaxSpreadPts overridden to 45 (their 15 blocks duka_robo spread 25-28).
2026 4-month window. Tabulate to find the author's pattern + understand the EA."""
import subprocess, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from detune_metrics import ulcer_index, max_dd_pct, daily_avg_pct, losing_basket_count
import pandas as pd

WT = Path(__file__).resolve().parents[1]
DL = "C:/Users/nikof/Downloads"
EXPERT = r"MoneyDancer_1.2\MoneyDancer_1.2.ex5"
SYM = "XAUUSD.duk_robo"
FRM, TO = "2026.02.01", "2026.05.14"

# (run_id, set_file, period, deposit)
RUNS = [
    ("N12-35k-m15", f"{DL}/#GOLD capital-35k, h 1- 22, m15.set", "M15", 35000),
    ("N12-13a-m30", f"{DL}/TEST 13a M30+.set", "M30", 10000),
    ("N12-1p3a-m30", f"{DL}/TEST 1.3a.set", "M30", 10000),
    ("N12-3k-m1", f"{DL}/#GOLD capital-3k, h5-19, m1, sl,multix3.set", "M1", 3000),
    ("N12-5k-m5", f"{DL}/# GOLD cap 5k dd 4100 - hard scal, mix time, range burst zone.set", "M5", 5000),
]

def run(rid, setf, period, dep):
    rd = WT / "runs" / rid; tc = rd / "trades.csv"
    if not (tc.exists() and tc.stat().st_size > 50):
        subprocess.run([sys.executable, str(WT/"scripts"/"f0_runner.py"), "--set-file", setf,
                        "--run-id", rid, "--symbol", SYM, "--period", period, "--model", "0",
                        "--from-date", FRM, "--to-date", TO, "--deposit", str(dep), "--expert", EXPERT,
                        "--input-override", "MaxSpreadPts=45", "--timeout", "5400"], cwd=str(WT))
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
        return {"deals": 0}
    return {"deals": len(o), "net": round(o.profit.sum(), 0), "ret%": round(o.profit.sum()/dep*100, 1),
            "maxDD%": round(max_dd_pct(d.balance), 1), "ulcer": round(ulcer_index(d.balance), 1),
            "dailyavg%": round(daily_avg_pct(d, dep), 2), "losers": losing_basket_count(d), "maxlot": d.volume.max()}

def main():
    res = {}
    for r in RUNS:
        print(f"--- {r[0]} ({r[2]}, dep {r[3]}) ---"); res[r[0]] = run(*r)
    print("\n=== AUTHOR SETS on NATIVE 1.2 (2026 Feb-May) ===")
    h = ["run", "deals", "ret%", "maxDD%", "ulcer", "dailyavg%", "losers", "maxlot"]
    print(" ".join(f"{x:>11}" for x in h))
    for rid, m in res.items():
        if not m: print(f"{rid:>11}  NO REPORT"); continue
        if m.get("deals", 0) == 0: print(f"{rid:>11}  0 deals"); continue
        print(" ".join(f"{c:>11}" for c in [rid] + [str(m.get(k, "")) for k in h[1:]]))

if __name__ == "__main__":
    main()
