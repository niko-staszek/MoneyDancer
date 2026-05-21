#!/bin/bash
# Isolate which STEP parameter caused feb25 regression.
# WT feb25 = +25.0%. STEP feb25 = -17.8%. Try each knob alone.
set +e
SET_FILE="C:\Users\nikof\Documents\GitHub\MoneyDancer\# GOLD cap 5k dd 4100 - hard scal, mix time, range burst zone.set"
EXPERT="MoneyDancer_2.0\MoneyDancer_2.0.ex5"

run() {
  local run_id="$1"; shift
  echo "===== ${run_id} ====="
  python scripts/f0_runner.py \
    --set-file "$SET_FILE" --run-id "$run_id" \
    --symbol "XAUUSD.duk_robo_2025" --from-date "2025.02.01" --to-date "2025.02.14" \
    --deposit 5000 --expert "$EXPERT" \
    --input-override MaxSpreadPts=100 --input-override MaxBasketLossPct=8.0 \
    --input-override MaxBasketSLPerDay=2 --input-override MaxAllTimeDDPct=40.0 \
    --input-override RegimeMode=2 --input-override RegimeTimeframe=15 \
    --input-override UseMMDClassifier=true --input-override RegimeTrendMode=1 \
    --input-override FridayFlattenHour=20 --input-override LotsBasePerThousand=0.002 \
    "$@"
}

# Variant A: only Step change (StepPoints=80, MinOrderDistancePts=40 default)
run "ISO-A-feb25" --input-override StepPoints=80
# Variant B: only MinDist change (StepPoints=120 default, MinOrderDistancePts=60)
run "ISO-B-feb25" --input-override MinOrderDistancePts=60
# Variant C: halfway (StepPoints=100, MinOrderDistancePts=50)
run "ISO-C-feb25" --input-override StepPoints=100 --input-override MinOrderDistancePts=50

echo "===== feb25 isolation done ====="
