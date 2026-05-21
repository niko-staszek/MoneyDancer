#!/bin/bash
# S2.C.8 round 3: CONDITIONAL flatten at 22:00 — only close losing baskets (threshold=1% equity).
# Hypothesis: lets winning baskets capture overnight monster moves while cutting bleeding baskets
# before the closed window.
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
    --input-override DailyResumeHour=1 --input-override DailyPreCloseLossThresholdPct=1.0
}

run "PRECLOSE_C1-5k-may25-H2" "XAUUSD.duk_robo_2025" "2025.05.15" "2025.05.30"
run "PRECLOSE_C1-5k-dec25-H1" "XAUUSD.duk_robo_2025" "2025.12.01" "2025.12.14"
run "PRECLOSE_C1-5k-apr26-H1" "XAUUSD.duk_robo"      "2026.04.01" "2026.04.14"
run "PRECLOSE_C1-5k-feb25-H1" "XAUUSD.duk_robo_2025" "2025.02.01" "2025.02.14"
run "PRECLOSE_C1-5k-mar25-H1" "XAUUSD.duk_robo_2025" "2025.03.01" "2025.03.14"
run "PRECLOSE_C1-5k-jan26-H1" "XAUUSD.duk_robo"      "2026.01.01" "2026.01.14"

echo "===== S2.C.8 conditional sample done ====="
