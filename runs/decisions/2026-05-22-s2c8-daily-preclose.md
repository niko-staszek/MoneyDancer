# S2.C.8 Daily pre-close flatten — decision memo

**Date**: 2026-05-22
**Story**: S2.C.8 (path 2 — code investigation)
**Outcome**: investigated, NOT shipped (H1 win was OOS overfit)
**Status**: closed; STEP stays ship

## Motivation

may25-H2 (OOS validation cell) had 40.48% equity DD — breaches the 40% S1.6
ceiling. S5.5f scan showed the mechanism: basket-SL rail spins 22,000+ times
during the ~30-min XAU daily-break window (~00:00-01:00 UTC) where the
broker returns "Market closed" on every close attempt. S5.5f fixed the
*symptom* (rail no longer spams logs); S2.C.8 attempted to prevent the
*cause* by closing baskets BEFORE the daily-break window starts.

## Code changes

Three new inputs (default OFF — STEP behavior preserved):

- `DailyPreCloseHour` (recommend 22)
- `DailyPreCloseMinute` (recommend 0)
- `DailyResumeHour` (recommend 1)
- `DailyPreCloseLossThresholdPct` (default 0.0 = unconditional; tested 1.0/4.0/6.0)

New `EnforceDailyPreClose()` in Risk.mqh, wired in OnTick after Friday flatten.
Supports both unconditional (close everything) and conditional (close only
losing baskets meeting threshold). Per-direction independent close via
`BasketFloatingPL(dir,false)` + `CloseSeriesBasketPositions_S10(dir,skey)`.
Compiles clean (0/0). Commit `17150ff` (initial) and `ffa55ad` (conditional).

## Experimental progression (6 rounds)

| Round | Variant | may25-H2 DD | dec25 H1 | apr26 H1 | Outcome |
|---|---|---|---|---|---|
| 1 | uncond, cutoff 23:55 | 40.48% (no change) | – | – | flatten itself rejected (inside closed window) |
| 2 | uncond, cutoff 22:00 | **19.2%** ✓ | +229 (-77pp) | +102 (-156pp) | DD fixed, monsters -156pp |
| 3 | cond≥1%, cutoff 22:00 | 19.9% | +181 (-125pp) | +102 | worse than R2 — monsters dip <1% mid-build |
| 4 | cond≥4%, cutoff 22:00 | 25.4% | +320 (+15pp) | +122 (-136pp) | dec25 improved, apr26 still hurts |
| **5** | **cond≥6%, cutoff 22:00 (sample 4 cells)** | **26.7%** ✓ | **+315 (+9pp)** | **+258 (-0pp)** | **all 4 cells improved/unchanged** |
| 5b | Full H1 17-cell sweep at cond≥6% | n/a | (H1) +315 | (H1) +258 | **+$3,924 vs STEP, gate technically passes** |
| 5c | H2 OOS 15-cell sweep at cond≥6% | **+132% @ 26.7%** ✓ | (H2) +62 (=) | (H2) +226 (=) | **-$9,986 vs STEP** — mar26-H2 alone -$2,715 |

## Final numbers

| | STEP H1 | PC H1 | STEP H2 | PC H2 | Combined |
|---|---|---|---|---|---|
| Total | $82,110 | $86,034 | $66,346 | $56,360 | STEP $148,456 vs PC $142,394 |
| Cells positive | 16/17 | 16/17 | 13/15 | 11/15 | – |
| Max DD | 37.79% | 38.14% | 40.48% | 26.7% (may25-H2) | – |
| Delta | – | **+$3,924** | – | **-$9,986** | **PC -$6,062** |

H1 win was overfit to first-half-of-month basket dynamics. H2 OOS exposed
the failure mode: mar26-H2 lost 54.3pp because flatten cut off baskets that
would have recovered into monster TPs overnight. Same -6% threshold that
worked perfectly on mar26-H1 (no flatten fire) catastrophically fails on
mar26-H2 (multiple flatten fires).

## Lesson learned (added to validated facts)

**Static cross-cell loss thresholds don't survive H2 OOS** even at
conservatively conservative settings. The basket-recovery probability at
22:00 server time isn't a stable function of basket-floating-PL — it's
path-dependent (re-confirms round 4 finding). What we'd need is a
per-night, per-symbol "is this basket likely to recover during the daily
break" classifier — which would require regime telemetry and significantly
more research than this single story.

## What stays shipped

- ✓ **S5.5f** (basket-SL rail handles market-closed) — code hygiene win, bit-identical to buggy version on backtest, prevents log spam + provides live broker safety. Stays in STEP_ship.
- ✓ **S2.C.8 inputs in EA defaults OFF** — `DailyPreCloseHour=0`, `DailyPreCloseLossThresholdPct=0.0`. Users who want it can enable. STEP behavior preserved when off.
- ✓ **`XAUUSD_2.0_STEP_PRECLOSE_ship.set` retained as an *opt-in variant*** in `presets/` — documented as "tighter DD at cost of $6k aggregate on 31-cell backtest". For users prioritizing prop-firm DD bound over total profit.

## What gets dropped

- ✗ STEP+PRECLOSE as new ship default
- ✗ Promotion to `XAUUSD_2.0_ship.set` symbolic link

## Where it appears

- Code: `mt5/2.0/MoneyDancer_2.0/Include/Inputs.mqh` (3 inputs), `Include/Risk.mqh` (`EnforceDailyPreClose()`), `MoneyDancer_2.0.mq5` (OnTick wiring)
- Variant .set: `mt5/2.0/MoneyDancer_2.0/presets/XAUUSD_2.0_STEP_PRECLOSE_ship.set`
- Test variant (historical): `mt5/2.0/MoneyDancer_2.0/presets/XAUUSD_2.0_STEP_PRECLOSE_test.set` (round 1 settings, 23:55 cutoff — kept for traceability)
- Scripts: `scripts/_s2c8_preclose_*.sh` (R1, R2, R3, R4, R5 sample scripts + full H1/H2)
- Analysis scripts: `scripts/_summarize_s2c8_*.py`
- Commits: `17150ff` (initial), `82d3e9b` (R1 result + R2 retry), `ffa55ad` (R5 win + full sweep), this commit (H2 closure)

## Next

Move to S2.C.4 — Martingale shape sample (startBe=3, MaxOrdersDir=30).
This was designed in plan but never run.
