#!/bin/bash
# S2.C.4 — Martingale shape sample. STEP base + 3 variants on 5 cells each.
#   A. startBe=3      (delayed martingale: 4 trades in basket before geometric adds)
#   B. MaxOrdersDir=30 (depth cap, was 50)
#   C. combined (A + B)
# Cells: mar25 (weak), jul25 (weak), dec25 (monster), apr26 (monster), jan26 (marginal)
# STEP baseline numbers (H1): mar25 +37.0, jul25 +59.4, dec25 +305.8, apr26 +258.4, jan26 +19.0
# Acceptance: 3/5 cells improve, no cell -30pp, max DD <= 37.8%
set +e
SET_FILE="C:\Users\nikof\Documents\GitHub\MoneyDancer\# GOLD cap 5k dd 4100 - hard scal, mix time, range burst zone.set"
EXPERT="MoneyDancer_2.0\MoneyDancer_2.0.ex5"

run() {
  local run_id="$1"; local symbol="$2"; local from="$3"; local to="$4"
  local startbe="$5"; local maxord="$6"
  echo "===== ${run_id} (startBe=${startbe}, MaxOrd=${maxord}) ====="
  python scripts/f0_runner.py \
    --set-file "$SET_FILE" --run-id "$run_id" --symbol "$symbol" \
    --from-date "$from" --to-date "$to" --deposit 5000 --expert "$EXPERT" \
    --input-override MaxSpreadPts=100 --input-override MaxBasketLossPct=8.0 \
    --input-override MaxBasketSLPerDay=2 --input-override MaxAllTimeDDPct=40.0 \
    --input-override RegimeMode=2 --input-override RegimeTimeframe=15 \
    --input-override UseMMDClassifier=true --input-override RegimeTrendMode=1 \
    --input-override FridayFlattenHour=20 --input-override LotsBasePerThousand=0.002 \
    --input-override StepPoints=80 --input-override MinOrderDistancePts=60 \
    --input-override startBe="$startbe" --input-override MaxOrdersDir="$maxord"
}

# Variant A: startBe=3 (delayed martingale, MaxOrdersDir unchanged at 50)
echo "===== Variant A: startBe=3 ====="
run "MART_A-5k-mar25" "XAUUSD.duk_robo_2025" "2025.03.01" "2025.03.14" 3 50
run "MART_A-5k-jul25" "XAUUSD.duk_robo_2025" "2025.07.01" "2025.07.14" 3 50
run "MART_A-5k-dec25" "XAUUSD.duk_robo_2025" "2025.12.01" "2025.12.14" 3 50
run "MART_A-5k-apr26" "XAUUSD.duk_robo"      "2026.04.01" "2026.04.14" 3 50
run "MART_A-5k-jan26" "XAUUSD.duk_robo"      "2026.01.01" "2026.01.14" 3 50

# Variant B: MaxOrdersDir=30 (depth cap, startBe=1 = STEP default)
echo "===== Variant B: MaxOrdersDir=30 ====="
run "MART_B-5k-mar25" "XAUUSD.duk_robo_2025" "2025.03.01" "2025.03.14" 1 30
run "MART_B-5k-jul25" "XAUUSD.duk_robo_2025" "2025.07.01" "2025.07.14" 1 30
run "MART_B-5k-dec25" "XAUUSD.duk_robo_2025" "2025.12.01" "2025.12.14" 1 30
run "MART_B-5k-apr26" "XAUUSD.duk_robo"      "2026.04.01" "2026.04.14" 1 30
run "MART_B-5k-jan26" "XAUUSD.duk_robo"      "2026.01.01" "2026.01.14" 1 30

# Variant C: combined (startBe=3 + MaxOrdersDir=30)
echo "===== Variant C: startBe=3 + MaxOrdersDir=30 ====="
run "MART_C-5k-mar25" "XAUUSD.duk_robo_2025" "2025.03.01" "2025.03.14" 3 30
run "MART_C-5k-jul25" "XAUUSD.duk_robo_2025" "2025.07.01" "2025.07.14" 3 30
run "MART_C-5k-dec25" "XAUUSD.duk_robo_2025" "2025.12.01" "2025.12.14" 3 30
run "MART_C-5k-apr26" "XAUUSD.duk_robo"      "2026.04.01" "2026.04.14" 3 30
run "MART_C-5k-jan26" "XAUUSD.duk_robo"      "2026.01.01" "2026.01.14" 3 30

echo "===== S2.C.4 martingale-shape sample done ====="
