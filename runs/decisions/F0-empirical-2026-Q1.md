---
date: 2026-05-14
story_id: F0
action: empirical
window: 2026-01-01 to 2026-01-31
symbol: XAUUSD
broker: RoboForex-Pro
modeling: every-tick-based-on-real-ticks, 40ms execution delay
evidence_runs:
  - F0-test1.3a-scalper
  - F0-test13a-fastscalper
  - F0-35k-pyramid
  - F0-3k-heavy-pyramid
  - F0-5k-heavy-grid
---

# F0 — Empirical January 2026 runs on user's 5 .set files

> Window reduced from Q1 → January only to keep total batch runtime ≈75 min instead of fighting the modify-spam-driven 5-hour Q1 runtime. Can extend the surviving lane to full Q1 or YTD later.

## Per-run scorecard

| Run | Deposit | Net P/L | Net % | PF | Bal DD% | Eq DD% | Trades | Win% | Max cons loss |
|---|---|---|---|---|---|---|---|---|---|
| F0-test1.3a-scalper | $100,000 | +$13.49 | +0.01% | 1.02 | 0.70 | 0.77 | 477 | 92.0% | 1 |
| F0-test13a-fastscalper | $100,000 | +$425.73 | +0.43% | 1.27 | 0.22 | 0.34 | 1,368 | 77.8% | 6 |
| F0-35k-pyramid | $35,000 | +$1,884.92 | +5.39% | 1.09 | **28.63** | **48.66** ⚠ | 294 | 74.8% | 15 |
| F0-3k-heavy-pyramid | $3,000 | +$421.36 | +14.05% | 1.05 | **30.46** ⚠ | **31.27** ⚠ | 734 | 47.4% | 11 |
| **F0-5k-heavy-grid** | **$5,000** | **+$4,393.24** | **+87.86%** 🥇 | **1.97** | **8.68** ✓ | **11.66** ✓ | **2,619** | **67.4%** | **9** |

**Bolded ⚠** drawdowns exceed our locked 30% ceiling. **Bolded ✓** are under target.

## Compared to the 2.5%/day compounding target

Hitting 2.5%/day compounded over 22 January trading days = **≈70% monthly**. Result:

- TEST 1.3a-scalper: 0.01% monthly → 0.0005%/day (basically flat)
- TEST 13a-fastscalper: 0.43% monthly → ~0.02%/day
- 35k-pyramid: 5.39% monthly → ~0.27%/day
- 3k-heavy-pyramid: 14.05% monthly → ~0.7%/day
- **5k-heavy-grid: 87.86% monthly → ~2.9%/day average — *exceeds* the 2.5% target while keeping equity DD under 12%.**

**The 5k config alone beats the 2.5%/day target in January 2026.** The other four configs are 4×–7000× short. This is a critical finding — we have at least one .set that achieves the target on real January data, with drawdown well inside the 30% ceiling.

**Caveat — single-month sample.** January 2026 had specific characteristics (gold's late-Jan FOMC reaction, range-y prior weeks) that may have favored a fast-reactive grid martingale. The 5k result could be regime-specific. **Must validate across more months before treating as repeatable.**

## Three architecture lanes — what we actually found

The original "tight scalper vs heavy + pyramid" split missed a third lane: **heavy grid WITHOUT pyramid**. That's where the 5k surprise lives.

### Lane A: tight scalper (TEST 1.3a, TEST 13a)
- **Profile**: `PriceStep=0.20` (tight), `bePoints=25–40` (small), `lotMultiplier=1.50` (default), `MaxOrdersDir=15`, per-position SL=7500 catastrophe-only.
- **Verdict**: SAFE — DD <1% in both — but barely profitable. TEST 1.3a essentially flat (+$13 over 477 trades). TEST 13a slightly better at +$425 over 1,368 trades.
- **Bottleneck**: too risk-averse. Strategy never compounds because individual trade size never grows.

### Lane B: heavy grid + pyramid (35k, 3k)
- **Profile**: `PriceStep=0.90` (wide), `bePoints=65–250`, `lotMultiplier=2.0–3.0`, **pyramid ON**, `MaxOrdersDir=20`, per-position SL 0 or 515.
- **Verdict**: Decent net (5–14% monthly) but **DD ceiling violated on every run** — 35k hit 48.66% equity DD, 3k hit 30.46% balance DD. Pyramid amplifies winners but also amplifies losers in a drawn-out basket.
- **Bottleneck**: lacks basket-equity-SL (S1.0). Per-position SL alone is insufficient under high concurrent-position counts.

### Lane C: heavy grid, NO pyramid, 4× martingale (5k) — the surprise winner
- **Profile**: `PriceStep=0.90` (wide), `bePoints=65` (medium), `lotMultiplier=4.0` (very aggressive), `startBe=1` (martingale immediately), `MaxOrdersDir=50` (deep grid allowed), `StartOpenLots=0.10` (10× larger initial), `maPeriod=4` + `slopeLookbackBars=2` (extremely fast slope filter), **`PyramRange=0` (pyramid OFF)**, no per-position SL, no after-hour profit-lock.
- **Verdict**: +87.86% monthly with only 11.66% equity DD. PF 1.97 — strongest of all. 2619 trades, 67% win rate, max 9 consecutive losses.
- **Why this might work**: PURE grid mean-reversion. Fast-reactive slope filter catches small reversals immediately. Wide PriceStep means levels are spaced far enough that 4× martingale doesn't blow up under typical gold volatility. NO pyramid means no extra exposure when trend persists. Basket BE pulls back to profit quickly.
- **Caveats**:
  - Single-month sample. January 2026 may have been unusually friendly to this regime.
  - 4× martingale with deep grid (up to 50 orders) is mathematically a positive-skew bet — works most months, blows up catastrophically on a strong trending month.
  - 5k account with `StartOpenLots=0.10` is using **2% initial position** (0.10 lots × $100/pip = $10/pip; on a 100-point adverse move = $1000 = 20% of equity). Very aggressive sizing that won't scale linearly to 100k (would need 2.0 lots initial).

## Win-rate vs profitability paradox

| Config | Win rate | Net profit | Conclusion |
|---|---|---|---|
| TEST 1.3a | 92.0% | +$13.49 | High WR, low net — too cautious; basket BE returns nothing |
| TEST 13a | 77.8% | +$425.73 | Best balance — good WR with reasonable net |
| 35k | 74.8% | +$1,884.92 | Pyramid amplifies — fewer trades, bigger wins |
| 3k | **47.4%** | +$421.36 | LOSS trades > profit trades, but profit per win > loss per loss — pyramid-driven |

**The 3k config makes money DESPITE losing more trades than it wins** — pyramid on trending moves catches outsized winners. This is the structural truth: when sized correctly, heavy-grid + pyramid is a positive-skew strategy. When sized wrong (no basket SL, no daily cap), it's a Russian-roulette positive-skew strategy.

## High-impact events in January 2026

Notable events that hit during the test window:
- **Jan 9 13:30 UTC** — NFP (Dec 2025 data)
- **Jan 14 13:30 UTC** — CPI YoY (Dec 2025)
- **Jan 22 13:30 UTC** — ECB Rate Decision
- **Jan 29 19:00 UTC** — FOMC Rate Decision
- **Jan 30 13:30 UTC** — PCE Index

Event-trade overlay against each .set is in `runs/<run_id>/event_impact.csv` (run `scripts/overlay_calendar.py` after batch fully completes). Until generated, we can't quantitatively say which event hit each config hardest.

## Synthesis — implications for the plan

1. **The 5k config alone is at the 2.5%/day target.** This is the most important finding. We have an existing .set that achieves the goal on real January 2026 data, within the locked 30% DD ceiling. Everything else from here is "can we make this repeatable and scale it to 100k?".

2. **The 5k config is `PyramRange=0` (pyramid OFF).** This **rejects the original "heavy grid + pyramid" framing** as the upside lane. Pure martingale grid (no pyramid) beats grid + pyramid in this dataset. Sprint 5's pyramid stories should be deprioritized; Sprint 2 should focus on what makes the bare grid work.

3. **`MaxBasketDD_Pct=55` is still ornamental.** All 5 .sets use it unchanged; 35k blew through to 48.66% equity DD anyway. S1.0's basket-equity-SL is still the binding constraint we need — even though 5k's equity DD was 11.66% in this sample, a tail month could blow it open. **Sprint 1 work must precede live deployment of 5k recipe.**

4. **Sizing is the elephant.** 5k config uses `StartOpenLots=0.10` (10× the 0.01 base of the others). Net P/L scales with lot size; **the 5k result is partly an effect of bigger initial positions**, not pure strategy edge. Scaling to 100k means we'd need StartOpenLots=2.0 (40× current 35k config!) which is far outside the broker / margin envelope. **Sprint 1.5's auto-scaled `LotsBase` story is now critical** — without it, this strategy can't scale to 100k.

5. **Daily-profit-lock at 14:30 server** is absent from 5k. The other lane-A and lane-B configs use it but 5k doesn't — and 5k beats them. Either profit-lock doesn't matter or it actively HURTS in a continuously-trending market. Sprint 4's "TimeOfDay profit-lock" story should be DOWN-prioritized as a result, possibly cut.

6. **3k config's per-position SL=515 didn't save it from 31% balance DD.** Per-position SL alone is insufficient when the EA opens many concurrent positions. Confirms F1's choice of *basket-equity* SL over per-position SL.

7. **Win rate alone is not a good metric.** 5k at 67.4% WR / +87.8% net vs 1.3a at 92% WR / +0.01% net. Sprint 2's recipe-discovery should rank by UPI (net / Ulcer), not WR.

8. **Fast-reactive slope filter is part of the magic.** 5k has `maPeriod=4` and `slopeLookbackBars=2` (vs default 50 / 5). The fast filter catches micro-reversals which feed the grid. Sprint 2 must include slope-filter speed as a discovered parameter — slow defaults may have been suppressing strategy edge.

## Decision rule outputs

- **Surviving architecture for Sprint 2 seeding**: **Lane C — 5k config**. UPI ≈ 4393 / 505 = **8.7**, an order of magnitude better than the next best (35k at 0.13). Pure grid martingale, no pyramid, fast-reactive slope filter, aggressive initial sizing.
- **Re-priority of plan stories**:
  - S1.5 (auto-scaled LotsBase) → **promoted to URGENT**. Without it, the 5k recipe doesn't scale to 100k.
  - S1.0 (basket-equity-SL) → still required to bound the tail-month risk.
  - Sprint 5 pyramid stories (S5.2, S5.3) → **deprioritized** or possibly cut. Pyramid hurt in the empirical results.
  - S4.2 (multi-snapshot profit-lock) → **deprioritized**. 5k doesn't use any profit-lock and beats configs that do.
  - Sprint 2 must include `maPeriod` / `slopeLookbackBars` in the scaling-discovery shortlist for `lotMultiplier` and `startBe` (they're related through fast-reactive entry).
- **Must validate** the 5k recipe across multiple months (Feb, Mar, Apr 2026; older 2024-2025 if possible) before committing to it as the Sprint 2 seed. Single-month results can mislead.

## Open follow-ups

- [ ] **Extend 5k recipe to Feb / Mar / Apr 2026** to test repeatability (high priority).
- [ ] **Replay 5k recipe at 100k deposit** with `StartOpenLots=2.0` (or auto-scaled) — does it still work or does it run into broker margin / stop-out?
- [ ] **Run `scripts/overlay_calendar.py` per .set** for event-by-event impact — particularly: did 5k survive Jan 29 FOMC cleanly, or did equity DD spike there?
- [ ] **Try 5k recipe at smaller / larger lot multipliers** (3×, 5×, 6×) to see if 4× is sweet spot or local maximum.
- [ ] **Add pyramid to 5k config** as A/B to confirm pyramid actually hurts (vs just confound from other parameter differences).
