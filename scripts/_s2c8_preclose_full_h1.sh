#!/bin/bash
# S2.C.8 Daily pre-close flatten — full 17-cell H1 sweep on STEP base.
# CONFIG: cond@6% threshold, cutoff=22:00 server time, resume next day at 01:00.
# Round-5 sample (4 cells) was net positive vs STEP. This validates on full H1.
# Decision: ship STEP+PRECLOSE if total >= $82,120 (STEP) AND >=16/17 positive
# AND max DD <= 37.8% (STEP max). Else keep STEP.
set +e
SET_FILE="C:\Users\nikof\Documents\GitHub\MoneyDancer\# GOLD cap 5k dd 4100 - hard scal, mix time, range burst zone.set"
EXPERT="MoneyDancer_2.0\MoneyDancer_2.0.ex5"

run() {
  local run_id="$1"; local symbol="$2"; local from="$3"; local to="$4"
  echo "===== ${run_id} ====="
  python scripts/f0_runner.py \
    --set-file "$SET_FILE" --run-id "$run_id" --symbol "$symbol" \
    --from-date "$from" --to-date "$to" --deposit 5000 --expert "$EXPERT" \
    --input-override MaxSpreadPts=100 --input-override MaxBasketLossPct=8.0 \
    --input-override MaxBasketSLPerDay=2 --input-override MaxAllTimeDDPct=40.0 \
    --input-override RegimeMode=2 --input-override RegimeTimeframe=15 \
    --input-override UseMMDClassifier=true --input-override RegimeTrendMode=1 \
    --input-override FridayFlattenHour=20 --input-override LotsBasePerThousand=0.002 \
    --input-override StepPoints=80 --input-override MinOrderDistancePts=60 \
    --input-override DailyPreCloseHour=22 --input-override DailyPreCloseMinute=0 \
    --input-override DailyResumeHour=1 --input-override DailyPreCloseLossThresholdPct=6.0
}

# 17 cells: H1 (days 1-14) of each month Jan25-May26
run "PRECLOSE_C6-5k-jan25" "XAUUSD.duk_robo_2025" "2025.01.01" "2025.01.14"
run "PRECLOSE_C6-5k-feb25" "XAUUSD.duk_robo_2025" "2025.02.01" "2025.02.14"
run "PRECLOSE_C6-5k-mar25" "XAUUSD.duk_robo_2025" "2025.03.01" "2025.03.14"
run "PRECLOSE_C6-5k-apr25" "XAUUSD.duk_robo_2025" "2025.04.01" "2025.04.14"
run "PRECLOSE_C6-5k-may25" "XAUUSD.duk_robo_2025" "2025.05.01" "2025.05.14"
run "PRECLOSE_C6-5k-jun25" "XAUUSD.duk_robo_2025" "2025.06.01" "2025.06.14"
run "PRECLOSE_C6-5k-jul25" "XAUUSD.duk_robo_2025" "2025.07.01" "2025.07.14"
run "PRECLOSE_C6-5k-aug25" "XAUUSD.duk_robo_2025" "2025.08.01" "2025.08.14"
run "PRECLOSE_C6-5k-sep25" "XAUUSD.duk_robo_2025" "2025.09.01" "2025.09.14"
run "PRECLOSE_C6-5k-oct25" "XAUUSD.duk_robo_2025" "2025.10.01" "2025.10.14"
run "PRECLOSE_C6-5k-nov25" "XAUUSD.duk_robo_2025" "2025.11.01" "2025.11.14"
run "PRECLOSE_C6-5k-dec25" "XAUUSD.duk_robo_2025" "2025.12.01" "2025.12.14"
run "PRECLOSE_C6-5k-jan26" "XAUUSD.duk_robo"      "2026.01.01" "2026.01.14"
run "PRECLOSE_C6-5k-feb26" "XAUUSD.duk_robo"      "2026.02.01" "2026.02.14"
run "PRECLOSE_C6-5k-mar26" "XAUUSD.duk_robo"      "2026.03.01" "2026.03.14"
run "PRECLOSE_C6-5k-apr26" "XAUUSD.duk_robo"      "2026.04.01" "2026.04.14"
run "PRECLOSE_C6-5k-may26" "XAUUSD.duk_robo"      "2026.05.01" "2026.05.14"

echo "===== S2.C.8 full H1 sweep done ====="
