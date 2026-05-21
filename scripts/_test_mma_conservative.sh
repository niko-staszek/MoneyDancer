#!/bin/bash
set +e
SET_FILE="C:\Users\nikof\Documents\GitHub\MoneyDancer\# GOLD cap 5k dd 4100 - hard scal, mix time, range burst zone.set"
EXPERT="MoneyDancer_2.0\MoneyDancer_2.0.ex5"

run() {
  local run_id="$1"
  local symbol="$2"
  local from="$3"
  local to="$4"
  local constant="$5"
  local mx="$6"
  echo "===== ${run_id} (C=${constant}, Max=${mx}) ====="
  python scripts/f0_runner.py \
    --set-file "$SET_FILE" \
    --run-id "$run_id" \
    --symbol "$symbol" \
    --from-date "$from" \
    --to-date "$to" \
    --deposit 5000 \
    --expert "$EXPERT" \
    --input-override MaxSpreadPts=100 \
    --input-override MaxBasketLossPct=8.0 \
    --input-override MaxBasketSLPerDay=2 \
    --input-override MaxAllTimeDDPct=40.0 \
    --input-override RegimeMode=2 \
    --input-override RegimeTimeframe=15 \
    --input-override UseMMDClassifier=true \
    --input-override RegimeTrendMode=1 \
    --input-override FridayFlattenHour=20 \
    --input-override LotsBasePerThousand=0.002 \
    --input-override MinMoveAdaptiveMode=1 \
    --input-override MinMoveATRTimeframe=15 \
    --input-override MinMoveATRPeriod=14 \
    --input-override MinMoveATRConstant=${constant} \
    --input-override MinMovePointsMin=20 \
    --input-override MinMovePointsMax=${mx}
}

# Test conservative settings (C=1000, Max=50) on the regression cells + verify monsters still improve
run "MMA-CONS-5k-mar25-2wk" "XAUUSD.duk_robo_2025" "2025.03.01" "2025.03.14" "1000" "50"
run "MMA-CONS-5k-sep25-2wk" "XAUUSD.duk_robo_2025" "2025.09.01" "2025.09.14" "1000" "50"
run "MMA-CONS-5k-jan26-2wk" "XAUUSD.duk_robo" "2026.01.01" "2026.01.14" "1000" "50"
run "MMA-CONS-5k-dec25-2wk" "XAUUSD.duk_robo_2025" "2025.12.01" "2025.12.14" "1000" "50"
echo "===== MMA-CONS test done ====="
