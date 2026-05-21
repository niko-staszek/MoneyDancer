#!/bin/bash
# Batch S17 on 2026 Jan-May using MD 2.0 on duk_robo (2026 overlay)
set -e
SET_FILE="C:\Users\nikof\Documents\GitHub\MoneyDancer\# GOLD cap 5k dd 4100 - hard scal, mix time, range burst zone.set"
EXPERT="MoneyDancer_2.0\MoneyDancer_2.0.ex5"
SYMBOL="XAUUSD.duk_robo"

run() {
  local run_id="$1"
  local from="$2"
  local to="$3"
  echo "===== ${run_id} (${from} -> ${to}) ====="
  python scripts/f0_runner.py \
    --set-file "$SET_FILE" \
    --run-id "$run_id" \
    --symbol "$SYMBOL" \
    --from-date "$from" \
    --to-date "$to" \
    --deposit 5000 \
    --expert "$EXPERT" \
    --input-override MaxSpreadPts=100 \
    --input-override MaxBasketLossPct=8.0 \
    --input-override MaxBasketSLPerDay=2 \
    --input-override MaxAllTimeDDPct=40.0 \
    --input-override RegimeMode=2 \
    --input-override RegimeAdxThresh=30 \
    --input-override RegimePeriod=14 \
    --input-override RegimeTimeframe=15 \
    --input-override UseMMDClassifier=true \
    --input-override FridayFlattenHour=20 \
    --input-override LotsBasePerThousand=0.002 \
    --input-override UseNewsBlackout=false \
    --input-override UseSpreadSpikeGuard=false \
    --input-override HourBlockList="" \
    --input-override MaxDailyLossPct=0.0
}

run "S2.0a-S17-2026-5k-jan-2wk" "2026.01.01" "2026.01.14"
run "S2.0a-S17-2026-5k-feb-2wk" "2026.02.01" "2026.02.14"
run "S2.0a-S17-2026-5k-mar-2wk" "2026.03.01" "2026.03.14"
run "S2.0a-S17-2026-5k-apr-2wk" "2026.04.01" "2026.04.14"
run "S2.0a-S17-2026-5k-may-2wk" "2026.05.01" "2026.05.14"
echo "===== 2026 S17 batch done ====="
