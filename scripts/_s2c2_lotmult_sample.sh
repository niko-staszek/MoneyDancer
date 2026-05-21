#!/bin/bash
# S2.C.2 — lotMultiplier sensitivity sample test.
# 5 critical cells × 2 multipliers (2.5, 3.0) = 10 runs.
# Acceptance per C.2.4: mean (5-cell) >= WT mean, max single-cell drop <= 30pp, max DD <= 37.1%.
set +e
SET_FILE="C:\\Users\\nikof\\Documents\\GitHub\\MoneyDancer\\# GOLD cap 5k dd 4100 - hard scal, mix time, range burst zone.set"
EXPERT="MoneyDancer_2.0\\MoneyDancer_2.0.ex5"

run() {
  local run_id="$1"; local symbol="$2"; local from="$3"; local to="$4"; local mult="$5"
  echo "===== ${run_id} (lotMult=${mult}) ====="
  python scripts/f0_runner.py \
    --set-file "$SET_FILE" --run-id "$run_id" --symbol "$symbol" \
    --from-date "$from" --to-date "$to" --deposit 5000 --expert "$EXPERT" \
    --input-override MaxSpreadPts=100 --input-override MaxBasketLossPct=8.0 \
    --input-override MaxBasketSLPerDay=2 --input-override MaxAllTimeDDPct=40.0 \
    --input-override RegimeMode=2 --input-override RegimeTimeframe=15 \
    --input-override UseMMDClassifier=true --input-override RegimeTrendMode=1 \
    --input-override FridayFlattenHour=20 --input-override LotsBasePerThousand=0.002 \
    --input-override lotMultiplier="$mult"
}

# 5 critical cells x 2 multipliers
for mult in 2.5 3.0; do
  for c in mar25 jan26 sep25 dec25 apr25; do
    case $c in
      mar25) sym="XAUUSD.duk_robo_2025"; from="2025.03.01"; to="2025.03.14";;
      jan26) sym="XAUUSD.duk_robo"; from="2026.01.01"; to="2026.01.14";;
      sep25) sym="XAUUSD.duk_robo_2025"; from="2025.09.01"; to="2025.09.14";;
      dec25) sym="XAUUSD.duk_robo_2025"; from="2025.12.01"; to="2025.12.14";;
      apr25) sym="XAUUSD.duk_robo_2025"; from="2025.04.01"; to="2025.04.14";;
    esac
    # Run id uses underscore to avoid dot confusion in tester reports
    mult_clean=${mult//./}  # 2.5 -> 25, 3.0 -> 30
    run "LM${mult_clean}-5k-${c}-2wk" "$sym" "$from" "$to" "$mult"
  done
done

echo "===== S2.C.2 sample done ====="
