#!/bin/bash
# S2.C.5.2 — regime-aware lotMultiplier sample test.
# WT keeps lotMultiplier=4.0 (trend), adds lotMultiplierRange=2.5 (range).
# 5 cells: mar25 (weak, range-heavy), jul25 (weak), apr25 (monster, trend),
#          dec25 (monster, trend), jan26 (weak/marginal).
set +e
SET_FILE="C:\\Users\\nikof\\Documents\\GitHub\\MoneyDancer\\# GOLD cap 5k dd 4100 - hard scal, mix time, range burst zone.set"
EXPERT="MoneyDancer_2.0\\MoneyDancer_2.0.ex5"

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
    --input-override lotMultiplier=4.0 --input-override lotMultiplierRange=2.5
}

run "RLM-5k-mar25-2wk" "XAUUSD.duk_robo_2025" "2025.03.01" "2025.03.14"
run "RLM-5k-jul25-2wk" "XAUUSD.duk_robo_2025" "2025.07.01" "2025.07.14"
run "RLM-5k-apr25-2wk" "XAUUSD.duk_robo_2025" "2025.04.01" "2025.04.14"
run "RLM-5k-dec25-2wk" "XAUUSD.duk_robo_2025" "2025.12.01" "2025.12.14"
run "RLM-5k-jan26-2wk" "XAUUSD.duk_robo" "2026.01.01" "2026.01.14"

echo "===== S2.C.5.2 sample done ====="
