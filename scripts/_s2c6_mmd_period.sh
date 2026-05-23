#!/bin/bash
# S2.C.6 MMD cloud period tuning. 2 variants × 5 cells.
#   A: MMDPeriod_Red=8 (faster - more responsive regime classifier)
#   B: MMDPeriod_Red=24 (slower - less noisy regime classifier)
# This is the LAST cheap static-knob test. If both fail, declare iteration exhausted.
set +e
SET_FILE="C:\Users\nikof\Documents\GitHub\MoneyDancer\# GOLD cap 5k dd 4100 - hard scal, mix time, range burst zone.set"
EXPERT="MoneyDancer_2.0\MoneyDancer_2.0.ex5"

run() {
  local run_id="$1"; local symbol="$2"; local from="$3"; local to="$4"
  local red="$5"
  echo "===== ${run_id} (MMDPeriod_Red=${red}) ====="
  python scripts/f0_runner.py \
    --set-file "$SET_FILE" --run-id "$run_id" --symbol "$symbol" \
    --from-date "$from" --to-date "$to" --deposit 5000 --expert "$EXPERT" \
    --input-override MaxSpreadPts=100 --input-override MaxBasketLossPct=8.0 \
    --input-override MaxBasketSLPerDay=2 --input-override MaxAllTimeDDPct=40.0 \
    --input-override RegimeMode=2 --input-override RegimeTimeframe=15 \
    --input-override UseMMDClassifier=true --input-override RegimeTrendMode=1 \
    --input-override FridayFlattenHour=20 --input-override LotsBasePerThousand=0.002 \
    --input-override StepPoints=80 --input-override MinOrderDistancePts=60 \
    --input-override MMDPeriod_Red="$red"
}

# Variant A: Red=8 (faster)
echo "===== Variant A: MMDPeriod_Red=8 ====="
run "MMD_A-5k-mar25" "XAUUSD.duk_robo_2025" "2025.03.01" "2025.03.14" 8
run "MMD_A-5k-jul25" "XAUUSD.duk_robo_2025" "2025.07.01" "2025.07.14" 8
run "MMD_A-5k-dec25" "XAUUSD.duk_robo_2025" "2025.12.01" "2025.12.14" 8
run "MMD_A-5k-apr26" "XAUUSD.duk_robo"      "2026.04.01" "2026.04.14" 8
run "MMD_A-5k-jan26" "XAUUSD.duk_robo"      "2026.01.01" "2026.01.14" 8

# Variant B: Red=24 (slower)
echo "===== Variant B: MMDPeriod_Red=24 ====="
run "MMD_B-5k-mar25" "XAUUSD.duk_robo_2025" "2025.03.01" "2025.03.14" 24
run "MMD_B-5k-jul25" "XAUUSD.duk_robo_2025" "2025.07.01" "2025.07.14" 24
run "MMD_B-5k-dec25" "XAUUSD.duk_robo_2025" "2025.12.01" "2025.12.14" 24
run "MMD_B-5k-apr26" "XAUUSD.duk_robo"      "2026.04.01" "2026.04.14" 24
run "MMD_B-5k-jan26" "XAUUSD.duk_robo"      "2026.01.01" "2026.01.14" 24

echo "===== S2.C.6 MMD-period sample done ====="
