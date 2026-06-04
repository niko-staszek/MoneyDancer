# Multi-cell robustness + ATR/MMD probe — STATIC DEAD, no clean scaling law

## Multi-cell maximin (8 cands x 5 cells, multicell_opt.py)
ROBUST configs (worst-cell >=1.5%/day AND profitable on all 5 cells): **NONE -> path-dependence confirmed.**
Every config worst-cell %/day negative (-0.97 to -3.05); max DD 23-37%.
Per-cell optimal LotMultiplier SHIFTS: mar25->1.5(gentle), mar26->2.0, may26->2.5(aggr), sep25->any(all win),
jun25->NONE(all lose). (Numbers traceable to runs/MC-*/trades.csv.)

## ATR/ADX probe vs optimal LotMult (5 cells)
 cell   bestLotMult  ATR(H1)  ATR%   ADX   netMove%
 mar25  1.5 gentle   7.80    0.266  28.7  +5.60
 sep25  any          9.52    0.264  31.2  +5.69
 jun25  none(lose)  10.95    0.325  26.5  +1.87
 mar26  2.0         30.14    0.588  30.3 -10.21
 may26  2.5 aggr    19.21    0.412  27.7  +1.66

## Verdict
- Whisper of signal (low-vol mar25 -> gentle; higher-vol 2026 -> aggressive) BUT inverted
  (mar26 highest ATR% wants 2.0, may26 lower wants 2.5). ATR alone does NOT order optimal LotMult. ADX flat/useless.
- jun25 LOSES on every config yet ATR/ADX/move look ordinary -> NO feature flags the killer cells.
  = discriminator-search wall (Nth confirmation): no aggregate feature predicts grid survival.
- Adaptive SCALING cannot save unwinnable cells (jun25); only a sit-out signal could, and indicators don't see it.
- n=5 sniff; preview discouraging. 70-week regression = likely marginal/noisy = attempt #8 at a mapping that failed 7x.

## DECISION (2026-06): STOP backtesting. Forward-test STEP on live demo ticks (deploy/STEP-forward-test-kit.md).
Only unseen ticks can tell if STEP is real vs curve-fit. Param hunt exhausted.
