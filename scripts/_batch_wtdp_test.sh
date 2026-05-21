#!/bin/bash
# WTDP = WT + Dynamic Pyramid (PyramidFixedTPPts=150)
# Test on regression cells (mar25, mar26, feb26) + trend cell sep25 + a normal one (dec25)
set -e
SET_FILE="C:\\Users\\nikof\\Documents\\GitHub\\MoneyDancer\\# GOLD cap 5k dd 4100 - hard scal, mix time, range burst zone.set"
EXPERT="MoneyDancer_2.0\\MoneyDancer_2.0.ex5"

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
    --input-override UseNewsBlackout=false \
    --input-override UseSpreadSpikeGuard=false \
    --input-override HourBlockList="" \
    --input-override MaxDailyLossPct=0.0 \
    --input-override PyramRange=4 \
    --input-override PyramSlopeEmaPeriod=8 \
    --input-override PyramSlopeLookbackBars=3 \
    --input-override PyramSlopeAngleDeg=24.0 \
    --input-override PyramBEBufPts=65 \
    --input-override PyramidFixedTPPts=150
}

run "WTDP-5k-mar25-2wk" "XAUUSD.duk_robo_2025" "2025.03.01" "2025.03.14"
run "WTDP-5k-mar26-2wk" "XAUUSD.duk_robo" "2026.03.01" "2026.03.14"
run "WTDP-5k-feb26-2wk" "XAUUSD.duk_robo" "2026.02.01" "2026.02.14"
run "WTDP-5k-sep25-2wk" "XAUUSD.duk_robo_2025" "2025.09.01" "2025.09.14"
run "WTDP-5k-dec25-2wk" "XAUUSD.duk_robo_2025" "2025.12.01" "2025.12.14"
echo "===== WTDP test done ====="
