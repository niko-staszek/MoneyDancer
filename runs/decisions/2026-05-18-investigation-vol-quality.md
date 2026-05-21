# 2026-05-18 — Investigation: volatility-quality finding

## Method

Built per-cell mechanism breakdown using `scripts/_per_cell_mechanism.py`. For each of the 17 WT cells, computed:
- Trade count (in / out)
- Win rate (sum profitable vs total)
- Sum winners / sum losers / PF
- Average + median holding time per position
- Active days, trades-per-active-day
- Basket-SL fires (from tester log)

## Key data

| Cell category | Trades/day | Avg hold | Win% | PF |
|---|---|---|---|---|
| Top 5 (Dec25, Apr26, Apr25, May26, Nov25) | **485** | 2.7 min | 71% | 1.45–1.60 |
| Bottom 5 (Jul25, Jun25, May25, Mar25, Jan26) | **212** | 7.1 min | 70% | **1.01–1.07** |

Win rate identical across both groups. The strategy enters about the same QUALITY of bursts (same TP-hit ratio); the difference is **volume of bursts available and TP/spread ratio**.

## Hypothesis

In low-volatility regimes:
1. Fewer bursts trip the tick-burst detector → fewer entries
2. The bursts that DO trip the detector have small per-burst movement
3. Small moves → small TPs → barely cover spread + slippage → PF crashes to ~1.0
4. Baskets get stuck waiting for retracement that doesn't come on time → long holding times → low throughput

## Targeted single-cell test (Jan26, worst WT cell, +0.6%)

| Config | Net % | DD % | PF | Trades |
|---|---|---|---|---|
| WT baseline | +0.6% | 33.4% | 0.95 | 1,086 |
| **MinMovePoints=40** | **+92.4%** | **13.0%** | **1.52** | **3,750** |
| TP_Points=100 | +11.8% | 30.7% | 1.09 | 1,567 |
| TP=80 + MinMove=35 | -4.9% | 25.2% | 0.96 | 1,575 |

**MinMovePoints=40 produces a 150× net-profit improvement on the worst cell.** The strategy got *more* selective AND ended up with *more* trade volume — because baskets completed faster (real momentum → real TP hits) and the EA wasn't tied up holding stalled baskets.

## Mechanism interpretation

`MinMovePoints=25` accepts marginal momentum signals. Marginal momentum frequently reverses → basket waits → stuck. `MinMovePoints=40` rejects marginal signals; only real momentum bursts get through → baskets cycle faster → more throughput AND higher quality per trade. Less is more.

## Next test (in flight)

Apply `MinMovePoints=40` to a representative sample:
- 2 monster cells (Dec25, Apr26) — must not regress significantly
- 2 regression cells (Feb26, Mar26) — could help if same low-vol mechanism
- 1 trend cell (Sep25) — must preserve WT's trend recovery
- 1 other weak cell (Mar25) — could be huge win

If sample test wins on most + doesn't break monsters → full 17-month sweep → if confirmed → ship as new default `MinMovePoints=40`.

## Why this matters more than the previous variant attempts

WTP, WT5, WTDP each changed *one rail* (pyramid, SL, pyramid+TP) — each helped some cells while hurting others. They were *behavioral* changes. MinMovePoints=40 changes the *quality threshold for entries* — it should help universally if the hypothesis is right (low-vol cells have low-quality entries that drag PF). The fact that win rate is identical across cells but PF varies wildly is the smoking gun: filter quality is the lever, not exit logic.

If MM40 wins broadly, the next step is making it adaptive: `MinMovePoints = max(base, atr_multiplier × ATR(period))`. That's S2.A territory but with a clear motivation.
