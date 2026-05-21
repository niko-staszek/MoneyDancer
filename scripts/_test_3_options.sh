#!/bin/bash
# Test all 3 path-dependent basket-handling options.
# 5 critical cells: mar25 (weak), jan26 (worst), sep25 (trend save), dec25 (monster), apr25 (monster)
set +e
SET_FILE="C:\Users\nikof\Documents\GitHub\MoneyDancer\# GOLD cap 5k dd 4100 - hard scal, mix time, range burst zone.set"
EXPERT="MoneyDancer_2.0\MoneyDancer_2.0.ex5"

run() {
  local run_id="$1"
  local symbol="$2"
  local from="$3"
  local to="$4"
  shift 4
  echo "===== ${run_id} (${from} -> ${to}) ====="
  python scripts/f0_runner.py \
    --set-file "$SET_FILE" --run-id "$run_id" --symbol "$symbol" \
    --from-date "$from" --to-date "$to" --deposit 5000 --expert "$EXPERT" \
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
    "$@"
}

# Option 1: regime-aware basket SL (Range=8 keep, TrendWith=12, TrendAgainst=4)
for c in mar25 jan26 sep25 dec25 apr25; do
  case $c in
    mar25) symbol="XAUUSD.duk_robo_2025"; from="2025.03.01"; to="2025.03.14";;
    jan26) symbol="XAUUSD.duk_robo"; from="2026.01.01"; to="2026.01.14";;
    sep25) symbol="XAUUSD.duk_robo_2025"; from="2025.09.01"; to="2025.09.14";;
    dec25) symbol="XAUUSD.duk_robo_2025"; from="2025.12.01"; to="2025.12.14";;
    apr25) symbol="XAUUSD.duk_robo_2025"; from="2025.04.01"; to="2025.04.14";;
  esac
  run "OPT1-5k-${c}-2wk" "$symbol" "$from" "$to" \
    --input-override MaxBasketLossPctRange=8.0 \
    --input-override MaxBasketLossPctTrendWith=12.0 \
    --input-override MaxBasketLossPctTrendAgainst=4.0
done

# Option 2: BlockDOnAdverseMMD
for c in mar25 jan26 sep25 dec25 apr25; do
  case $c in
    mar25) symbol="XAUUSD.duk_robo_2025"; from="2025.03.01"; to="2025.03.14";;
    jan26) symbol="XAUUSD.duk_robo"; from="2026.01.01"; to="2026.01.14";;
    sep25) symbol="XAUUSD.duk_robo_2025"; from="2025.09.01"; to="2025.09.14";;
    dec25) symbol="XAUUSD.duk_robo_2025"; from="2025.12.01"; to="2025.12.14";;
    apr25) symbol="XAUUSD.duk_robo_2025"; from="2025.04.01"; to="2025.04.14";;
  esac
  run "OPT2-5k-${c}-2wk" "$symbol" "$from" "$to" \
    --input-override BlockDOnAdverseMMD=true
done

# Option 3: ScenarioE with UseMMDAdverseGateForE
for c in mar25 jan26 sep25 dec25 apr25; do
  case $c in
    mar25) symbol="XAUUSD.duk_robo_2025"; from="2025.03.01"; to="2025.03.14";;
    jan26) symbol="XAUUSD.duk_robo"; from="2026.01.01"; to="2026.01.14";;
    sep25) symbol="XAUUSD.duk_robo_2025"; from="2025.09.01"; to="2025.09.14";;
    dec25) symbol="XAUUSD.duk_robo_2025"; from="2025.12.01"; to="2025.12.14";;
    apr25) symbol="XAUUSD.duk_robo_2025"; from="2025.04.01"; to="2025.04.14";;
  esac
  run "OPT3-5k-${c}-2wk" "$symbol" "$from" "$to" \
    --input-override ScenarioE=true \
    --input-override UseMMDAdverseGateForE=true \
    --input-override HedgeRatio=0.35 \
    --input-override RunnerBE_StartPts=120 \
    --input-override RunnerTrailDistPts=200 \
    --input-override RunnerTrailStepPts=50 \
    --input-override SiphonPct=0.9
done

echo "===== 3-options sample test done ====="
