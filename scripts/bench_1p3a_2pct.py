#!/usr/bin/env python3
"""Run the v1.6 deployable preset XAUUSD_1.3a_2pct.set (1.3a scalp + auto-lot 0.5-base
+ 2% equity-gated daily target + DD-40) across the 10 worst-fortnight windows @100k,
on MoneyDancer_1.6. A/B counterpart to the benchmark's 1.3a column.

Idempotent (skip if report exists); per-run MT5 reset (wait-for-flush, kill-if-stuck);
appends a summary row to runs/BENCH2_results.csv. Run via the self-relaunch wrapper
scripts/bench_1p3a_2pct_loop.sh for collision robustness.
"""
import csv, json, os, subprocess, time
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
os.chdir(ROOT)

EXPERT  = "MoneyDancer_1.6\\MoneyDancer_1.6.ex5"
PRESET  = str(ROOT / "mt5/1.6/MoneyDancer_1.6/presets/XAUUSD_1.3a_2pct.set")
DEPOSIT = 100000
PERIOD  = "M30"  # 1.3a native TF
OVERRIDES = ["MaxSpreadPts=45"]  # preset already carries auto-lot + 2% target + DD-40
WINDOWS = json.load(open("reports/bench-worst-months-20260610-125342Z/worst_windows.json"))
WINDOWS = sorted(WINDOWS, key=lambda w: -w[4])  # worst-range first

RESULTS = ROOT / "runs" / "BENCH2_results.csv"
RESULTS.parent.mkdir(exist_ok=True)
if not RESULTS.exists():
    RESULTS.write_text("month,window,sym,range_pct,status,deals,net,net_pct,max_dd_pct,maxlot,final_equity,blown\n")

def _running(name):
    out = subprocess.run(["tasklist"], capture_output=True, text=True).stdout.lower()
    return name in out

def reset_mt5(grace=300):
    subprocess.run(["taskkill", "//IM", "terminal64.exe", "//F"], capture_output=True)
    waited = 0
    while _running("metatester64") and waited < grace:
        time.sleep(5); waited += 5
    if _running("metatester64"):
        subprocess.run(["taskkill", "//IM", "metatester64.exe", "//F"], capture_output=True)
        time.sleep(10)
    time.sleep(5)

def summarize(rid):
    import pandas as pd, numpy as np
    c = ROOT / "runs" / rid / "trades.csv"
    if not c.exists():
        return None
    d = pd.read_csv(c)
    out = d[d.direction == "out"] if "direction" in d.columns else d
    net = float(out["profit"].sum()) if "profit" in out.columns else 0.0
    bal = np.concatenate([[DEPOSIT], DEPOSIT + out["profit"].cumsum().values]) if len(out) else np.array([DEPOSIT])
    peak = np.maximum.accumulate(bal); dd = (peak - bal) / peak * 100.0
    maxdd = float(dd.max()); maxlot = float(d["volume"].max()) if "volume" in d.columns else 0.0
    final = DEPOSIT + net
    return dict(deals=len(d), net=round(net, 2), net_pct=round(net / DEPOSIT * 100, 2),
                max_dd_pct=round(maxdd, 2), maxlot=maxlot, final_equity=round(final, 2),
                blown=int((final <= 0) or maxdd >= 99.0))

def main():
    total = len(WINDOWS)
    for i, (ym, frm, to, sym, rng) in enumerate(WINDOWS, 1):
        rid  = f"BENCH2-1.3a-{ym}"
        tcsv = ROOT / "runs" / rid / "trades.csv"
        rep  = ROOT / "runs" / rid / f"{rid}-report.htm"
        if tcsv.exists() or (rep.exists() and rep.stat().st_size > 0):
            print(f"[{i}/{total}] SKIP {rid} (already ran)"); continue
        ov = []
        for o in OVERRIDES:
            ov += ["--input-override", o]
        cmd = ["python", "scripts/f0_runner.py", "--set-file", PRESET, "--run-id", rid,
               "--symbol", sym, "--period", PERIOD, "--model", "0",
               "--from-date", frm, "--to-date", to, "--deposit", str(DEPOSIT),
               *ov, "--expert", EXPERT, "--timeout", "5400"]
        print(f"[{i}/{total}] RUN {rid} {sym} {PERIOD} {frm}..{to}")
        reset_mt5()
        subprocess.run(cmd)
        status = "OK"
        if rep.exists():
            for _t in range(3):
                subprocess.run(["python", "scripts/extract_trades_from_report.py",
                                "--report", str(rep), "--out", str(tcsv)])
                if tcsv.exists():
                    break
                time.sleep(4)
        s = summarize(rid)
        if s is None:
            row = [ym, f"{frm}..{to}", sym, rng, "NOREPORT", "", "", "", "", "", "", ""]
        else:
            row = [ym, f"{frm}..{to}", sym, rng, "OK", s["deals"], s["net"], s["net_pct"],
                   s["max_dd_pct"], s["maxlot"], s["final_equity"], s["blown"]]
        with open(RESULTS, "a", newline="") as fh:
            csv.writer(fh).writerow(row)
        print(f"      -> " + (f"net {s['net']} ({s['net_pct']}%) DD {s['max_dd_pct']}% maxlot {s['maxlot']} blown={s['blown']}" if s else "NOREPORT"))
    print("BENCH2 DONE")

if __name__ == "__main__":
    main()
