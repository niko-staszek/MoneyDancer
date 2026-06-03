# Detune optimization — SMOKE partial (do not trust as a result)

Snapshot of the MT5 genetic-optimization `.opt` cache, taken mid-run.

- EA: MoneyDancer_2.0 (with OnTester Ulcer-gated criterion)
- Symbol/window: XAUUSD.duk_robo M5, 2026.04.01–2026.04.04 (3-day SMOKE window)
- Sweep: full 10-lever camelCase set (opt_runner SWEEP, commit 0079552)
- Status at snapshot: pass ~1718 of 10,496; ~33h elapsed, ~203h projected (genetic)
- Criterion: OnTester smoothness score (Ulcer-gated, DD<=40% & dailyAvg>=1.5% gates)

WHY KEPT: evidence of the run that proved the 10-lever every-tick genetic sweep is
computationally infeasible (~203h wall for a 3-DAY window; the month-IS would be ~10-30x).
NOT a usable detune result — config is being revised to small batches (fewer levers,
capped LotMultiplier range, shorter window). Open the .opt in MT5 Strategy Tester
(Optimization Results -> right-click -> Load) to inspect the 1718 passes if needed.
