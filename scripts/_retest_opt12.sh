#!/bin/bash
set +e
SET_FILE="C:\Users\nikof\Documents\GitHub\MoneyDancer\# GOLD cap 5k dd 4100 - hard scal, mix time, range burst zone.set"
EXPERT="MoneyDancer_2.0\MoneyDancer_2.0.ex5"

run() {
  local run_id="$1"; local symbol="$2"; local from="$3"; local to="$4"; shift 4
  echo "===== ${run_id} ====="
  python scripts/f0_runner.py \
    --set-file "$SET_FILE" --run-id "$run_id" --symbol "$symbol" \
    --from-date "$from" --to-date "$to" --deposit 5000 --expert "$EXPERT" \
    --input-override MaxSpreadPts=100 --input-override MaxBasketLossPct=8.0 \
    --input-override MaxBasketSLPerDay=2 --input-override MaxAllTimeDDPct=40.0 \
    --input-override RegimeMode=2 --input-override RegimeTimeframe=15 \
    --input-override UseMMDClassifier=true --input-override RegimeTrendMode=1 \
    --input-override FridayFlattenHour=20 --input-override LotsBasePerThousand=0.002 \
    "$@"
}

# Option 1 retry with gentler thresholds (8/10/6 instead of 8/12/4)
for c in mar25 jan26 sep25 dec25 apr25; do
  case $c in
    mar25) sym="XAUUSD.duk_robo_2025"; from="2025.03.01"; to="2025.03.14";;
    jan26) sym="XAUUSD.duk_robo"; from="2026.01.01"; to="2026.01.14";;
    sep25) sym="XAUUSD.duk_robo_2025"; from="2025.09.01"; to="2025.09.14";;
    dec25) sym="XAUUSD.duk_robo_2025"; from="2025.12.01"; to="2025.12.14";;
    apr25) sym="XAUUSD.duk_robo_2025"; from="2025.04.01"; to="2025.04.14";;
  esac
  run "OPT1B-5k-${c}-2wk" "$sym" "$from" "$to" \
    --input-override MaxBasketLossPctRange=8.0 \
    --input-override MaxBasketLossPctTrendWith=10.0 \
    --input-override MaxBasketLossPctTrendAgainst=6.0
done

# Option 2 (now properly wired in ScenarioD path)
for c in mar25 jan26 sep25 dec25 apr25; do
  case $c in
    mar25) sym="XAUUSD.duk_robo_2025"; from="2025.03.01"; to="2025.03.14";;
    jan26) sym="XAUUSD.duk_robo"; from="2026.01.01"; to="2026.01.14";;
    sep25) sym="XAUUSD.duk_robo_2025"; from="2025.09.01"; to="2025.09.14";;
    dec25) sym="XAUUSD.duk_robo_2025"; from="2025.12.01"; to="2025.12.14";;
    apr25) sym="XAUUSD.duk_robo_2025"; from="2025.04.01"; to="2025.04.14";;
  esac
  run "OPT2B-5k-${c}-2wk" "$sym" "$from" "$to" \
    --input-override BlockDOnAdverseMMD=true
done

echo "===== retest done ====="
