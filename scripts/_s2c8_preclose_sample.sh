#!/bin/bash
# S2.C.8 Daily pre-close flatten — sample test on 6 priority cells.
# DailyPreCloseHour=23, DailyPreCloseMinute=55, DailyResumeHour=1
#
# Priority cells:
#   may25-H2: THE motivating case (40.48% DD breach previously).
#   dec25-H1, apr26-H1: monster cells — check whether we lose overnight winnings.
#   feb25-H1: STEP's only negative cell (-17.8%) — does pre-close help?
#   mar25-H1: weak cell.
#   jan26-H1: weak/marginal cell.
#
# Decision rule:
#   - may25-H2 DD < 35% (vs 40.48% baseline) = success on motivating case
#   - At least 4/6 cells show no regression > 30pp
#   - No cell DD exceeds 40% (S1.6 ceiling)
# If all green, proceed to full 17-cell sweep.
set +e
SET_FILE="C:\Users\nikof\Documents\GitHub\MoneyDancer\# GOLD cap 5k dd 4100 - hard scal, mix time, range burst zone.set"
EXPERT="MoneyDancer_2.0\MoneyDancer_2.0.ex5"

run() {
  local run_id="$1"; local symbol="$2"; local from="$3"; local to="$4"
  echo "===== ${run_id} ====="
  python scripts/f0_runner.py \
    --set-file "$SET_FILE" --run-id "$run_id" --symbol "$symbol" \
    --from-date "$from" --to-date "$to" --deposit 5000 --expert "$EXPERT" \
    --input-override MaxSpreadPts=100 --input-override MaxBasketLossPct=8.0 \
    --input-override MaxBasketSLPerDay=2 --input-override MaxAllTimeDDPct=40.0 \
    --input-override RegimeMode=2 --input-override RegimeTimeframe=15 \
    --input-override UseMMDClassifier=true --input-override RegimeTrendMode=1 \
    --input-override FridayFlattenHour=20 --input-override LotsBasePerThousand=0.002 \
    --input-override StepPoints=80 --input-override MinOrderDistancePts=60 \
    --input-override DailyPreCloseHour=22 --input-override DailyPreCloseMinute=0 \
    --input-override DailyResumeHour=1
}

# Sample of 6 priority cells
run "PRECLOSE22-5k-may25-H2" "XAUUSD.duk_robo_2025" "2025.05.15" "2025.05.30"
run "PRECLOSE22-5k-dec25-H1" "XAUUSD.duk_robo_2025" "2025.12.01" "2025.12.14"
run "PRECLOSE22-5k-apr26-H1" "XAUUSD.duk_robo"      "2026.04.01" "2026.04.14"
run "PRECLOSE22-5k-feb25-H1" "XAUUSD.duk_robo_2025" "2025.02.01" "2025.02.14"
run "PRECLOSE22-5k-mar25-H1" "XAUUSD.duk_robo_2025" "2025.03.01" "2025.03.14"
run "PRECLOSE22-5k-jan26-H1" "XAUUSD.duk_robo"      "2026.01.01" "2026.01.14"

echo "===== S2.C.8 sample done ====="
