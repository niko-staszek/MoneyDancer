#!/bin/bash
# Test MinMovePoints + TP_Points variations on Jan26 (worst WT cell, +0.6%)
set -e
SET_FILE="C:\Users\nikof\Documents\GitHub\MoneyDancer\# GOLD cap 5k dd 4100 - hard scal, mix time, range burst zone.set"
EXPERT="MoneyDancer_2.0\MoneyDancer_2.0.ex5"

run() {
  local run_id="$1"
  local minmove="$2"
  local tp="$3"
  echo "===== ${run_id} (MinMove=${minmove}, TP=${tp}) ====="
  python scripts/f0_runner.py \
    --set-file "$SET_FILE" \
    --run-id "$run_id" \
    --symbol "XAUUSD.duk_robo" \
    --from-date "2026.01.01" \
    --to-date "2026.01.14" \
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
    --input-override MinMovePoints=${minmove} \
    --input-override TP_Points=${tp}
}

# WT-baseline: MinMove=25 (base set), TP=60 (base set)
run "FILT-jan26-minmove40" "40" "60"
run "FILT-jan26-tp100"     "25" "100"
run "FILT-jan26-tp80-mm35" "35" "80"
echo "===== filter test done ====="
