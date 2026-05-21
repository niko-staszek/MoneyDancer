#!/bin/bash
# Variant (a) WITH_TREND_ONLY full 17-month sweep
set -e
SET_FILE="C:\Users\nikof\Documents\GitHub\MoneyDancer\# GOLD cap 5k dd 4100 - hard scal, mix time, range burst zone.set"
EXPERT="MoneyDancer_2.0\MoneyDancer_2.0.ex5"

run() {
  local run_id="$1"
  local symbol="$2"
  local from="$3"
  local to="$4"
  echo "===== ${run_id} (${from} -> ${to} on ${symbol}) ====="
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
    --input-override RegimeAdxThresh=30 \
    --input-override RegimePeriod=14 \
    --input-override RegimeTimeframe=15 \
    --input-override UseMMDClassifier=true \
    --input-override RegimeTrendMode=1 \
    --input-override FridayFlattenHour=20 \
    --input-override LotsBasePerThousand=0.002 \
    --input-override UseNewsBlackout=false \
    --input-override UseSpreadSpikeGuard=false \
    --input-override HourBlockList="" \
    --input-override MaxDailyLossPct=0.0
}

# 2025 cells (skip sep — already done)
run "S3.2b-WT-5k-jan25-2wk" "XAUUSD.duk_robo_2025" "2025.01.01" "2025.01.14"
run "S3.2b-WT-5k-feb25-2wk" "XAUUSD.duk_robo_2025" "2025.02.01" "2025.02.14"
run "S3.2b-WT-5k-mar25-2wk" "XAUUSD.duk_robo_2025" "2025.03.01" "2025.03.14"
run "S3.2b-WT-5k-apr25-2wk" "XAUUSD.duk_robo_2025" "2025.04.01" "2025.04.14"
run "S3.2b-WT-5k-may25-2wk" "XAUUSD.duk_robo_2025" "2025.05.01" "2025.05.14"
run "S3.2b-WT-5k-jun25-2wk" "XAUUSD.duk_robo_2025" "2025.06.01" "2025.06.14"
run "S3.2b-WT-5k-jul25-2wk" "XAUUSD.duk_robo_2025" "2025.07.01" "2025.07.14"
run "S3.2b-WT-5k-aug25-2wk" "XAUUSD.duk_robo_2025" "2025.08.01" "2025.08.14"
run "S3.2b-WT-5k-oct25-2wk" "XAUUSD.duk_robo_2025" "2025.10.01" "2025.10.14"
run "S3.2b-WT-5k-nov25-2wk" "XAUUSD.duk_robo_2025" "2025.11.01" "2025.11.14"
run "S3.2b-WT-5k-dec25-2wk" "XAUUSD.duk_robo_2025" "2025.12.01" "2025.12.14"
# 2026 cells
run "S3.2b-WT-5k-jan26-2wk" "XAUUSD.duk_robo" "2026.01.01" "2026.01.14"
run "S3.2b-WT-5k-feb26-2wk" "XAUUSD.duk_robo" "2026.02.01" "2026.02.14"
run "S3.2b-WT-5k-mar26-2wk" "XAUUSD.duk_robo" "2026.03.01" "2026.03.14"
run "S3.2b-WT-5k-apr26-2wk" "XAUUSD.duk_robo" "2026.04.01" "2026.04.14"
run "S3.2b-WT-5k-may26-2wk" "XAUUSD.duk_robo" "2026.05.01" "2026.05.14"
echo "===== S3.2b WITH_TREND 16-cell batch done ====="
