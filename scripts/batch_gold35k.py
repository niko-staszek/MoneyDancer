#!/usr/bin/env python3
"""Backtest the #GOLD 35k set: native 1.x (untranslated) + 2025 OOS weeks (2.0 translated).
Serial. Extracts trades + prints a metrics table. Idempotent (skip if trades.csv exists)."""
import subprocess, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from detune_metrics import ulcer_index, max_dd_pct, daily_avg_pct, losing_basket_count
import pandas as pd

WT = Path(__file__).resolve().parents[1]
DEP = 35000

# (run_id, set_file, expert, symbol, from, to)
RUNS = [
    # native 1.x — untranslated set on its native EA (1.2 then 1.1 fallback handled by inspecting result)
    ("NATIVE12-2026", "gold35k_native.set", r"MoneyDancer_1.2\MoneyDancer_1.2.ex5", "XAUUSD.duk_robo", "2026.02.01", "2026.05.14"),
    ("NATIVE11-2026", "gold35k_native.set", r"MoneyDancer_1.1\MoneyDancer_1.1.ex5", "XAUUSD.duk_robo", "2026.02.01", "2026.05.14"),
    # 2025 OOS weeks — translated 2.0 set (set authored Jun-2025; H2 = post-creation OOS)
    ("T20-2025mar", "gold35k_translated.set", r"MoneyDancer_2.0\MoneyDancer_2.0.ex5", "XAUUSD.duk_robo_2025", "2025.03.03", "2025.03.14"),
    ("T20-2025jul", "gold35k_translated.set", r"MoneyDancer_2.0\MoneyDancer_2.0.ex5", "XAUUSD.duk_robo_2025", "2025.07.07", "2025.07.18"),
    ("T20-2025sep", "gold35k_translated.set", r"MoneyDancer_2.0\MoneyDancer_2.0.ex5", "XAUUSD.duk_robo_2025", "2025.09.08", "2025.09.19"),
    ("T20-2025nov", "gold35k_translated.set", r"MoneyDancer_2.0\MoneyDancer_2.0.ex5", "XAUUSD.duk_robo_2025", "2025.11.03", "2025.11.14"),
]

def metrics(rid):
    tc = WT / "runs" / rid / "trades.csv"
    if not (tc.exists() and tc.stat().st_size > 50):
        return None
    d = pd.read_csv(tc); o = d[d.direction == "out"]
    if not len(o):
        return {"deals": 0}
    return {"deals": len(o), "net": round(o.profit.sum(), 0),
            "ret%": round(o.profit.sum() / DEP * 100, 1),
            "maxDD%": round(max_dd_pct(d.balance), 1), "ulcer": round(ulcer_index(d.balance), 1),
            "dailyavg%": round(daily_avg_pct(d, DEP), 2), "losers": losing_basket_count(d),
            "maxlot": d.volume.max()}

def run(rid, setf, expert, sym, frm, to):
    rd = WT / "runs" / rid; tc = rd / "trades.csv"
    if not (tc.exists() and tc.stat().st_size > 50):
        cmd = [sys.executable, str(WT/"scripts"/"f0_runner.py"), "--set-file", str(WT/setf),
               "--run-id", rid, "--symbol", sym, "--period", "M15", "--model", "0",
               "--from-date", frm, "--to-date", to, "--deposit", str(DEP), "--expert", expert, "--timeout", "5400"]
        subprocess.run(cmd, cwd=str(WT))
        rpt = rd / f"{rid}-report.htm"
        if rpt.exists():
            subprocess.run([sys.executable, str(WT/"scripts"/"extract_trades_from_report.py"),
                            "--report", str(rpt), "--out", str(tc)])
        for lg in rd.glob("*.log"):
            try: lg.unlink()
            except OSError: pass
    return metrics(rid)

def main():
    res = {}
    for r in RUNS:
        print(f"--- {r[0]} ({r[2].split(chr(92))[0]}, {r[3]}, {r[4]}..{r[5]}) ---")
        res[r[0]] = run(*r)
    print("\n=== RESULTS ===")
    hdr = ["run", "deals", "net", "ret%", "maxDD%", "ulcer", "dailyavg%", "losers", "maxlot"]
    print(" ".join(f"{h:>10}" for h in hdr))
    for rid, m in res.items():
        if not m:
            print(f"{rid:>10}  NO REPORT (EA refused / license / no data)"); continue
        if m.get("deals", 0) == 0:
            print(f"{rid:>10}  0 deals (spread/hours blocked all entries)"); continue
        row = [rid] + [str(m.get(h, "")) for h in hdr[1:]]
        print(" ".join(f"{c:>10}" for c in row))

if __name__ == "__main__":
    main()
