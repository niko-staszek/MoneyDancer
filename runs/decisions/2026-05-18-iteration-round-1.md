# 2026-05-18 — Iteration round 1: WT vs variants

**Goal**: push toward sustained cent $50M/year (= 2.5%/day live, sustained).
**Starting point**: WT (with-trend grid) shipped 2026-05-18 with 17/17 positive cells, mean +63.8%/cell, +6.38%/day backtest.
**User push**: review code + iterate strategy/config until trajectory hits cent $50M comfortably.

## What I tested

| Variant | Description | Change vs WT |
|---|---|---|
| **WTP** | Static Pyramid always on | Set `PyramRange=4` always; legacy BUILDING/COASTING TPs |
| **WT5** | Tighter basket SL | `MaxBasketLossPct: 8 → 5` |
| **WTDP** | Dynamic Pyramid via PyramidFixedTPPts | New input `PyramidFixedTPPts=150`; per-position fixed TP |

## Results vs WT (17 cells unless noted)

### WTP — FAILED on first test
- Mar25 -8.7% (vs WT +3.3%)
- Feb26 **tester timeout** — pyramid accumulated positions during sustained trend, never coasted out
- Aborted. Confirmed Pyramid's slope-COAST exit doesn't work in 2-week sustained trends.

### WT5 — Mixed full sweep
| Stat | WT | WT5 | Delta |
|---|---|---|---|
| Cells positive | 17/17 | 14/17 | −3 |
| Mean / cell | +63.8% | +37.5% | **−26.3pp** |
| Median | +45.9% | +29.8% | −16.1pp |
| Worst cell | +0.6% | -9.4% | −10pp |
| Max DD | 37.1% | 31.8% | −5.3pp |
| Daily-avg | +6.38% | +3.75% | -2.6pp |
| Total $ (17×$5k) | $54.2k | $31.9k | -41% |
| Risk-adj (mean/DD) | 1.72 | 1.18 | -31% |

WT5 trades 41% of return for 5pp lower max-DD. Big-winner cells (apr25 +177→30, dec25 +191→103, apr26 +185→97) lose most because basket-SL fires on winning baskets that would have eventually TP'd. Three cells turn negative (Jan25, Jun25, Aug25). **Net worse on every metric except max-DD.**

Mar26 was a striking exception: +60% → **+127%** (DD 21.8 → 7.4). For this specific cell, tighter SL prevented the basket from growing too large during a strong-trend month with deep pullbacks. But the gain on this one cell didn't compensate for the broader losses.

### WTDP — Mixed on 5-cell test (Pyramid + WT + fixed TP)
| Cell | WT | WTDP |
|---|---|---|
| mar25 | +3.3 / 25.1 | **+46.7 / 18.3** ← recovers to S17 level |
| mar26 | +59.6 / 21.8 | +64.3 / 17.0 |
| feb26 | +45.9 / 16.0 | +55.6 / 19.2 |
| sep25 | +65.7 / 27.0 | +48.5 / 25.8 ← worse |
| dec25 | +191.0 / 12.2 | **+71.5 / 40.2** ← DD breach! |

Pyramid + fixed-TP recovers mar25 dramatically. But on a strongly-trending month like dec25, pyramid positions accumulate (one per signal, each with a fixed TP), and even at TP=150pts each, the basket of in-flight pyramid positions hits DD 40% before they all clear. Plus the per-trade profit is lower than the grid-grinding WT does in those months.

**Skipped full WTDP sweep** because the dec25 DD breach makes this ineligible — would need to refine the slope threshold or fixed-TP value first.

## Key learnings

1. **WT is the local optimum.** Several promising-sounding tweaks (tighter SL, dynamic pyramid) actually hurt overall. The "two failure modes" diagnosis (mar25/mar26 trade-and-fail vs feb26 low-trend-TP) turned out to need *different* fixes — but you can't pick one fix that doesn't break another month.

2. **Basket SL is more nuanced than it looks.** 8% basket-SL is right because most basket DDs eventually recover via TP. Tightening to 5% cuts losses *and* cuts winning baskets that would have recovered. The empirical sweet spot here is 8%.

3. **Pyramid is fundamentally trend-following.** It needs trend to *end* to exit cleanly. In sustained 2-week trends (which is most of the high-return cells), pyramid positions accumulate. PyramidFixedTPPts mitigates this but introduces a new failure: when trend continues past TP, you're done with that pyramid, but the EA opens new pyramids, stacking exposure across non-coordinated positions.

4. **Sept 25's WT recovery was real and validates the WT framing.** Sep 25 went from -19.8% (S17) to +65.7% (WT) — the strategy participates in the strong trend instead of sitting out. This is the headline finding from the original WT validation and it survives all variants tested. No variant turns this into a loser.

5. **The 3 regression months (Mar25, Feb26, Mar26) under WT are real but bounded.** All still positive under WT (+3.3%, +45.9%, +59.6%). No variant uniformly improves them; each tested variant makes some *other* months worse to fix these.

## What's next

WT remains the ship config. No further single-input changes worth testing for now.

The real next leverage points (per plan):
1. **Cent forward test** (Sprint 7.2 reframed). Validate WT under real broker conditions. 60-90 day target. If live realizes ≥ 2.5%/day, cent $50M/year is on track.
2. **S2.A adaptive parameters**. The basket-SL "right answer" probably isn't 5% OR 8% — it's *cell-specific* (or volatility-specific). ATR-scaled basket-SL threshold, ATR-scaled PriceStep, spread-quantile MaxSpreadPts. Likely 1-2 weeks of work. Could push backtest from +6.38%/day to +8-10%/day.
3. **News-event safety classification** (open project memory). Per-event P&L on the 33k-deal master CSV. Would let UseNewsBlackout flip back on selectively for specific safe-to-block events.
4. **S3.2c proper** (Pyramid-only via new RegimeTrendMode=2). Cleaner than the PyramidFixedTPPts hack. Would close the WT regression cells if the slope-threshold is tuned right. ~1 week of work.

## Files

- Run folders: `runs/WTP-5k-*`, `runs/WT5-5k-*`, `runs/WTDP-5k-*`
- Code change: `mt5/2.0/MoneyDancer_2.0/Include/Inputs.mqh` + `Pyramid.mqh` — new input `PyramidFixedTPPts` (default 0 = legacy)
- Ship config unchanged: `mt5/2.0/MoneyDancer_2.0/presets/XAUUSD_2.0_S17_ship.set` (still WT, `RegimeTrendMode=1`)
