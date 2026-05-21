#!/bin/bash
# Test MinMovePoints=40 on a representative sample (monster + regression + trend + weak)
set -e
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
    --input-override MinMovePoints=40
}

# Monster: dec25 (was +191), apr26 (was +185)
run "MM40-5k-dec25-2wk" "XAUUSD.duk_robo_2025" "2025.12.01" "2025.12.14"
run "MM40-5k-apr26-2wk" "XAUUSD.duk_robo" "2026.04.01" "2026.04.14"
# Regression: feb26 (was +46), mar26 (was +60)
run "MM40-5k-feb26-2wk" "XAUUSD.duk_robo" "2026.02.01" "2026.02.14"
run "MM40-5k-mar26-2wk" "XAUUSD.duk_robo" "2026.03.01" "2026.03.14"
# Trend: sep25 (was +66, biggest WT save)
run "MM40-5k-sep25-2wk" "XAUUSD.duk_robo_2025" "2025.09.01" "2025.09.14"
# Other weak: mar25 (was +3.3)
run "MM40-5k-mar25-2wk" "XAUUSD.duk_robo_2025" "2025.03.01" "2025.03.14"
echo "===== MM40 sample test done ====="
