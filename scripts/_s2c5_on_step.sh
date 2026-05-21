#!/bin/bash
# S2.C.5.2 — regime-aware lotMultiplier ON TOP of STEP config.
# WT keeps lotMultiplier=4.0 (trend), lotMultiplierRange=2.5 (range).
# Plus STEP: StepPoints=80, MinOrderDistancePts=60.
# 5 cells: focus on cells where range vs trend matters most.
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
    --input-override lotMultiplier=4.0 --input-override lotMultiplierRange=2.5
}

# 5 cells: feb25 (broken under STEP — does regime-aware lotMult save it?), apr25, dec25, mar25, jan26
run "STEP-RLM-5k-feb25-2wk" "XAUUSD.duk_robo_2025" "2025.02.01" "2025.02.14"
run "STEP-RLM-5k-mar25-2wk" "XAUUSD.duk_robo_2025" "2025.03.01" "2025.03.14"
run "STEP-RLM-5k-jan26-2wk" "XAUUSD.duk_robo" "2026.01.01" "2026.01.14"
run "STEP-RLM-5k-dec25-2wk" "XAUUSD.duk_robo_2025" "2025.12.01" "2025.12.14"
run "STEP-RLM-5k-apr25-2wk" "XAUUSD.duk_robo_2025" "2025.04.01" "2025.04.14"

echo "===== STEP+RegimeLotMult sample done ====="
