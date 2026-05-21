# 2026-05-19 — Discriminator search: what separates weak from monster cells

## Question

WT delivers 17/17 positive cells but with huge variance: mean +63.8%, range +0.6% to +191%. What market feature predicts which cells will be monsters vs weak?

If we could identify the feature, we could gate trading (only run when feature is favorable) or scale parameters (more aggressive when favorable, conservative when not).

## Features measured per cell

For each of 17 WT cells (Jan 2025 → May 2026, 2-week windows), computed:

### From per-cell mechanism (existing data)
- Win rate
- Trades per day
- Avg holding time
- Profit factor
- Basket-SL fires

### From `scripts/_compute_atr_per_cell.py` (new)
- M15 ATR (mean, p10/p25/p50/p75, min, max)

### From `scripts/_burst_freq_per_cell.py` (new)
- Ticks per minute
- Bursts per hour (simulating EA's tick-burst detector: 14 ticks, 11s window, ≥25pts move, 15s cooldown)
- Mean burst move size
- Follow-through % (bursts where price hit ≥TP_Points within 5 min)

## Result

**None of the aggregate features cleanly predicts WT performance.**

Examples that break each hypothesis:

| Feature | Hypothesis | Counterexample |
|---|---|---|
| ATR low → weak | "Strategy needs vol" | jan25 lowest ATR (301) → +32.8% (good); jan26 high ATR (821) → +0.6% (worst) |
| Trade count low → weak | "Need throughput" | Already a symptom, not a cause |
| Burst frequency low → weak | "Need bursts" | jan26 has 122 bursts/hr (similar to monsters) → +0.6% |
| Follow-through % low → weak | "Bursts need momentum" | jan26 follow% is 80% (high) → +0.6% |
| Mean burst move small → weak | "Spread eats small TPs" | jan25 mean_move 30 → +32.8% (good); apr26 mean_move 48 → +185% — but mar26 also 52 → only +60% |

## Most striking case

**Jan26 vs Dec25** — nearly identical input features, opposite outcomes:

| Feature | jan26 (WORST) | dec25 (MONSTER) |
|---|---|---|
| ATR mean | 821 | 679 |
| ticks/min | 176 | 198 |
| bursts/hour | 122 | 140 |
| follow-through % | 80% | 77% |
| mean burst move | 37 | 36 |
| **WT net %** | **+0.6%** | **+191%** |

Jan26 actually has slightly **better** burst characteristics than Dec25 on most metrics. Yet WT performs 300× worse on jan26.

## Interpretation

The variance is **path-dependent**, not aggregate-feature dependent. Same burst stream → different outcomes based on *when* bursts happen relative to:
- Existing open basket state
- MMD regime transitions
- Recent basket-SL fires (day-pause logic)
- News-event timing (when entries get caught at adverse fills)
- Friday end-of-week proximity

These are *per-basket-path* features, not measurable in cell-summary statistics.

## What this means for the strategy

1. **No simple "gate when conditions are unfavorable" filter will work.** We've checked the obvious aggregate features.

2. **WT is close to the local optimum for this strategy architecture.** The 5 negative cells under S17 became 0 under WT. The remaining variance under WT (+0.6% to +191%) is what's left after the survival rails + regime gate have done their job.

3. **Further backtest-only iteration has diminishing returns.** Each new variant we test (WT5, WTP, WTDP, MM40, MM-adaptive INVERSE, ATR floor, lot scaling) either wins some cells while losing others, or doesn't move the needle.

4. **The next genuine improvement requires either:**
   - **Online basket-state-aware logic** (much more complex code than what we have)
   - **Different strategy architecture** (different grid mechanics, not parameter tweaks)
   - **Live data** that reveals which failure modes actually occur in production vs which are backtest-specific artifacts

## Recommendation

- Ship WT as-is. It's already validated, 17/17 positive, in target band.
- Open cent forward test as the next concrete step. Live data will tell us which of the path-dependent issues are real and which are backtest curiosities.
- Park S2.A expansion (other adaptive params) until cent live data informs which path-dependencies matter most.
- The S2.A.3 (regime-aware lot) full sweep in flight will provide one last empirical signal — if it shows clear net improvement, we ship that. Otherwise WT stands.

## Files

- ATR analysis: `scripts/_compute_atr_per_cell.py`
- Burst-freq analysis: `scripts/_burst_freq_per_cell.py`
- Per-cell mechanism: `scripts/_per_cell_mechanism.py`
- S2.A.3 full sweep (in flight): bahuosyhk
