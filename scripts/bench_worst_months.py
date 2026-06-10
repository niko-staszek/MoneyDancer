#!/usr/bin/env python3
"""Benchmark: all 5 author .set files x 10 worst-fortnight windows (2025-2026),
deposit 100k, v1.4 auto-lot ON (Add/Equity, div 1000, inc 0.01), Model=0.

Idempotent: skips a run if its trades.csv already exists. Appends a summary row per
run to runs/BENCH_results.csv so partial progress is queryable mid-batch.

Run: python scripts/bench_worst_months.py
"""
import csv, json, os, subprocess, sys, hashlib, time
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
os.chdir(ROOT)

EXPERT = "MoneyDancer_1.4\\MoneyDancer_1.4.ex5"
DEPOSIT = 100000
AUTO_OVERRIDES = [  # v1.4 auto-lot ON, default Add/Equity
    "AutoLotScaling=1", "AutoLotType=0", "AutoLotMode=0",
    "AutoLotDivisor=1000", "AutoLotIncrement=0.01", "MaxSpreadPts=45",
]
PRESET_DIR = ROOT / "mt5/1.4/MoneyDancer_1.4/presets/author-reference"
SETS = [  # (id, filename, timeframe)
    ("35k",  "#GOLD capital-35k, h 1- 22, m15.set", "M15"),
    ("13a",  "TEST 13a M30+.set",                   "M30"),
    ("1.3a", "TEST 1.3a.set",                        "M30"),
    ("5k",   "# GOLD cap 5k dd 4100 - hard scal, mix time, range burst zone.set", "M5"),
    ("3k",   "#GOLD capital-3k, h5-19, m1, sl,multix3.set", "M1"),
]
# worst-fortnight windows, ordered worst-range first so the hardest months finish early
WINDOWS = sorted(json.load(open("/tmp/worstwin.json")), key=lambda w: -w[4])

RESULTS = ROOT / "runs" / "BENCH_results.csv"
RESULTS.parent.mkdir(exist_ok=True)
if not RESULTS.exists():
    RESULTS.write_text("set,month,window,sym,range_pct,status,deals,net,net_pct,max_dd_pct,maxlot,final_equity,blown\n")

def summarize(rid):
    """deals, net, net%, maxDD%, maxlot, final_equity, blown from trades.csv."""
    import pandas as pd
    c = ROOT / "runs" / rid / "trades.csv"
    if not c.exists():
        return None
    d = pd.read_csv(c)
    out = d[d.direction == "out"] if "direction" in d.columns else d
    net = float(out["profit"].sum()) if "profit" in out.columns else 0.0
    bal = DEPOSIT + out["profit"].cumsum().values if len(out) else [DEPOSIT]
    import numpy as np
    b = np.asarray(bal, float)
    peak = np.maximum.accumulate(np.concatenate([[DEPOSIT], b]))
    dd = (peak - np.concatenate([[DEPOSIT], b])) / peak * 100.0
    maxdd = float(dd.max())
    maxlot = float(d["volume"].max()) if "volume" in d.columns else 0.0
    final = DEPOSIT + net
    blown = (final <= 0) or (maxdd >= 99.0)
    return dict(deals=len(d), net=round(net, 2), net_pct=round(net / DEPOSIT * 100, 2),
                max_dd_pct=round(maxdd, 2), maxlot=maxlot, final_equity=round(final, 2),
                blown=int(blown))

def _running(name):
    out = subprocess.run(["tasklist"], capture_output=True, text=True).stdout.lower()
    return name in out

def reset_mt5(grace=60):
    """Clean MT5 state before a run: kill terminal64, wait for metatester64 to exit
    naturally (it may be finalizing a big report), force-kill only if stuck, then settle.
    Killing a BUSY metatester breaks the agent pool, so we wait first."""
    subprocess.run(["taskkill", "//IM", "terminal64.exe", "//F"], capture_output=True)
    for _ in range(max(1, grace // 3)):
        if not _running("metatester64") and not _running("terminal64"):
            break
        time.sleep(3)
    subprocess.run(["taskkill", "//IM", "metatester64.exe", "//F"], capture_output=True)
    time.sleep(5)

def main():
    # status-aware: a run is "done" only if it produced trades (OK) — NOREPORT rows must retry
    done = set()
    if RESULTS.exists():
        for r in csv.DictReader(open(RESULTS)):
            if r.get("status") == "OK":
                done.add((r["set"], r["month"]))
    total = len(SETS) * len(WINDOWS)
    i = 0
    for ym, frm, to, sym, rng in WINDOWS:
        for sid, fname, tf in SETS:
            i += 1
            rid = f"BENCH-{sid}-{ym}"
            tcsv = ROOT / "runs" / rid / "trades.csv"
            if (sid, ym) in done or tcsv.exists():
                print(f"[{i}/{total}] SKIP {rid} (done)")
                continue
            setpath = PRESET_DIR / fname
            ov = []
            for o in AUTO_OVERRIDES:
                ov += ["--input-override", o]
            cmd = ["python", "scripts/f0_runner.py", "--set-file", str(setpath),
                   "--run-id", rid, "--symbol", sym, "--period", tf, "--model", "0",
                   "--from-date", frm, "--to-date", to, "--deposit", str(DEPOSIT),
                   *ov, "--expert", EXPERT, "--timeout", "5400"]
            print(f"[{i}/{total}] RUN {rid} {sym} {tf} {frm}..{to}")
            reset_mt5()              # clean MT5 state before each launch (avoids agent-pool collision)
            subprocess.run(cmd)
            rep = ROOT / "runs" / rid / f"{rid}-report.htm"
            status = "OK"
            if rep.exists():
                for _try in range(3):   # extract can transiently fail on huge reports; retry
                    subprocess.run(["python", "scripts/extract_trades_from_report.py",
                                    "--report", str(rep), "--out", str(tcsv)])
                    if tcsv.exists():
                        break
                    time.sleep(4)
            s = summarize(rid)
            if s is None:
                status = "NOREPORT"
                row = [sid, ym, f"{frm}..{to}", sym, rng, status, "", "", "", "", "", "", ""]
            else:
                row = [sid, ym, f"{frm}..{to}", sym, rng, status, s["deals"], s["net"],
                       s["net_pct"], s["max_dd_pct"], s["maxlot"], s["final_equity"], s["blown"]]
            with open(RESULTS, "a", newline="") as fh:
                csv.writer(fh).writerow(row)
            print(f"      -> {status} " + (f"net {s['net']} ({s['net_pct']}%) DD {s['max_dd_pct']}% maxlot {s['maxlot']} blown={s['blown']}" if s else ""))
    print("BENCH DONE")

if __name__ == "__main__":
    main()
