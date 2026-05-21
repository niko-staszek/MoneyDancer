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
| **Last code change** | `17150ff` — "add S2.C.8 daily pre-close flatten (path 2)" (in-test) |
| **32-cell validation** | H1 16 cells + H2 OOS 16 cells. 28/32 positive (87.5%). Total $144,314 on $5k baseline (× 32 cells). Mean +90.2% / cell. Max DD 40.48% (may25-H2). |
| **Daily-avg backtest** | +9.66% / day H1; +8.21% / day H2. Live decay expected 40-50% → realistic 4-5% / day target. |
| **Blocking next step** | S5.5e cent-account forward test — user opens RoboForex Pro-Cent demo with $1k real, deploys STEP .set, monitors 30-60 days. |

### What's open (next code/test work)

| ID | Description | Status | Task # |
|---|---|---|---|
| S2.C.8 | Daily pre-close flatten (XAU daily-break safety) | in-progress (sample running) | #46 |
| S2.C.9 | Per-DOW × per-regime hour P&L map | planned | #47 |
| S2.C.4 | Martingale shape sample (startBe=3, MaxOrdersDir=30) | designed, never run | #48 |
| S3.2c | PYRAMID_ONLY during MMD-trend | designed, never tested | #49 |
| S3.2d | PURE_TREND_FOLLOW (stretch) | parked | #50 |
| S5.5b | Max-lot ceiling discovery per broker | research | #20 |
| S5.5c | Regime-aware base lot scaling (LotMultRange/Trend) | designed, never run | #51 |
| S5.5d | Equity-tier scaling | deferred until cent forward | n/a |
| S5.5e | **Cent-account forward test** | **blocked on user** | #19 |

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

**Round 3 (cutoff=22:00 UTC, conditional close on loss ≥ 1% equity) — in progress.** Asymmetric: only flatten *losing* baskets at the cutoff; let winning baskets run. Implementation: new input `DailyPreCloseLossThresholdPct` + per-direction `BasketFloatingPL(dir,false)` check + `CloseSeriesBasketPositions_S10` per direction if threshold met. Compiled clean.

**Decision memo**: pending — `runs/decisions/2026-05-21-s2c8-daily-preclose.md` (write after round 3 completes)

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
