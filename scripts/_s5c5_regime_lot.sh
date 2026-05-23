#!/bin/bash
# S5.5c — Regime-aware base lot scaling. 4 combos × 5 cells.
# Code: LotMultRange + LotMultTrend already in Inputs.mqh defaults 1.0.
# STEP baseline: mar25 +37 / jul25 +59 / dec25 +306 / apr26 +258 / jan26 +19
set +e
SET_FILE="C:\Users\nikof\Documents\GitHub\MoneyDancer\# GOLD cap 5k dd 4100 - hard scal, mix time, range burst zone.set"
EXPERT="MoneyDancer_2.0\MoneyDancer_2.0.ex5"

run() {
  local run_id="$1"; local symbol="$2"; local from="$3"; local to="$4"
  local mr="$5"; local mt="$6"
  echo "===== ${run_id} (LotMultRange=${mr}, LotMultTrend=${mt}) ====="
  python scripts/f0_runner.py \
    --set-file "$SET_FILE" --run-id "$run_id" --symbol "$symbol" \
    --from-date "$from" --to-date "$to" --deposit 5000 --expert "$EXPERT" \
    --input-override MaxSpreadPts=100 --input-override MaxBasketLossPct=8.0 \
    --input-override MaxBasketSLPerDay=2 --input-override MaxAllTimeDDPct=40.0 \
    --input-override RegimeMode=2 --input-override RegimeTimeframe=15 \
    --input-override UseMMDClassifier=true --input-override RegimeTrendMode=1 \
    --input-override FridayFlattenHour=20 --input-override LotsBasePerThousand=0.002 \
    --input-override StepPoints=80 --input-override MinOrderDistancePts=60 \
    --input-override LotMultRange="$mr" --input-override LotMultTrend="$mt"
}

# C1: less in range, normal in trend
echo "===== Combo C1: Range=0.5 Trend=1.0 ====="
run "LOT_C1-5k-mar25" "XAUUSD.duk_robo_2025" "2025.03.01" "2025.03.14" 0.5 1.0
run "LOT_C1-5k-jul25" "XAUUSD.duk_robo_2025" "2025.07.01" "2025.07.14" 0.5 1.0
run "LOT_C1-5k-dec25" "XAUUSD.duk_robo_2025" "2025.12.01" "2025.12.14" 0.5 1.0
run "LOT_C1-5k-apr26" "XAUUSD.duk_robo"      "2026.04.01" "2026.04.14" 0.5 1.0
run "LOT_C1-5k-jan26" "XAUUSD.duk_robo"      "2026.01.01" "2026.01.14" 0.5 1.0

# C2: normal in range, push in trend
echo "===== Combo C2: Range=1.0 Trend=1.5 ====="
run "LOT_C2-5k-mar25" "XAUUSD.duk_robo_2025" "2025.03.01" "2025.03.14" 1.0 1.5
run "LOT_C2-5k-jul25" "XAUUSD.duk_robo_2025" "2025.07.01" "2025.07.14" 1.0 1.5
run "LOT_C2-5k-dec25" "XAUUSD.duk_robo_2025" "2025.12.01" "2025.12.14" 1.0 1.5
run "LOT_C2-5k-apr26" "XAUUSD.duk_robo"      "2026.04.01" "2026.04.14" 1.0 1.5
run "LOT_C2-5k-jan26" "XAUUSD.duk_robo"      "2026.01.01" "2026.01.14" 1.0 1.5

# C3: less in range, push in trend
echo "===== Combo C3: Range=0.5 Trend=1.5 ====="
run "LOT_C3-5k-mar25" "XAUUSD.duk_robo_2025" "2025.03.01" "2025.03.14" 0.5 1.5
run "LOT_C3-5k-jul25" "XAUUSD.duk_robo_2025" "2025.07.01" "2025.07.14" 0.5 1.5
run "LOT_C3-5k-dec25" "XAUUSD.duk_robo_2025" "2025.12.01" "2025.12.14" 0.5 1.5
run "LOT_C3-5k-apr26" "XAUUSD.duk_robo"      "2026.04.01" "2026.04.14" 0.5 1.5
run "LOT_C3-5k-jan26" "XAUUSD.duk_robo"      "2026.01.01" "2026.01.14" 0.5 1.5

# C4: control / inverse — push in range, less in trend
echo "===== Combo C4 (inverse/control): Range=1.5 Trend=0.5 ====="
run "LOT_C4-5k-mar25" "XAUUSD.duk_robo_2025" "2025.03.01" "2025.03.14" 1.5 0.5
run "LOT_C4-5k-jul25" "XAUUSD.duk_robo_2025" "2025.07.01" "2025.07.14" 1.5 0.5
run "LOT_C4-5k-dec25" "XAUUSD.duk_robo_2025" "2025.12.01" "2025.12.14" 1.5 0.5
run "LOT_C4-5k-apr26" "XAUUSD.duk_robo"      "2026.04.01" "2026.04.14" 1.5 0.5
run "LOT_C4-5k-jan26" "XAUUSD.duk_robo"      "2026.01.01" "2026.01.14" 1.5 0.5

echo "===== S5.5c regime-lot sample done ====="
