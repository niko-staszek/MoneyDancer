#!/bin/bash
# Second-half-of-month OOS test on STEP.
# 17 cells covering days 15-28/30 of each month Jan25-May26.
# Tests STEP on data NOT in the original first-half sweep.
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
    --input-override StepPoints=80 --input-override MinOrderDistancePts=60
}

# 17 cells: days 15-28/30 of each month (second half — OOS vs first-half sweep)
run "STEP-OOS-5k-jan25-H2" "XAUUSD.duk_robo_2025" "2025.01.15" "2025.01.30"
run "STEP-OOS-5k-feb25-H2" "XAUUSD.duk_robo_2025" "2025.02.15" "2025.02.28"
run "STEP-OOS-5k-mar25-H2" "XAUUSD.duk_robo_2025" "2025.03.15" "2025.03.30"
run "STEP-OOS-5k-apr25-H2" "XAUUSD.duk_robo_2025" "2025.04.15" "2025.04.30"
run "STEP-OOS-5k-may25-H2" "XAUUSD.duk_robo_2025" "2025.05.15" "2025.05.30"
run "STEP-OOS-5k-jun25-H2" "XAUUSD.duk_robo_2025" "2025.06.15" "2025.06.30"
run "STEP-OOS-5k-jul25-H2" "XAUUSD.duk_robo_2025" "2025.07.15" "2025.07.30"
run "STEP-OOS-5k-aug25-H2" "XAUUSD.duk_robo_2025" "2025.08.15" "2025.08.30"
run "STEP-OOS-5k-sep25-H2" "XAUUSD.duk_robo_2025" "2025.09.15" "2025.09.30"
run "STEP-OOS-5k-oct25-H2" "XAUUSD.duk_robo_2025" "2025.10.15" "2025.10.30"
run "STEP-OOS-5k-nov25-H2" "XAUUSD.duk_robo_2025" "2025.11.15" "2025.11.30"
run "STEP-OOS-5k-dec25-H2" "XAUUSD.duk_robo_2025" "2025.12.15" "2025.12.30"
run "STEP-OOS-5k-jan26-H2" "XAUUSD.duk_robo" "2026.01.15" "2026.01.30"
run "STEP-OOS-5k-feb26-H2" "XAUUSD.duk_robo" "2026.02.15" "2026.02.28"
run "STEP-OOS-5k-mar26-H2" "XAUUSD.duk_robo" "2026.03.15" "2026.03.30"
run "STEP-OOS-5k-apr26-H2" "XAUUSD.duk_robo" "2026.04.15" "2026.04.30"
run "STEP-OOS-5k-may26-H2" "XAUUSD.duk_robo" "2026.05.15" "2026.05.30"

echo "===== STEP second-half OOS done ====="
