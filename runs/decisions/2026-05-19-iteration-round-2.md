# 2026-05-19 — Iteration round 2: investigation, adaptive MinMove, diminishing returns

## What was investigated

Continued from user's "back to drawing board" directive. Goal: push backtest higher to give live decay more headroom toward cent $50M/year target.

## What I learned

### Per-cell mechanism breakdown (the real finding)

Built `scripts/_per_cell_mechanism.py`. Ran on all 17 WT cells. Two distinct groups emerged:

| | Trades/day | Avg hold | Win rate | PF |
|---|---|---|---|---|
| **Top 5 (monsters)** | 485 | 2.7 min | 71% | 1.45–1.60 |
| **Bottom 5 (weak)** | 212 | 7.1 min | 70% | **1.01–1.07** |

**Win rate is IDENTICAL** across both groups. Differentiator is PF. That means the strategy correctly identifies winning bursts (same 70% hit rate everywhere). What differs is **per-trade profit relative to spread**: in low-vol cells the wins are tiny → PF crashes toward 1.0.

This is a strong signal that the lever to pull is the **entry quality filter** (`MinMovePoints`), not exit logic or basket management. Static value can't be right universally because volatility differs by cell.

### MinMove iterations tested

| Config | Where it helped | Where it broke |
|---|---|---|
| Static MM40 | Jan26 +0.6→+92.4% (huge) | Dec25 -78pp, Apr26 -102pp, Feb26 timeout |
| Static MM30 (not tested standalone) | — | — |
| Static MM_TP_combo (TP=100 + MM=35) | — | -4.9% on Jan26 |
| Adaptive INVERSE (C=1500, Max=80) | Jan26 +99%, Dec25 +209%, Apr26 +209% | mar25 -25% / DD 40%, sep25 +66→+16, mar26 small loss |
| Adaptive INVERSE (C=1000, Max=50) | Identical to C=1500 — both formulas hit clamp boundaries with these ATR ranges |

### Why adaptive INVERSE doesn't fully work

The current formula `MinMove = clamp(C / ATR_pts, Min, Max)`:
- High vol (ATR > 75 pts): hits Min=20 floor (lots of entries — overshoots range months that *also* have high vol)
- Low vol (ATR < 30 pts): hits Max=80 ceiling (very few entries — destroys cells like mar25 where some baskets still need to open to recover)
- Middle vol (30-50): linear range works

So the formula's binary "trend on / off" doesn't capture the nuance. mar25 with very low ATR gets MinMove=80, only ~50 entries/day, the few that DO fire get basket-SL'd → net negative. Conservative (C=1000, Max=50) gave identical results because mar25's ATR is so low that even the conservative formula hits the Max clamp.

## Honest read

**WT is the ceiling for one-knob-at-a-time iteration.** Each new lever I pull breaks somewhere else:
- Tighter SL: helps mar26, hurts winners
- Static MM40: helps Jan26, breaks monsters
- Adaptive INVERSE: helps extremes, breaks marginal cells
- Pyramid (WTP/WTDP): helps some, breaks others

The shape of the optimal solution would need to be multi-dimensional:
- ATR-scaled MinMove (with a more nuanced function than INVERSE clamps)
- Regime-aware lot scaling (which is in S5.5c)
- Per-regime-mode TP/SL ratios
- Multiple regime classifiers cross-referenced

That's not a quick iteration — it's S2.A framework expansion plus serious calibration work. ~2-4 weeks of focused effort.

## What got shipped from this round

Code change in 2.0 EA (in `mt5/2.0/MoneyDancer_2.0/`):

- `Include/Inputs.mqh`: new `ENUM_MINMOVE_MODE` (FIXED/ATR_INVERSE/ATR_LINEAR) + 5 new inputs (ATRTimeframe, ATRPeriod, ATRConstant, ATRMult, Min, Max). **Default = MM_FIXED** so the WT ship config is unaffected.
- `Include/Utils.mqh`: new `EffectiveMinMovePoints()` function caches ATR per-bar and computes the adaptive value when mode != FIXED.
- `Include/Signal.mqh`: replaced direct `MinMovePoints` references with `EffectiveMinMovePoints()` calls.

This is the **first slice of the S2.A adaptive parameter framework**. Same pattern can be applied to `MaxSpreadPts` (spread quantile), `PriceStep` (ATR-scaled), `bePoints` (ATR-scaled), `lotMultiplier` (regime-aware) — each needs its own calibration.

Compiles 0/0 warnings. WT ship .set unchanged (no adaptive inputs set → defaults to FIXED behavior).

## Next-iteration recommendations

1. **Stop backtest-iterating.** We've hit diminishing returns. The next signal must come from live trading — even paper-cent demo. Backtest fitting beyond this point is the start of overfitting territory.

2. **Open cent-account demo NOW.** Deploy WT 2.0 .set, log daily P&L vs the backtest expectation. 30-60 days. This will tell us:
   - Whether live decay is 30%, 50%, or 70% of backtest (critical for $50M math)
   - Whether the WT regression cells (mar25-ish patterns) ever recur in live
   - Whether any unmodeled cost (swap, slippage, requote) is materially eating profit

3. **Skip the adaptive-param tuning iteration until cent confirms live behavior.** If live realizes 3%/day cleanly, WT is sufficient — adaptive scaling is gilding. If live underperforms badly, the cent forward test will reveal *what* underperforms, which is far more useful than guessing.

4. **S5.5a (recovery-add lot bug) is the only cheap fix worth shipping pre-cent.** One-line change. Validate on one cell, then ship.

5. **Park S2.A adaptive expansion as a Sprint 2 backlog item.** The framework slice is in place; calibration is open. Revisit after cent forward data.

## Files

- Iteration runs: `runs/MM40-5k-*`, `runs/MMA-INV-5k-*`, `runs/MMA-CONS-5k-*`, `runs/FILT-*`, `runs/WT5-5k-*`, `runs/WTP-5k-*`, `runs/WTDP-5k-*`
- Mechanism analysis: `scripts/_per_cell_mechanism.py`
- Investigation memo: `runs/decisions/2026-05-18-investigation-vol-quality.md`
- Previous round: `runs/decisions/2026-05-18-iteration-round-1.md`
