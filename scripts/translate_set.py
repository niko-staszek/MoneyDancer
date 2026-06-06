#!/usr/bin/env python3
"""Translate an old-scheme MoneyDancer .set (underscore names + single-session hours +
license fields) to the current camelCase 2.0 EA input names. Logs every param that does
NOT map to a real EA input (so nothing silently defaults).

    python scripts/translate_set.py "<src.set>" <out.set>
"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from f0_runner import parse_set_file

import re
_MQH = Path(__file__).resolve().parents[1] / "mt5/2.0/MoneyDancer_2.0/Include/Inputs.mqh"
EA_INPUTS = set(re.findall(r"^input\s+\S+\s+(\w+)", _MQH.read_text(errors="ignore"), re.M))

RENAME = {
    "lotMultiplier": "LotMultiplier", "TP_Points": "TPPoints", "SL_Points": "SLPoints",
    "bePoints": "BEPoints", "startBe": "StartBE", "maPeriod": "MAPeriod",
    "slopeLookbackBars": "SlopeLookbackBars", "slopeThresholdPts": "SlopeThresholdPts",
    "strongTrendPts": "StrongTrendPts", "MaxBasketDD_Pct": "MaxBasketDDPct",
    "MaxEquityDD_Pct": "MaxEquityDDPct", "RunnerBE_StartPts": "RunnerBEStartPts",
}
WEEKDAYS = ["Mon", "Tue", "Wed", "Thu", "Fri"]

def translate(src):
    raw = parse_set_file(Path(src))           # strips license/optimizer slots already
    out, dropped = {}, []
    # single-session hours -> per-weekday Start1/End1 (Start2/End2 disabled)
    sh, sm = raw.pop("TradeStartHour", None), raw.pop("TradeStartMinute", None)
    eh, em = raw.pop("TradeEndHour", None), raw.pop("TradeEndMinute", None)
    if sh is not None:
        for d in WEEKDAYS:
            out[f"{d}dayTrading" if d == "Mon" else f"{d}sdayTrading" if d == "Wed" else f"{d}rsdayTrading" if d == "Thu" else f"{d}day{'s' if False else ''}Trading"] = "1"
        # build clean weekday-trading + session bounds (explicit, avoid the ternary mess above)
    out = {}
    if sh is not None:
        names = {"Mon": "MondayTrading", "Tue": "TuesdayTrading", "Wed": "WednesdayTrading",
                 "Thu": "ThursdayTrading", "Fri": "FridayTrading"}
        for d in WEEKDAYS:
            out[names[d]] = "1"
            out[f"{d}Start1Hour"] = sh; out[f"{d}Start1Minute"] = sm or "0"
            out[f"{d}End1Hour"] = eh; out[f"{d}End1Minute"] = em or "0"
            out[f"{d}Start2Hour"] = "0"; out[f"{d}Start2Minute"] = "0"
            out[f"{d}End2Hour"] = "0"; out[f"{d}End2Minute"] = "0"
    # remaining params: rename then validate against EA inputs
    for k, v in raw.items():
        nk = RENAME.get(k, k)
        if nk in EA_INPUTS:
            out[nk] = v
        else:
            dropped.append(f"{k}={v}")
    return out, dropped

def main():
    src, dst = sys.argv[1], sys.argv[2]
    out, dropped = translate(src)
    # write as a flat .set (key=value), the form f0_runner.parse_set_file reads
    Path(dst).write_text("\n".join(f"{k}={v}" for k, v in out.items()) + "\n", encoding="utf-8")
    print(f"translated -> {dst} ({len(out)} EA params)")
    print(f"DROPPED (no matching EA input -> would default): {len(dropped)}")
    for d in sorted(dropped):
        print("  ", d)
    # sanity: key grid params present?
    for k in ("LotMultiplier", "TPPoints", "StepPoints", "MaxOrdersDir", "BEPoints", "StartBE"):
        print(f"  check {k} = {out.get(k, 'MISSING!')}")

if __name__ == "__main__":
    main()
