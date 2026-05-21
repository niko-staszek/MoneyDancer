# 2026-05-19 — Iteration round 3 (final): adaptive params closed

## Goal of this round

Push backtest past WT's +63.8%/cell to give more headroom against live decay toward cent $50M/year target. Started by user push: "investigate, plan, test."

## What was added to plan + code

### Plan (S2.A sub-stories)
- S2.A.0 framework foundations
- S2.A.1 adaptive MinMove (shipped, defaulted OFF)
- S2.A.2 ATR-floor entry gate (DROPPED after discovery)
- S2.A.3 regime-aware lot scaling (NEW)
- S2.A.4 combined sweep (decision point)
- S2.A.5+ other adaptive params (deferred)
- S2.A.6 (added mid-round) discriminator investigation

### Code (mt5/2.0/MoneyDancer_2.0/)
- `Include/Inputs.mqh`: added `MinATRPointsForEntry`, `LotMultRange`, `LotMultTrend`
- `Include/Utils.mqh`: added `CurrentATRPoints()`, `ATRGateBlocks()`, regime-aware multiplier in `ComputeBaseLot()`
- `Include/Signal.mqh`: wired `ATRGateBlocks()` into `HandleSignal`
- All inputs default to OFF / 1.0 — WT ship behavior unchanged

## Discoveries (in order)

### 1. ATR doesn't discriminate (S2.A.2 dropped)
- `scripts/_compute_atr_per_cell.py`: M15 ATR per cell
- jan25 LOWEST ATR (301) → +32.8% (good)
- jan26 HIGH ATR (821) → +0.6% (worst)
- mar25/jul25 (weak) have ATR identical to feb25 (good)
- No reasonable ATR floor catches weak cells without also catching good ones

### 2. Burst frequency / tick density / follow-through also don't discriminate
- `scripts/_burst_freq_per_cell.py`: simulated EA's tick-burst detector against Duka ticks
- **Jan26 vs Dec25 — nearly identical inputs, opposite outputs**:
  - jan26: 122 bursts/hr, 80% follow-through, mean_move 37 → **+0.6%**
  - dec25: 140 bursts/hr, 77% follow-through, mean_move 36 → **+191%**
- Same market activity in aggregate, 300× different performance

### 3. Performance variance is path-dependent, not aggregate-feature-dependent
- No "gate on market condition X" filter can work
- Variance comes from *when* bursts happen relative to existing basket state, MMD transitions, news timing, day-pause counter state
- These are per-basket-path features, not measurable in cell summaries

### 4. S2.A.3 (regime-aware lot, LotMultTrend=0.5)
- Full 17-month sweep: net **-8.3% profit** vs WT ($49,686 vs $54,219 total)
- 11 cells identical (MMD never said trend → no effect)
- 1 big loss (apr25 +177 → +87, -90pp) — scaling lot to 0.5 throttled a winning trend
- 2 small wins (apr26 +11pp / DD -8pp, may26 marginal)
- 4 marginal movements
- Net: not justifiable

## Conclusion

**WT remains the ship.**

All round-3 attempts to push past WT's backtest performance failed:
- Static MM30/40 → broke monsters
- Adaptive MinMove (INVERSE/LINEAR) → broke marginal cells
- ATR floor → ATR doesn't discriminate
- Regime-aware lot scaling → net -8%

The investigation has reached the empirical ceiling for **backtest-only iteration on the existing strategy architecture**. To push further requires either:
- Per-basket-path-aware logic (complex code, new architecture)
- Different strategy mechanics (not parameter tweaks)
- Live data feedback (cent forward test reveals path-dependent failure modes)

## What's actually in the EA now

Code-wise, the 2.0 EA gained 3 adaptive params from this round (all default OFF):
- `MinMoveAdaptiveMode` + 5 supporting inputs (S2.A.1)
- `MinATRPointsForEntry` (S2.A.2, kept in code for future experiments even though dropped from plan)
- `LotMultRange` + `LotMultTrend` (S2.A.3, kept in code even though not net-positive)
- `PyramidFixedTPPts` (from round 1)

These give future iterations a framework to build on. None are active in the ship config.

## Recommendation

**Stop backtest-iterating. The next signal must come from live trading.**

Priority sequence:
1. **Open cent forward test** (RoboForex Pro-Cent demo, $1k → cent $100k). Deploy WT 2.0 .set. Monitor 30-60 days.
2. **S5.5e cent-account validation** (per S5.5 plan section) — first cent week is the proof point.
3. **Analyze live trade data** to identify the dominant path-dependent failure mode in the wild.
4. **Only then** decide whether further adaptive expansion is worth doing.

## Files

- Iteration runs: `runs/MMA-INV-5k-*`, `runs/MMA-CONS-5k-*`, `runs/MM40-5k-*`, `runs/S2A3-5k-*`
- Analysis scripts: `scripts/_compute_atr_per_cell.py`, `scripts/_burst_freq_per_cell.py`, `scripts/_per_cell_mechanism.py`
- Decision docs:
  - `runs/decisions/2026-05-18-iteration-round-1.md` (WTP/WT5/WTDP)
  - `runs/decisions/2026-05-18-investigation-vol-quality.md` (initial PF/win-rate finding)
  - `runs/decisions/2026-05-19-iteration-round-2.md` (MinMove static + adaptive)
  - `runs/decisions/2026-05-19-discriminator-search.md` (burst-freq investigation, no discriminator found)
  - `runs/decisions/2026-05-19-iteration-round-3-final.md` (this doc)
