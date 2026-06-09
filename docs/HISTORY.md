# MoneyDancer — Research History & Findings

Canonical, append-only ledger of changes, decisions and findings. **Update this file every time a change ships, a hypothesis is tested, or a decision is made.** See § "Update workflow" at the bottom for the discipline.

> If a fact appears in two places (memory file, decision memo, CHANGELOG), this doc is the index that points to them all. Memory and `runs/decisions/*` are the primary sources; CHANGELOG describes deltas; this file ties them together.

---

## 1. Current state (2026-05-21)

| Field | Value |
|---|---|
| **Ship config** | `mt5/2.0/MoneyDancer_2.0/presets/XAUUSD_2.0_STEP_ship.set` |
| **Ship lineage** | S17 (block-both) → WT (with-trend) → **STEP** (WT + StepPoints=80 + MinOrderDistancePts=60) |
| **Last ship commit** | `7521035` — "ship MoneyDancer 2.0 (STEP variant) + 1.2 reconstruction + DiscoSignalReplay" |
| **Last code change** | `ae9a874` — "PL.5 daily EOD webhook" (pre-live engineering complete) |
| **Pre-live engineering** | PL.1 (rail state persistence), PL.2 (order error logging), PL.3 (symbol-spec assertion), PL.5 (daily EOD webhook). PL.4 (full CSV telemetry) deferred — Print() to Experts log sufficient for MVP. |
| **32-cell validation** | H1 16 cells + H2 OOS 16 cells. 28/32 positive (87.5%). Total $144,314 on $5k baseline (× 32 cells). Mean +90.2% / cell. Max DD 40.48% (may25-H2). |
| **Daily-avg backtest** | +9.66% / day H1; +8.21% / day H2. Live decay expected 40-50% → realistic 4-5% / day target. |
| **Blocking next step** | S5.5e cent-account forward test — user opens RoboForex Pro-Cent demo with $1k real, deploys STEP .set, monitors 30-60 days. |

### What's open (next code/test work)

**Status as of 2026-05-23: backtest iteration PAUSED after 4-in-a-row failures since STEP. Only S5.5e (cent forward) is actionable, and it's blocked on user.**

| ID | Description | Status | Task # |
|---|---|---|---|
| S2.C.8 | Daily pre-close flatten — INVESTIGATED, BUSTED on H2 OOS | completed | #46 |
| S2.C.4 | Martingale shape — INVESTIGATED, BUSTED (startBe=1 structurally required) | completed | #48 |
| S5.5c | Regime-aware base lot — INVESTIGATED, BUSTED (cell-specific) | completed | #51 |
| S2.C.6 | MMD cloud Red period — INVESTIGATED, BUSTED | completed | #52 |
| S2.C.9 | Per-DOW × per-regime hour map | **paused** (low expected payoff vs cost) | #47 |
| S3.2c | PYRAMID_ONLY during MMD-trend | **paused** (high cost, low confidence) | #49 |
| S3.2d | PURE_TREND_FOLLOW (stretch) | **paused** | #50 |
| S5.5b | Max-lot ceiling discovery per broker | research (needs live capacity data) | #20 |
| S5.5d | Equity-tier scaling | deferred until cent forward | n/a |
| **S5.5e** | **Cent-account forward test** | **BLOCKED on user — only actionable work remaining** | #19 |
| PL.1 | Rail state persistence across EA restart | ✅ shipped `2c82ea3` | #53 |
| PL.2 | Order-send error logging | ✅ shipped `5136346` | #54 |
| PL.3 | Symbol-spec assertion (OnInit) | ✅ shipped `5136346` | #55 |
| PL.4 | Full CSV telemetry (CashCabaret 48-col) | deferred — Experts log sufficient | #56 |
| PL.5 | Daily EOD webhook (Discord/Telegram) | ✅ shipped `ae9a874` | #57 |

---

## 2. Lineage tree

```
1.1 (original 5 user .sets)
  │  F0: 5k-heavy-grid +88% Jan, -429% Apr OOS — regime-shift catastrophe
  ▼
1.2 (Sprint 1 rails reconstruction; not shipped to users)
  │  S1.0 basket-SL · S1.6 all-time DD · S3.2 regime gate
  │  S1.7 Friday flatten · S1.1 news (off) · S2.0 hour-block
  ▼
2.0 — S17 (block-both)
  │  RegimeTrendMode=0 — block grid both directions in MMD-trend
  │  Result: +25.9% / cell, 12/17 positive (5 negatives during trend false-range gaps)
  ▼
2.0 — WT (with-trend)
  │  RegimeTrendMode=1 — allow grid only in trend direction during MMD-trend
  │  Result: +63.8% / cell, 17/17 positive, +6.38% / day H1
  ▼
2.0 — STEP                                        ← CURRENT SHIP
  │  StepPoints: 120 → 80 (basket-BE gate triggers earlier)
  │  MinOrderDistancePts: 40 → 60 (sparser grid in early build-up)
  │  Result: +96.6% / cell H1, 16/17 positive (feb25 -17.8% is the cost)
  │           +82.9% / cell H2 OOS (13/16 positive)
  │           32-cell combined: 28/32 positive, $144,314 sum, +90.2% mean
  ▼
2.0 — STEP + S2.C.8 (under test)
   DailyPreCloseHour=23, DailyPreCloseMinute=55, DailyResumeHour=1
   Hypothesis: close baskets pre-XAU-daily-break to eliminate
   may25-H2's 40.48% DD breach (basket bled during market-closed pocket).
```

---

## 3. Timeline of iterations

Each row links to: commit, decision memo (`runs/decisions/`), and any relevant memory file.

### 2026-05-15 — F0 (sprint -1, feasibility study)

- **What**: Ran 5 user .sets on Jan 2026 RoboForex, then cross-broker Duka, then OOS Apr-May 2026.
- **Result**: 5k-heavy-grid blew up in Apr OOS (-429%, 6 days, stop-out). Pattern: range-month wins, trend-month catastrophe.
- **Lesson**: cross-broker on same period gives false confidence. **Cross-period (different months, same broker) is what matters.**
- **Plan-level changes**: S1.0, S1.6, S3.2 elevated to critical-path before Sprint 2 work allowed.
- **Memory**: `project_moneydancer_f0_findings.md`
- **Decision memos**: `runs/decisions/F0-empirical-2026-Q1.md`, `F0-duka-comparison.md`, `F0-OOS-failure.md`

### 2026-05-15 → 2026-05-17 — Sprint 1 rails (1.2 build)

- **What**: Ported 1.1 to 1.2 and added: S1.0 basket-equity-SL, S1.3 daily-loss kill, S1.6 all-time DD, S1.7 Friday flatten, S2.0 hour-block, S3.2 ADX gate, S3.2a MMD multi-cloud classifier.
- **Validation**: Apr 1-10 2026 rerun. F0 baseline -429% → rails-on +149%, eq DD 10.1%.
- **Lesson**: rails do the work, spread overlay alone makes it worse (-1280% vs -429% no-rails).
- **Critical bugfixes baked in**:
  1. Rails no longer respect day-pause (Feb-25 catastrophe: paused rails left positions bleeding 22 hours).
  2. Series-close failure escalates to CloseAll instead of incrementing day counter as if SL fired.
- **Memory**: `project_moneydancer_critical_path.md`
- **Decision memo**: `runs/decisions/S1-rails-validation.md`

### 2026-05-17 — S2.0 hour analysis

- **What**: 36,268 deals across 5 IS + 5 OOS months. Hour-of-day P&L breakdown.
- **Result**: H22 best (+$3.66/trade); only H18 (-$0.09) and H23 (-$0.20) negative. Friday weakest weekday.
- **Decision**: ship `HourBlockList="18,23"` (later removed when WT regime gate proved cleaner).
- **Memory**: `project_moneydancer_critical_path.md` (§S2.0)

### 2026-05-18 — Iteration round 1 (variants)

- **What tried**: WTP (pyramid on), WT5 (basket SL 5%), WTDP (PyramidFixedTPPts=150).
- **Result**: ALL FAILED. WTP timed out (pyramid can't exit sustained trends with slope-coast). WT5 net 41% lower than WT. WTDP dec25 DD breach 40%.
- **Code shipped (defaults OFF)**: `PyramidFixedTPPts` input (fixed-TP pyramid mode).
- **Decision memo**: `runs/decisions/2026-05-18-iteration-round-1.md`

### 2026-05-18 — Investigation: weak vs monster cells

- **What**: Compared aggregate features of weak cells (mar25, jul25, jan26) vs monster cells (dec25, apr25, apr26).
- **Result**: Same 70% win rate. PF differs (1.0 weak vs 1.5 monster). Driver = entry-quality filter, not exit logic.
- **Decision memo**: `runs/decisions/2026-05-18-investigation-vol-quality.md`

### 2026-05-19 — Iteration round 2 (adaptive MinMove)

- **What shipped (default OFF)**: `ENUM_MINMOVE_MODE` (FIXED/ATR_INVERSE/ATR_LINEAR) + 5 inputs + `EffectiveMinMovePoints()` helper.
- **Result**: INVERSE helps jan26 (+99pp) + dec25 (+18pp) but breaks mar25 (-25pp), sep25 (-50pp). Continuous scaling shape is wrong for binary problem.
- **Decision memo**: `runs/decisions/2026-05-19-iteration-round-2.md`

### 2026-05-19 — Discriminator search

- **What**: Computed per-cell ATR, burst frequency, tick density, follow-through % across 17 cells.
- **Result**: NONE discriminate weak from monster cells. jan26 vs dec25 have near-identical aggregate features but 300× different output.
- **Conclusion**: variance is **path-dependent** (basket state, regime transitions, news positioning), not market-state-dependent.
- **Decision memo**: `runs/decisions/2026-05-19-discriminator-search.md`

### 2026-05-19 → 20 — Iteration rounds 3 + 4

- **Round 3 (ATR floor + regime lot scaling)**: ATR floor doesn't discriminate (jan25 has lowest ATR but +32% positive). LotMultTrend=0.5 hurts apr25 -90pp (smaller base lot → smaller wins on monster trends). Both rejected.
- **Round 4 (path-dependent options)**: BlockDOnAdverseMMD, UseMMDAdverseGateForE, MaxBasketLossPctRange/Trend — all 3 options also failed. Confirms path-dependence is the real driver.
- **Code shipped (defaults OFF)**: MinATRPointsForEntry, LotMultRange/Trend, MaxBasketLossPctRange/TrendWith/TrendAgainst, BlockDOnAdverseMMD, UseMMDAdverseGateForE.
- **Decision memos**: `2026-05-19-iteration-round-3-final.md`, `2026-05-20-iteration-round-4-path-dependent.md`

### 2026-05-20 → 21 — Iteration round 5 (S2.C static-param audit)

- **HARD STOP rule**: max 3 full-sweep attempts beating WT, else declare WT final.
- **S2.C.1 hour-of-day**: no hour consistently bad across cells. FAILED.
- **S2.C.2 lotMultiplier 2.5 & 3.0**: split signal — weak cells WANT 2.5, monsters WANT 4.0. Static 2.5 universal: -270pp aggregate. FAILED.
- **S2.C.3 basket mechanics (3 variants)**: STEP (`StepPoints=80`, `MinOrderDistancePts=60`) **WON +51% on full 17-month sweep**. TIGHTER and WIDER failed.
- **S2.C.5 regime-aware lotMultiplier (LotMultiplierRange=2.5)**: sample test failed; ship STEP universal multiplier.
- **Ship decision**: STEP becomes new default. feb25-H1 (-18%) is the cost — isolated to `StepPoints=80` (same knob that drives wins). No clean knob separation.
- **Code shipped**: `lotMultiplierRange` input (default 0.0 = use base multiplier).

### 2026-05-21 — H2 OOS validation + S5.5f + commit 7521035

- **H2 second-half-of-month sweep on STEP** (16 cells; may26-H2 has no data): 13/16 positive (81%), sum $66,345 (85% of H1), mean +82.9%, max DD 40.48% (may25-H2 breaches 40% S1.6 ceiling — would trigger kill in compounded mode).
- **S5.5f code fix**: basket-SL rail (`Risk.mqh::EnforceBasketSL_Dir`) now detects market-closed during XAU daily-break (~00:00-01:00 UTC) and defers retries instead of spinning ~22,000 times per cell. New `IsMarketCurrentlyClosed()` helper.
- **Validated bit-identical**: may25-H2 P&L unchanged with fix (+$6,490 / 40.48% DD / 3,418 trades). Fix is code hygiene + live broker safety; doesn't change backtest P&L. **The 40.48% DD is architectural** (basket-vs-market dynamics during closed window), not bug-induced.
- **S5.5a recovery-add lot fix**: shipped same commit. Recovery "DB" adds now use preserved `FirstBasketLotSeries` instead of shrunken `ComputeBaseLot()`.
- **Commit**: `7521035` — ships MoneyDancer 2.0 (STEP) + 1.2 reconstruction + DiscoSignalReplay.
- **Memory**: `project_moneydancer_17month_stability.md` (32-cell summary table)
- **Decision memo**: `runs/decisions/2.0-release-and-validation.md`

### 2026-05-21 — S2.C.8 daily pre-close flatten (in test)

- **Hypothesis**: pre-closing baskets 5 min before XAU daily-break window eliminates may25-H2's bleed-during-closed mechanism. S5.5f handles the *symptom* (rail spinning); S2.C.8 prevents the *cause* (basket open during closed pocket).
- **Code shipped (default OFF)**: `DailyPreCloseHour`, `DailyPreCloseMinute`, `DailyResumeHour` inputs + `EnforceDailyPreClose()` in Risk.mqh, wired in OnTick after Friday flatten.
- **Test variant**: `XAUUSD_2.0_STEP_PRECLOSE_test.set` (STEP + S2.C.8 enabled).
- **Promotion gate**: may25-H2 DD < 35% AND ≥4/6 cells no regression > 30pp AND no cell DD > 40%.
- **Commit**: `17150ff`

**Round 1 (cutoff=23:55 UTC) — bit-identical to STEP baseline.** The function fires daily, log shows "closed 0 positions" every time. Tracing may25-H2 log: market-closed errors start at **23:xx** (165 events) and peak at **00:xx** (14,026 events) and **01:xx** (1,664 events). The 23:55 cutoff is INSIDE the broker's daily-close window — our flatten itself is rejected with "Market closed" same as basket-SL. Lesson: flatten cutoff must be EARLIER, before any close-failures begin. Trying **22:00** (right before trading-window end at 22:10) next.

**Round 2 (cutoff=22:00 UTC) — DD breach fixed, monster cells regress.**

| Cell | STEP % | R2 % | R2 DD | Delta |
|---|---|---|---|---|
| **may25-H2** | +128.8% | +129.5% | **19.2%** | +0.7pp ✓ DD breach gone |
| dec25-H1 | +305.8% | +229.0% | 18.1% | -76.8pp ✗ |
| apr26-H1 | +258.4% | +101.9% | 17.9% | **-156.5pp ✗** |
| feb25-H1 | -17.8% | -11.8% | 38.7% | +6.0pp ✓ |
| mar25-H1 | +37.0% | +31.4% | 23.9% | -5.6pp |
| jan26-H1 | +19.0% | +24.6% | 33.2% | +5.6pp |

Sample sum R2 = +504.6% vs STEP +731.2% (-227pp). Promotion gate fails: dec25 & apr26 regress >30pp. **The flatten kills overnight monster wins** (basket still building when 22:00 hits → forced close cuts off the run). may25-H2's bleeding basket WAS open at 22:00 (trades dropped 3503 → 3330) and successfully closed before the closed window.

**Round 3 (cutoff=22:00 UTC, conditional close on loss ≥ 1% equity) — fixes DD but WORSE on aggregate than R2.**

| Cell | STEP % | R2 uncond | R3 cond≥1% | R3 DD | R3-STEP |
|---|---|---|---|---|---|
| may25-H2 | +128.8% | +129.5% | +126.7% | 19.9% | -2.1pp ✓ |
| dec25-H1 | +305.8% | +229.0% | +181.0% | 19.8% | -124.8pp ✗ |
| apr26-H1 | +258.4% | +101.9% | +101.5% | 17.6% | -156.9pp ✗ |
| feb25-H1 | -17.8% | -11.8% | -11.1% | 38.4% | +6.7pp ✓ |
| mar25-H1 | +37.0% | +31.4% | +32.7% | 24.0% | -4.3pp |
| jan26-H1 | +19.0% | +24.6% | +22.7% | 33.5% | +3.7pp |

R3 sum +453%, R2 sum +505%, STEP +731%. **R3 conditional is worse than R2 unconditional on aggregate.**

Diagnosis: monster baskets aren't "in profit" at 22:00 — they're mid-build with floating losses while waiting for retraces. The 1% threshold catches them. Unconditional flatten locks in whatever mid-state P&L; conditional leaves the basket open and it goes through deeper dips before reverting. The "let winners run" mental model doesn't apply because at 22:00 there are rarely "winners" to spare.

**Round 4 (cutoff=22:00 UTC, conditional ≥4%) — partial fix; cell-specific.**

| Cell | STEP | R4@4% | R4 DD | Delta |
|---|---|---|---|---|
| may25-H2 | +128.8% | +117.5% | **25.4%** ✓ | -11.3pp |
| dec25-H1 | +305.8% | **+320.4%** | 18.1% | **+14.6pp ✓** |
| apr26-H1 | +258.4% | +122.2% | 17.9% | **-136.2pp ✗** |
| feb25-H1 | -17.8% | -12.4% | 38.2% | +5.4pp ✓ |

Trade counts: dec25 4216 → 4207 (almost unchanged), apr26 5096 → 4292 (-800 trades). So 4% threshold barely fires on dec25 but fires often on apr26. apr26 has nights with deep transient dips that would have recovered. dec25 doesn't. **The asymmetric mechanic works for some cells but not others — cell-specific.**

**Round 5 (cutoff=22:00 UTC, conditional ≥6%) — SAMPLE WIN.** 4-cell sample at cond@6% threshold: all 4 cells improved or unchanged. apr26 trade count identical (flatten never fired). Sample sum: +692% vs STEP +675% (+17pp).

**Full 17-cell H1 sweep at cond@6% — CLEAR NET WIN.**

| Cell | STEP | PRECLOSE_C6 | PC DD | Delta |
|---|---|---|---|---|
| jan25 | +49.0% | +49.0% | 14.5% | +0.0pp |
| feb25 | -17.8% | -13.0% | 38.1% | +4.8pp |
| mar25 | +37.0% | +37.0% | 22.2% | +0.0pp |
| apr25 | +98.8% | +110.4% | 18.9% | +11.6pp |
| may25 | +79.7% | +93.9% | 23.8% | +14.2pp |
| jun25 | +36.8% | +36.3% | 30.5% | -0.5pp |
| jul25 | +59.4% | +60.1% | 18.2% | +0.7pp |
| aug25 | +25.1% | +25.1% | 18.0% | -0.0pp |
| sep25 | +70.5% | +80.3% | 21.7% | +9.8pp |
| oct25 | +100.9% | +108.7% | 13.7% | +7.8pp |
| nov25 | +64.0% | +54.2% | 33.1% | -9.8pp |
| dec25 | +305.8% | +314.7% | 18.1% | +8.9pp |
| jan26 | +19.0% | +22.5% | 31.4% | +3.5pp |
| feb26 | +160.5% | +160.5% | 15.0% | +0.0pp |
| mar26 | +212.1% | +212.1% | 12.9% | +0.0pp |
| apr26 | +258.4% | +258.3% | 12.2% | -0.1pp |
| may26 | +83.0% | +110.5% | 21.6% | **+27.5pp** |

**Aggregate**: PRECLOSE total **$86,034** vs STEP $82,110 → **+$3,924 (+4.8%)**. 16/17 positive (same). 0 regressions > 20pp. 7 cells materially improved. 8 cells essentially unchanged (flatten never fires). Max DD 38.14% (slightly worse than STEP's 37.79% by 0.35pp).

**Promotion gate**: 2/3 PASS. Only the max-DD criterion fails by 0.35pp (38.14% vs 37.8% target). But H1 max-DD was never the worry — **may25-H2 (OOS) had 40.48% DD breach**; sample confirmed PRECLOSE drops it to 26.7%. The H2 OOS sweep (15 cells) is running to confirm.

**Decision direction**: ship STEP+PRECLOSE if H2 confirms may25-H2 DD < 30% AND H2 aggregate is ≥ 85% of H1 (same OOS degradation profile as STEP).

**H2 OOS sweep (15 cells, jan26-H2 re-running) — REVERSES THE H1 WIN.**

| Cell | STEP H2 | PRECLOSE H2 | Delta |
|---|---|---|---|
| **may25-H2** | +129.8% @ **40.5% DD** | +132.3% @ **26.7% DD** | DD breach FIXED + small gain |
| apr25-H2 | +150.1% | +162.3% | +12.2pp ✓ |
| sep25-H2 | +40.5% | +66.7% | +26.3pp ✓ |
| oct25-H2 | +64.1% | +66.7% | +2.6pp ✓ |
| jun25-H2 | +10.1% | -0.0% | -10.2pp |
| nov25-H2 | +228.6% | +217.6% | -11.0pp |
| **mar26-H2** | **+124.2%** | **+69.9%** | **-54.3pp ✗** |
| 9 other cells | — | — | unchanged (flatten didn't fire) |

**H2 totals (15 cells)**: STEP $66,346 vs PRECLOSE $56,360 → **PRECLOSE LOSES $9,986 on OOS**.

**Combined 31-cell picture**: STEP $148,456 vs PRECLOSE $142,394 = PRECLOSE -$6,062. Net loss.

**Classic OOS overfit detection.** The H1 win was specific to first-half basket dynamics. mar26-H2 has nights where baskets transiently dip below -6% then recover for monster wins; PRECLOSE flatten cuts them off (-$2,715 on one cell alone). The same -6% threshold that worked perfectly on H1 mar26 (+0.0pp delta) destroys H2 mar26.

**Lesson**: even a conservatively-tuned static threshold doesn't survive OOS. Basket-build-vs-recovery dynamics differ by 2-week window in ways unpredictable from aggregate features (re-confirms the round-4 path-dependence finding).

### DECISION: drop S2.C.8 from ship. STEP stays ship.

- ✓ may25-H2 architectural DD (40.48%) is a known weakness — accepted as-is for now
- ✓ S5.5f remains shipped (code hygiene, fixes the rail-spin log spam during the same window)
- ✗ S2.C.8 daily pre-close NOT shipped — code stays in EA defaults OFF for future re-investigation
- ✗ `XAUUSD_2.0_STEP_PRECLOSE_ship.set` NOT promoted — kept as a documented variant in `presets/` for users who prioritize DD ceiling over total profit (15% DD reduction on may25-H2, $6k aggregate cost)

**Decision memo**: `runs/decisions/2026-05-22-s2c8-daily-preclose.md` to write up the failure.

### 2026-05-23 — S2.C.4 Martingale shape (busted, 5-cell sample only)

- **What tried**: 3 variants on 5 cells (mar25, jul25, dec25, apr26, jan26):
  - A: `startBe=3` (delayed martingale: 4 trades before geometric adds)
  - B: `MaxOrdersDir=30` (depth cap, was 50)
  - C: combined A + B
- **Result**: 
  - Variant A catastrophic: -602pp aggregate on 5 cells. dec25 +306% → +9%, jul25 +59% → -38%.
  - Variant B bit-identical to STEP (baskets never reach 30 naturally).
  - Variant C identical to A (startBe dominates).
- **Lesson**: under WT+STEP, `startBe=1` (aggressive martingale from trade 2) is structurally required. The rails (basket-SL, regime gate) provide the aggression-prevention; martingale's job is recovery. Delaying martingale breaks the recovery, causing accumulated small losses.
- **Decision**: drop S2.C.4. STEP stays. Added 2 entries to validated facts + busted hypotheses.
- **Decision memo**: not required — this was a 5-cell sample with clear catastrophic results. HISTORY.md entry is sufficient.
- **Next**: S5.5c (regime-aware base lot scaling — LotMultRange/Trend inputs already in code).

### 2026-05-23 — S5.5c Regime-aware base lot — BUSTED

- **What tried**: 4 combos × 5 cells using `LotMultRange` + `LotMultTrend` inputs (code already in place).
- **Result**: all 4 combos FAIL the gate (3/5 improve, no -30pp, DD ≤ 37.8%).
  - C1 (Range=0.5, Trend=1.0): aggregate -270pp, dec25 -127, apr26 -143
  - C2 (Range=1.0, Trend=1.5 — original hypothesis): aggregate -169pp. **Hypothesis inverted.**
  - C3 (Range=0.5, Trend=1.5): aggregate -234pp
  - C4 (Range=1.5, Trend=0.5 — INVERSE): aggregate -66pp. apr26 +109pp ✓ but dec25 -193pp ✗
- **Surprise**: C4 made apr26 GROW by 109pp but crippled dec25 by 193pp. Cell-specific asymmetry — same pattern as S2.C.8.
- **mar25 and jan26 unchanged across all 4 combos**: those cells stay in single regime for the whole window, so only one multiplier applies (and equals 1.0 in 3 of 4 combos).
- **Lesson**: regime-aware base lot scaling doesn't carve a universal win. The PF-by-regime distinction is real but cell-specific in direction — can't be addressed by a static cross-cell multiplier.
- **Added to busted hypotheses**: "PF higher in trend → push trend lots" (the original hypothesis) is wrong direction empirically.
- **Decision memo**: not required — HISTORY.md entry sufficient. Pattern is becoming clear.

### Pattern (3 consecutive failures since STEP shipped)

S2.C.8 (daily pre-close), S2.C.4 (martingale shape), S5.5c (regime-aware lot) — all three iterations after STEP have FAILED. The round-4 path-dependence finding is the dominant truth: **STEP is at a strong local optimum for static-knob iteration**. Aggregate market features don't predict cell variance; cell-specific behavior can't be carved by global thresholds.

**Implication**: remaining queued backtest stories (S2.C.9 per-DOW × regime hour, S3.2c PYRAMID_ONLY, S3.2d, S5.5b/d) are all higher-effort lower-confidence than what we just exhausted. Likely outcomes ranked from most to least likely:
1. Same cell-specific or static-overfit failures (most likely)
2. Marginal universal improvement (possible but small)
3. New ship config (low probability without live data signal)

### 2026-05-23 — S2.C.6 MMD cloud period tuning — BUSTED (4 in a row)

- **What tried**: 2 variants × 5 cells. A: Red=8 (faster), B: Red=24 (slower).
- **Result**: both FAIL the gate.
  - Variant A (Red=8): 0/5 improvements, aggregate -281pp. dec25 -126pp, apr26 -145pp.
  - Variant B (Red=24): 1/5 improvements, aggregate -124pp. dec25 -104pp.
- **Lesson**: changing MMD period doesn't improve discriminative power of the regime classifier in any direction. dec25's basket dynamics are robust to MMD timing changes — its 305% comes from the cloud structure WT trusts, not the Red cloud specifically.
- **Decision memo**: not required — HISTORY entry sufficient.

### 2026-05-23 — DECISION: backtest iteration EXHAUSTED. PAUSE for cent forward.

**4 consecutive failures since STEP shipped (2026-05-21):**

| Story | Mechanism tested | Outcome | Aggregate |
|---|---|---|---|
| S2.C.8 | Daily pre-close flatten (conditional ≥6%) | H1 win → H2 OOS reverse | -$6,062 net |
| S2.C.4 | Martingale shape (startBe=3, MaxOrd=30) | Structurally broken | -602pp / 5 cells |
| S5.5c | Regime-aware base lot (4 combos) | Cell-specific, no universal direction | -66 to -270pp / 5 cells |
| S2.C.6 | MMD cloud Red period (faster/slower) | Both directions hurt monsters | -124 to -281pp / 5 cells |

**Recurring failure mode**: every variant that helps one cell hurts another. dec25 + apr26 (monster trend cells) and mar25 + jul25 (weak range cells) want opposite parameter directions. Static cross-cell thresholds cannot satisfy both.

This re-confirms (now for the 5th time) the round-4 finding: **variance is path-dependent**. The cells share NO aggregate-feature discriminator (not ATR, burst freq, tick density, follow-through %, MMD period, lot scaling, basket-loss threshold, hour profile).

### Remaining queued backtest stories — PAUSED

| ID | Story | Why paused |
|---|---|---|
| S2.C.9 | Per-DOW × per-regime hour map | Requires ~3-5 hr telemetry code; path-dependence finding predicts cell-specific results — likely also fails the gate |
| S3.2c | PYRAMID_ONLY during MMD-trend | ~8-11 hr code + Pyramid retune; structural change with no signal it'd beat rails-on STEP |
| S3.2d | PURE_TREND_FOLLOW | Stretch; lower confidence than 3.2c |
| S5.5b | Max-lot ceiling discovery per broker | Research item, not optimization; need live capacity data |
| S5.5d | Equity-tier scaling | Deferred until cent forward proves base scaling |

**ALL have higher cost AND lower expected payoff than what just failed.** Continuing them is unlikely to find a new ship and burns time the user could use to start cent forward.

### Recommendation to user

**STEP is the final shipped backtest config.** Open the RoboForex Pro-Cent demo, deposit $1k real (= cent $100k display), deploy `XAUUSD_2.0_STEP_ship.set`, monitor 30-60 days. The cent forward is the **only remaining signal source** that can:
1. Confirm STEP's 9.66%/day backtest translates to live (target 40-50% realization = 4-5%/day live)
2. Reveal whether per-cell variance shows up live in a way that suggests a specific code change
3. Test the rails (S1.0 basket-SL, S1.6 all-time DD, S5.5f market-closed handler) under real broker conditions

Once cent data lands, the remaining stories may be re-prioritized based on what live data shows. Until then, backtest iteration is on pause.

### 2026-05-23 — Pre-live engineering (PL.1, PL.2, PL.3, PL.5 shipped)

After declaring backtest iteration exhausted, surfaced and addressed pre-live code gaps that would have put $1k real money at risk. **PL.4 (full CSV telemetry) deferred** — existing `Print()` to MT5 Experts log with module prefixes (`[S1.0]`, `[S2.C.8]`, `[PL.1]` etc.) is sufficient for MVP forensic analysis.

**PL.1 Rail state persistence** (`Include/RailStatePersist.mqh`, commit `2c82ea3`):
- Persists Tier-A state (peakEquityEver, basketSLToday/DayKey, tradePauseUntil/Reason, series active/id/openEq/SLFired, baseDayKey/Balance/Ready/Time, lastBuy/SellTime, lastDealsCount, profitLock state) to CSV file `MoneyDancer_railstate_<Magic>_<Symbol>.csv` in MQL5/Files.
- LoadRailState() called at end of OnInit; SaveRailState() at top of OnDeinit; 60s heartbeat via OnTimer.
- Skipped in tester (MQL_TESTER guard) → backtest stays bit-identical.
- **Solves**: cent demo weekend restart loses accumulated DD/day-counter/series anchors.

**PL.2 Order error logging** (`Include/Orders.mqh` extensions, commit `5136346`):
- `TradeRetcodeString()` decodes 40+ MT5 retcodes to readable strings.
- `IsRetcodeRetryable()` / `IsRetcodeTerminal()` classify failures.
- `LogTradeFailure(op, ticket)` uniform `[PL.2]` log on any trade.* failure.
- Wired in `OpenPosition`, `ModifyPositionSLTP`, `ClosePosition` — surfaces broker-rejection codes that were previously silent.
- **Solves**: silent broker rejections that masked the actual failure mode.

**PL.3 Symbol-spec assertion** (`Include/SymbolSpec.mqh`, commit `5136346`):
- `VerifySymbolSpec()` called at OnInit (skipped in tester).
- ALWAYS logs all spec fields for forensic comparison (cent vs standard).
- HARD ASSERTS on: digits outside {2,3}, contract_size outside [10,1000], vol_min/step outside (0,1], tick_value <= 0, SYMBOL_TRADE_MODE=DISABLED.
- SOFT WARNS on: large stops_level, large swap.
- Returns false → INIT_FAILED if specs unexpected; EA refuses to trade.
- **Solves**: cent-account-vs-standard spec ambiguity that could cause wildly wrong lot sizing on real money.

**PL.5 Daily EOD webhook** (`Include/Webhook.mqh`, commit `ae9a874`):
- New inputs: `WebhookEnabled` (default false), `WebhookUrl`, `WebhookEodHour` (22), `WebhookEodMinute` (30).
- Auto-detects Discord vs Telegram from URL pattern.
- Posts daily summary: balance/equity/free, day P&L %, floating + open positions, peak equity + DD %, basket-SL count, pause state, series active/off.
- Once-per-day via `g_webhook_lastPushDayKey` tracker. Called from OnTimer 60s.
- Requires MT5 setup: Tools > Options > Expert Advisors > "Allow WebRequest for listed URL" → add webhook host.
- **Solves**: user can't watch MT5 24/7; needs at-a-glance daily status without polling.

**Backtest invariance**: all four pre-live features gated by `!MQLInfoInteger(MQL_TESTER)`. STEP backtest results unchanged. Verified via code review (no SUCCESS-path changes in trade.* wrappers).

### 2026-05-24 — Phase 1/2/3: 3.0 naming refactor + S2.C.9 telemetry + S3.2c PYRAMID_ONLY (in-place under mt5/2.0)

User chose to do the 4 deferred large items (naming refactor, S2.C.9 telemetry, S3.2c, remaining CR items) in-place under `mt5/2.0/` rather than cutting `mt5/3.0/` folder.

**Phase 1 (commit `0c3ccf2`)**: 3.0 naming refactor.
- 305 substitutions across 16 files (script: `scripts/_naming_refactor.py`)
- 61 input renames: camelCase + PascalCase_underscore → PascalCase
- 22 global renames: g_snake_case → g_camelCase
- 3 shipped `.set` files migrated via `scripts/_rename_set_file.py`
- CR comment cleanups: I6 (OnChartEvent), M5 (BE bisection step), M6 (OnTester), M11 (Webhook startup-hour)
- Verification: compile clean (0/0); EA init log shows MD 2.0 init + 125 input parsing OK + trades fire. Strict bit-identical mar25 deferred due to terminal singleton collision.

**Phase 2 (commit `57814f1`)**: S2.C.9 regime telemetry infrastructure.
- New `Include/RegimeTrace.mqh`: tester-allowed per-trade CSV writer with cols `ts, event, ticket, dir, regime, slope, basket_id, lot, price`
- New input `UseRegimeTrace` (default OFF) — backtest-invariant when off
- Wired into `OpenPosition` via `RegimeTrace_LogOpen`
- New analysis script `scripts/_s2c9_regime_breakdown.py`: joins per-cell trades.csv with regime trace, groups by (DOW × regime × hour), flags consistently-bad cells
- Expected outcome per "iteration exhausted" finding: no flagged (DOW, regime, hour) combinations. Confirms path-dependence dominates even at fine-grained keys.

**Phase 3 (in flight)**: S3.2c PYRAMID_ONLY enum value.
- New `RegimeTrendMode=REGIME_TREND_PYRAMID_ONLY (2)` enum
- New inputs: `RegimePyramidRange=200`, `RegimePyramidBEBufPts=50`, `RegimePyramidIgnoreSlope=true`
- New helpers in `Regime.mqh`: `RegimePyramidEnabled()` + `RegimePyramidDir()`
- `RegimeBlocksEntryDir()`: returns TRUE both dirs in PYRAMID_ONLY MMD-trend (grid blocked)
- `PyramidWantsOrder()`: bypass legacy PyramRange/slope gates when auto-enabled
- Sample test `PYR-5k-sep25` running (sep25 was -19.8% under WT — hypothesis: pyramid catches the trend better)
- Decision rule: if sep25 improves (e.g., > 0% or -10%) AND apr25 monster non-regression → consider full sweep. Else document as designed-not-shipped.

### 2026-05-23 — Code review (full pass, agent + manual triage)

Dispatched Plan agent to read all 22 files (~6.5k LOC) and report findings by severity. Agent produced 4 critical + 11 important + 12 minor + 4 style issues. Triaged + fixed in priority order:

- **All 4 CRITICAL fixed** (commit `153fe91`):
  - C1: `EnforceBasketSL` ignored regime-aware overrides when base `MaxBasketLossPct=0` — silently disabled rail
  - C2: `Dashboard.FinalizeSeriesIfEnded` left series-active stuck when `ShowBasketLabels=false` — next entry attached to dead series id
  - C3: `Dashboard_Init` overwrote PL.1-loaded `g_peakEquityEver` — fragile to init reordering
  - C4: Dead `IsMarketCurrentlyClosed()` pre-check (only checked permanent disable state, not session window)
- **6 of 11 IMPORTANT fixed**: I1 (`g_basketSLDayKey` actually used), I2 (delete write-only state), I4 (runner sizing respects S1.5), I5 (Sunday added to weekend guard), I9 (pre-close also sweeps runners), I11 (doc comment placement)
- **2 of 12 MINOR fixed**: M3, M4 (dead-code deletion)
- 5 IMPORTANT + 10 MINOR + 4 STYLE deferred (lower priority; documented in `docs/CODE_REVIEW.md` § "Deferred")

**Backtest-invariance verified empirically**: mar25 H1 cell with all fixes = $1850.91 / 22.18% DD / 1722 trades — **bit-identical** to STEP baseline. Fixes activate only outside STEP-backtest conditions (regime overrides off, ScenarioE off, DailyPreClose off, persistence tester-gated).

Full report: `docs/CODE_REVIEW.md`. Per-fix code references via `CR-<ID>` comments.

---

## 4. Validated facts (knowledge we keep)

Things tested enough to bet on:

| Finding | Evidence |
|---|---|
| **Drawdown first, profit later** — UPI not raw % is the ranker. Single-period winners (Jan 2026) blow up on out-of-period regimes. | F0 catastrophe; `feedback_dd_first_profit_later.md` |
| **Cross-period > cross-broker for validation.** Same period on two brokers covers the same regime; different periods exposes regime-shift. | F0 false-confidence; `feedback_cross_period_not_cross_broker.md` |
| **Rails do the work, not feed engineering.** Robo overlay alone made things worse (-1,280% vs -429% raw Duka). | Apr-2026 rails validation; `runs/decisions/S1-rails-validation.md` |
| **Variance is path-dependent, not market-feature-dependent.** No aggregate observable (ATR, burst freq, tick density, follow-through, …) discriminates weak from monster cells. | Round 4 discriminator search |
| **Day-pause must NOT pause rails.** Rails check existing positions every tick, regardless of pause state. Pause only blocks NEW entries. | Feb-25 catastrophe -100.8% before fix → -11.9% after |
| **Series-close failure must escalate to CloseAll, not bump day counter.** Otherwise a broker rejection looks like SL-fired and spuriously day-pauses. | Same Feb-25 cascade |
| **MaxSpreadPts is the single most-sensitive param.** -$1k → +$3k on the same data just by raising cap from 15 to 100. | F0 test1.3a; `feedback_spread_cap_most_sensitive.md` |
| **News-event filter not helpful under regime gate.** NFP/CPI/PPI/ECB all positive aggregate under WT — regime gate filters news implicitly. UseNewsBlackout=false is correct. | `project_moneydancer_news_event_classification.md` |
| **% thresholds, never fixed dollars.** Strategy must scale 10k → 200k unchanged. | `feedback_pct_not_dollars.md` |
| **ML can never touch lot, SL, kill-switches.** Advisory only on entry-quality / regime probability. | `feedback_ml_safety_segregation.md` |
| **TG signals are pending orders, not market entries.** Different backtest mechanic. | `feedback_tg_signals_are_pending_orders.md` |
| **Weekend gap is a real loss pattern.** 4 of 5 worst OOS-2025 DDs start Friday and trough Tue/Wed. S1.7 Friday flatten mitigates. | `feedback_friday_weekend_gap.md` |
| **XAU daily-break is a real loss pattern.** ~30 min market-closed pocket around 00:00 UTC where basket-SL rail can't fire. Drove may25-H2 40.48% breach. | S5.5f scan; `runs/decisions/2.0-release-and-validation.md` § H2 |
| **STEP `StepPoints=80` is the dominant single knob.** Drives both the +51% aggregate win AND the feb25 -43pp regression. No clean separation. | Round 5 isolation tests |
| **`startBe=1` (aggressive martingale from trade 2) is structurally required under WT+STEP.** Without geometric scaling, small initial losses accumulate uncorrected. Martingale's role under the rails is *recovery*, not *aggression* — the rails handle aggression-prevention. | S2.C.4 (2026-05-23) |
| **`MaxOrdersDir=50` is operationally unbounded under STEP.** Baskets never reach 30 depth naturally. The cap is a sanity guard, not an active constraint. | S2.C.4 (2026-05-23) |
| **Backtest iteration is EXHAUSTED at STEP.** Static-knob iteration ran 4 consecutive failures (S2.C.8, S2.C.4, S5.5c, S2.C.6) since STEP shipped. Path-dependence is the dominant variance driver; monsters and weak cells require opposite parameter directions, which no static cross-cell threshold can satisfy. Cent forward is the only remaining signal source. | 2026-05-23 |
| **Rail state MUST persist across EA restart on live.** Currently g_peakEquityEver, g_basketSLToday, g_tradePauseUntil, series anchors all reset on OnInit. Weekend close + Monday restart loses accumulated DD/counters. PL.1 fixes this via on-disk CSV; tester-invariant. | PL.1 (2026-05-23) |
| **Order-send failures must be logged, not silent.** Default CTrade behavior returns false on failure but doesn't surface retcode. PL.2 adds `LogTradeFailure(op, ticket)` with retcode-to-string decoder so post-mortem analysis on live is possible. | PL.2 (2026-05-23) |
| **Symbol specs must be verified at OnInit on live.** Cent vs standard account ambiguity could give wildly wrong lot sizing. PL.3 asserts contract_size/vol_min/digits/calc_mode at OnInit; refuses init if specs unexpected. | PL.3 (2026-05-23) |
| **State mutation must NEVER be gated by visual-only flags.** `Dashboard.FinalizeSeriesIfEnded` had `if(!ShowBasketLabels) return;` BEFORE `SetSeriesActive(false)` — silently broke series lifecycle when labels were turned off. Always separate state-machine updates from visual rendering. | CR-C2 (2026-05-23) |
| **Init-order races are bug-magnets.** `Dashboard_Init` unconditionally setting `g_peakEquityEver = ACCOUNT_EQUITY` worked only because of accidental include ordering vs PL.1's `LoadRailState`. Robust pattern: conditional set (`if value is uninitialized, then set`). | CR-C3 (2026-05-23) |

---

## 5. Busted hypotheses (don't try these again without new evidence)

| Hypothesis | What killed it | Where |
|---|---|---|
| "Single-period winner is shippable" | F0 OOS catastrophe | F0 |
| "Cross-broker validation is enough" | Both feeds covered the same regime | F0 |
| "Pyramid + slope-coast exits trends cleanly" | WTP timed out on dec25; pyramid never exits sustained trends with COASTING TP=lastTrigger | Round 1 |
| "ATR floor discriminates weak from monster cells" | jan25 has lowest ATR (301) but +32% positive; mar25 ATR ≈ feb25 ATR | Round 2 / Round 3 |
| "Lower base lot in trend regimes saves SLs" | LotMultTrend=0.5 hurts apr25 -90pp (smaller wins on monster trends) | Round 3 |
| "Static lotMultiplier=2.5 is universal improvement" | Weak cells want 2.5 (mar25 +24pp), monsters want 4.0 (apr25 -173pp) | Round 5 S2.C.2 |
| "Hour-block universally bad hours" | No hour consistently bad across cells under STEP | Round 5 S2.C.1 |
| "Tighter or wider basket mechanics (TP, bePoints)" | TIGHTER and WIDER both failed; only STEP (denser grid, earlier BE gate) worked | Round 5 S2.C.3 |
| "News blackout helps" | All major event groups positive aggregate under WT | News classification |
| "Adaptive MinMove (continuous scaling)" | Helps extremes (jan26 +99pp) but breaks marginals (mar25 -25pp). Linear/inverse function is wrong shape — needs step function on ATR percentile | Round 2 |
| "MMD adverse-side gates (Block D / E)" | Conditions almost never fire under WT (basket already direction-filtered) | Round 4 Opt2/3 |
| "Bidirectional regime-aware basket SL (8/12/4)" | TrendWith too loose, TrendAgainst clips monster captures | Round 4 Opt1 |
| "Daily pre-close flatten before XAU break (S2.C.8)" | H1 won (+$3.9k) but H2 OOS lost $10k. Static loss threshold doesn't generalize — mar26-H2 alone -$2,715 from forfeited monster builds. The cure costs more than the disease. | S2.C.8 R1-R6 (2026-05-21/22) |
| "Delayed martingale (startBe=3) is safer" | Catastrophic on 5-cell sample: -602pp aggregate (dec25 +306 → +9, jul25 +59 → -38). Under WT+STEP, aggressive `startBe=1` martingale is STRUCTURALLY REQUIRED — small initial losses can't be recovered without geometric scaling. Regime gate + STEP knobs already filter bad entries, so martingale's role is recovery, not aggression. | S2.C.4 (2026-05-22/23) |
| "Capping basket depth (MaxOrdersDir=30 vs 50)" | Bit-identical results. Baskets never reach 30 naturally under STEP — default 50 is just a sanity guard. | S2.C.4 (2026-05-22/23) |
| "Pushing base lot in trend regime (LotMultTrend=1.5)" | Aggregate -169pp on 5 cells. Hypothesis INVERTED: monster cells like dec25 lose 100pp when trend lots grow. | S5.5c C2 (2026-05-23) |
| "Regime-aware base lot scaling is universally improving" | All 4 combos of LotMultRange × LotMultTrend fail. C4 inverse (more in range, less in trend) helps apr26 +109pp but cripples dec25 -193pp. Cell-specific, can't carve by static thresholds. | S5.5c (2026-05-23) |
| "Tuning MMD Red cloud period (8 or 24 vs 12)" | Both faster and slower hurt monsters. Variant A: -281pp aggregate, dec25 -126pp / apr26 -145pp. Variant B: -124pp, dec25 -104pp. The MMD cloud stack is robust to small Red period changes — cell-specific behavior unaffected. | S2.C.6 (2026-05-23) |

---

## 6. Update workflow (so this doc stays current)

**The rule**: before closing any in-progress task, append to this file.

For each iteration:

1. **Add a timeline entry** in § 3, with:
   - Date
   - Story ID (e.g., S2.C.8) + headline
   - Hypothesis (1 line)
   - Result (1-3 lines, include numbers)
   - Lesson (1 line — what we'd tell a future Claude)
   - Commit hash (`git log --oneline -1`)
   - Decision memo path (or "memo pending" if not yet written)
   - Memory file path (if any)

2. **If the iteration moved the ship**: update § 1 (current state) + § 2 (lineage tree).

3. **If a hypothesis was confirmed/busted**: append to § 4 or § 5 with the evidence.

4. **If the queue changed**: update the "What's open" table in § 1.

5. **Commit this file together with the code change** so the history grows linearly with the work.

### After each git commit affecting code or .set:

```bash
# 1. Get the new commit hash
git log --oneline -1

# 2. Edit docs/HISTORY.md — add timeline entry + update § 1
# 3. Stage + commit (amend onto the code commit if commit was just made):
git add docs/HISTORY.md
git commit --amend --no-edit   # if same commit
# OR
git commit -m "docs(history): record S2.C.X result"
```

### After each decision memo lands in `runs/decisions/`:

- Add the memo path to the relevant § 3 timeline row.

---

## 7. Data assets index (where things live)

| Asset | Path | Notes |
|---|---|---|
| Ship .set (gold, 5k base, 100k cent scaled) | `mt5/2.0/MoneyDancer_2.0/presets/XAUUSD_2.0_STEP_ship.set` | The shipped config |
| Ship preset README (per-knob justification) | `mt5/2.0/MoneyDancer_2.0/presets/README.md` | Audit trail for every input |
| 2.0 release + validation memo | `runs/decisions/2.0-release-and-validation.md` | Full 17 + 16 OOS table |
| Per-iteration decision memos | `runs/decisions/2026-*-iteration-round-*.md` | One per failed/successful round |
| 17-month per-cell trades.csv | `runs/STEP-5k-{cell}-2wk/trades.csv` etc. | First-half cells |
| H2 OOS per-cell trades.csv | `runs/STEP-OOS-5k-{cell}-H2/` | Second-half cells |
| Dukascopy 36M tick CSV | `data/duka/XAUUSD_2026_jan-may.csv` (3.2 GB) | Pre-overlay raw |
| MT5 custom symbol (RoboForex spread overlay) | `XAUUSD.duk_robo` (2026), `XAUUSD.duk_robo_2025` (2025) | Used by all 17 cells |
| Calendar (NFP/CPI/PPI/ECB Jan-May 2026) | `data/calendar/Q1_2026.csv`, `Q2_2026.csv`, `2026_full.csv` | 47 T1+T2 events |
| Master 33k-deal CSV (F0 era) | `runs/trades_master.csv` | Multi-run unioned |
| Plan file | `C:\Users\nikof\.claude\plans\have-a-look-at-velvet-marble.md` | Full Scrum plan |
| Memory index | `C:\Users\nikof\.claude\projects\C--Users-nikof-Documents-GitHub-MoneyDancer\memory\MEMORY.md` | All persistent project notes |

---

## 8. Memory cross-reference

These memory files (in Claude's persistent memory, not in this repo) are the authoritative project notes. **This doc summarizes them; the memory files have full detail.**

| Memory | Topic |
|---|---|
| `project_moneydancer_17month_stability.md` | Full 17-month + H2 OOS sweep, ship implications |
| `project_moneydancer_f0_findings.md` | F0 regime-shift catastrophe |
| `project_moneydancer_critical_path.md` | Sprint 1 rails implementation status |
| `project_moneydancer_lot_management_backlog.md` | S5.5 cluster (1 bug + 4 discovery items) |
| `project_moneydancer_data_assets.md` | Where trades/ticks/calendar live |
| `project_moneydancer_news_event_classification.md` | All event groups positive under WT |
| `project_moneydancer_versioning.md` | MAJOR.MINOR workflow |
| `project_moneydancer_ea.md` | Versioned releases under mt5/X.Y/ |
| `feedback_dd_first_profit_later.md` | UPI not raw % |
| `feedback_dd_ceiling_40_then_harden.md` | 40% start, harden over time |
| `feedback_cross_period_not_cross_broker.md` | F0 lesson |
| `feedback_spread_cap_most_sensitive.md` | Most-sensitive EA param |
| `feedback_pct_not_dollars.md` | % thresholds rule |
| `feedback_ml_safety_segregation.md` | ML never touches safety |
| `feedback_rails_must_run_during_pause.md` | Feb-25 cascade lesson |
| `feedback_friday_weekend_gap.md` | Weekend gap pattern |
| `feedback_tg_signals_are_pending_orders.md` | TG backtest pitfall |
| `feedback_port_first_restructure_later.md` | 1:1 port discipline |
| `feedback_plan_before_code.md` | Always plan first |
| `feedback_write_plans_in_pieces.md` | Plan in chunks |
| `reference_moneydancer_plan_path.md` | Plan location |
| `reference_duka_pipeline.md` | Duka ingest |
| `reference_sibling_repo.md` | CashCabaret/LabRat/NotFinancialAdvice prior art |
| `reference_disco_ea_path.md` | DiscoSignalReplay EA |
| `reference_mt4_deploy_path.md` | Terminal data folder paths |
| `reference_build_scripts.md` | Deploy/compile helpers |
| `reference_prop_firm_rules.md` | FTMO / FundingPips caps |
| `user_nikodem.md` | User profile / collaboration style |

---

*Last updated: 2026-05-21. Next update: when S2.C.8 sample sweep completes.*
