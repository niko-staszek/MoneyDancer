#!/bin/bash
# S7.1 Walk-forward: continuous 17-month STEP backtest.
# 3 contiguous half-year windows covering Jan 2025 → May 2026.
# Fixed lot (LotsBase=0.01, LotsBasePerThousand=0) isolates strategy from compounding.
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
    --input-override FridayFlattenHour=20 \
    --input-override LotsBase=0.01 --input-override LotsBasePerThousand=0.0 \
    --input-override StepPoints=80 --input-override MinOrderDistancePts=60
}

# 3 contiguous half-year windows. Fixed lot 0.01 throughout.
run "WF-STEP-5k-H1-2025" "XAUUSD.duk_robo_2025" "2025.01.01" "2025.06.30"
run "WF-STEP-5k-H2-2025" "XAUUSD.duk_robo_2025" "2025.07.01" "2025.12.31"
run "WF-STEP-5k-H1-2026" "XAUUSD.duk_robo" "2026.01.01" "2026.05.31"

echo "===== Walk-forward continuous done ====="
