#!/bin/bash
# Test ATR_INVERSE adaptive MinMove on representative cells
# Low-vol month (jan26) should get high MinMove, high-vol month (dec25) should get low.
set +e  # don't abort batch on single failure
SET_FILE="C:\Users\nikof\Documents\GitHub\MoneyDancer\# GOLD cap 5k dd 4100 - hard scal, mix time, range burst zone.set"
EXPERT="MoneyDancer_2.0\MoneyDancer_2.0.ex5"

run() {
  local run_id="$1"
  local symbol="$2"
  local from="$3"
  local to="$4"
  echo "===== ${run_id} (${from} -> ${to}) ====="
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
    --input-override MinMoveATRTimeframe=16385 \
    --input-override MinMoveATRPeriod=14 \
    --input-override MinMoveATRConstant=1500.0 \
    --input-override MinMovePointsMin=20 \
    --input-override MinMovePointsMax=80
}

run "MMA-INV-5k-jan26-2wk" "XAUUSD.duk_robo" "2026.01.01" "2026.01.14"
run "MMA-INV-5k-dec25-2wk" "XAUUSD.duk_robo_2025" "2025.12.01" "2025.12.14"
run "MMA-INV-5k-apr26-2wk" "XAUUSD.duk_robo" "2026.04.01" "2026.04.14"
run "MMA-INV-5k-mar25-2wk" "XAUUSD.duk_robo_2025" "2025.03.01" "2025.03.14"
run "MMA-INV-5k-mar26-2wk" "XAUUSD.duk_robo" "2026.03.01" "2026.03.14"
run "MMA-INV-5k-sep25-2wk" "XAUUSD.duk_robo_2025" "2025.09.01" "2025.09.14"
echo "===== MMA-INV test done ====="
