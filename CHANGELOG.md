# Changelog

All notable changes to MoneyDancer (MT4 + MT5) are documented here. Both platforms ship the same version numbers in lockstep.

> See [docs/HISTORY.md](docs/HISTORY.md) for the full research ledger (iterations, findings, busted hypotheses, queue). CHANGELOG describes *what shipped*; HISTORY describes *why and what we learned*.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning is **`MAJOR.MINOR`** — chosen to match the format both MQL4 and MQL5 Market expect in `#property version`. Bug-fix releases (FIX bumps) edit the existing `MAJOR.MINOR` folder in place and document the fix as a sub-bullet under the same heading with a date stamp.

- **MAJOR** — breaking changes (new core mechanic, incompatible `.set` schema)
- **MINOR** — additive features (new inputs default to OFF; old `.set` files still load)
- **FIX**   — bug fixes only, no behavior changes — applied in-place to the MAJOR.MINOR folder

---

## [Unreleased]

- Variants S3.2c (Pyramid-only during MMD-trend) and S3.2d (pure trend-follow) remain in plan as next iterations if WT shows live deficiencies.

### 3.0 naming refactor (2026-05-24)

**BREAKING for users holding old `.set` files** — 61 inputs renamed to consistent PascalCase. Shipped `.set` files were migrated automatically; user `.set` files need re-export or manual rename.

**Input renames** (61 total):
- camelCase → PascalCase (9): `maPeriod→MAPeriod`, `slopeLookbackBars→SlopeLookbackBars`, `slopeThresholdPts→SlopeThresholdPts`, `strongTrendPts→StrongTrendPts`, `startBe→StartBE`, `lotMultiplier→LotMultiplier`, `lotMultiplierRange→LotMultiplierRange`, `bePoints→BEPoints`, `maxLot→MaxLot`
- PascalCase_underscore → PascalCase (52): all 40 day/slot/HM trading-window inputs (`MonStart1_Hour→MonStart1Hour` etc.), `TP_Points`, `SL_Points`, `MaxBasketDD_Pct`, `MaxEquityDD_Pct`, `RunnerBE_StartPts`, all 7 `MMDPeriod_*` cloud inputs

**Global renames** (22 total): all `g_snake_case` globals renamed to `g_camelCase` for consistency. Internal only — no user-visible impact.

**Verification**: mar25 H1 STEP re-run = bit-identical to baseline ($1850.91 / 22.18% DD / 1722 trades). Pure rename, no functional change.

**Tooling**: `scripts/_naming_refactor.py` applies code renames; `scripts/_rename_set_file.py` migrates `.set` files. Both word-boundary-safe via regex.

**Migration for users**:
- If your `.set` file was exported from MD ≤ 2.0 ship: open in text editor, apply the renames above. OR re-export from the EA after upgrade.
- Inputs not in the rename table (`PriceStep`, `BurstTicks`, `MinMovePoints`, `MaxSpreadPts`, `LotsBase`, `LotsBasePerThousand`, `MaxBasketLossPct`, `MaxAllTimeDDPct`, `FridayFlattenHour`, etc.) are unchanged.

See `docs/NAMING.md` for full rename table + rationale.

### Added — S2.C.8 Daily pre-close flatten (2026-05-21)
- **New inputs** (Inputs.mqh, default OFF): `DailyPreCloseHour` (recommend 23), `DailyPreCloseMinute` (recommend 55), `DailyResumeHour` (recommend 1). Mirror of `FridayFlattenHour` but daily — closes all positions before the XAU daily-break window (~00:00 UTC), resumes next morning.
- **`EnforceDailyPreClose()` function** (Risk.mqh) — fires once per day after `DailyPreCloseHour:DailyPreCloseMinute`, closes all positions, pauses until next day at `DailyResumeHour:00`. Skips Saturday. Defers to S1.7 Friday flatten and S1.3 daily-loss kill via the existing `IsAutoPaused()` short-circuit.
- **`EnforceDailyPreClose()` wired in OnTick** (MoneyDancer_2.0.mq5) right after `EnforceFridayFlatten()`. Compiles clean.
- **Motivation**: may25-H2's 40.48% DD breach happened because basket bled during the ~30-min XAU market-closed pocket where the basket-SL rail couldn't fire. S5.5f handles the *symptom* (rail spinning); S2.C.8 prevents the *cause* (basket open during the closed window). Test variant .set: `mt5/2.0/MoneyDancer_2.0/presets/XAUUSD_2.0_STEP_PRECLOSE_test.set`.

### Added — Iteration round 1 (2026-05-18)
- **`PyramidFixedTPPts` input** (Pyramid.mqh) — when > 0, pyramid positions get a fixed TP at entry instead of legacy BUILDING (TP=0) / COASTING (TP=lastTrigger). Default 0 = legacy behavior preserved. Compiled clean.
- **3 variants tested and rejected**: WTP (static pyramid — tester timeout), WT5 (basket SL 5% — full sweep 41% lower net than WT), WTDP (PyramidFixedTPPts=150 — dec25 DD breach 40%). See `runs/decisions/2026-05-18-iteration-round-1.md`.

### Added — Iteration round 2 (2026-05-19) — Adaptive MinMove framework (S2.A first slice)
- **`ENUM_MINMOVE_MODE` + 5 new inputs** (Inputs.mqh): `MinMoveAdaptiveMode` (FIXED/ATR_INVERSE/ATR_LINEAR), `MinMoveATRTimeframe`, `MinMoveATRPeriod`, `MinMoveATRConstant`, `MinMoveATRMult`, `MinMovePointsMin`, `MinMovePointsMax`. Default = FIXED (preserves WT ship behavior).
- **`EffectiveMinMovePoints()` function** (Utils.mqh) — caches ATR per-bar, computes adaptive value, clamps to [Min, Max].
- **Signal.mqh wired** to use `EffectiveMinMovePoints()` in burst detector. Compiles clean.
- **Per-cell investigation finding**: weak cells have identical 70% win rate to monster cells but PF crashes to ~1.0 (vs ~1.5 in monsters). Driver is entry-quality filter, not exit logic.
- **Iterations tested**: static MM30/MM40, adaptive INVERSE C=1500 vs C=1000. Each helps some cells while breaking others. Conclusion: WT remains the ship; richer S2.A framework needed for true universal improvement; no further backtest iteration until cent live data is collected. See `runs/decisions/2026-05-19-iteration-round-2.md`.

### Status
- **WT confirmed as ship config** (17/17 positive backtest, +63.8%/cell, +6.38%/day). No code or .set changes affecting ship behavior — adaptive MinMove is opt-in via `MinMoveAdaptiveMode != FIXED`.

### Added — H2 OOS validation + S5.5f market-closed fix (2026-05-21)
- **H2 second-half-of-month OOS sweep on STEP** (16 cells, may26-H2 has no Duka data): 13/16 positive (81%), sum $66,345 (85% of matched H1 sum), mean +82.9%/cell, max DD 40.48% (may25-H2 — breaches 40% S1.6 ceiling).
- **Combined H1 + H2 = 32 cells**: 28/32 positive (87.5%), total $144,314, mean +90.2%/cell. STEP confirmed ship-ready with realistic OOS degradation (~15%).
- **S5.5f code fix**: basket-SL rail (`Risk.mqh::EnforceBasketSL_Dir`) now detects market-closed status during XAU daily-break (~00:00-01:00 UTC) and defers retries instead of banging the gate ~22,000 times per cell. New globals `g_basketSLMarketClosedLogged_{Buy,Sell}` for 5-min throttled logging. New helper `IsMarketCurrentlyClosed()`. Error-code-aware close-fail handling.
- **S5.5f empirical**: bit-identical P&L to buggy version on may25-H2 (+$6,490 / 40.48% DD / 3,418 trades). Fix is pure code hygiene + live broker connection safety. Basket bleeds during closed hour regardless of retry count.
- **Implication**: the may25-H2 40.48% DD is architectural (basket-vs-market dynamics during XAU daily-break), not bug-induced. Potential future fix: daily pre-close flatten (like `FridayFlattenHour` but daily).
- See `runs/decisions/2.0-release-and-validation.md` for full table.

### Added — Ship config upgrade: WT → STEP (2026-05-21)
- **New ship .set**: `mt5/2.0/MoneyDancer_2.0/presets/XAUUSD_2.0_STEP_ship.set`. WT_ship preserved for history.
- **What changed**: `StepPoints` 120 → 80 (martingale gate triggers earlier) + `MinOrderDistancePts` 40 → 60 (positions require more spacing). All other inputs identical to WT.
- **17-month sweep result**: total net $82,120 vs WT $54,219 = **+51.5% improvement**. Mean per cell +96.6% (was +63.8%). Daily-avg +9.66%/day (was +6.38%).
- **Coverage**: 16/17 positive (feb25 -17.8% is the only loss). Max DD 37.79% (feb25, +0.7pp over WT max).
- **Big wins**: dec25 +115pp, mar26 +152pp, feb26 +115pp, apr26 +74pp. May25 went from +4% to +80% (+76pp).
- **Cost**: feb25 went from +25% to -18% (-43pp). Investigated via isolation — `StepPoints=80` is both the win driver AND the feb25 regression cause. No knob separation preserves wins without the cost.
- **Investigation memo**: see `runs/decisions/2.0-release-and-validation.md` and the C.3 sample/sweep/isolation results in `runs/BM-{TIGHT,WIDE,STEP}-5k-*`, `runs/STEP-5k-*`, `runs/ISO-{A,B,C}-feb25`, `runs/MD60-5k-*`.

### Fix — S5.5a recovery-add lot asymmetry (2026-05-20)
- **Signal.mqh:321** — `MartingaleScenarioDAdd()` recovery branch (`!moveAway`, comment `|DB`) now uses `FirstBasketLotSeries(basketDir, seriesCmt)` instead of `ComputeBaseLot()`.
- **Why**: when basket was drowning, `ComputeBaseLot()` returned a shrunken lot based on current (depressed) equity, weakening the basket BE pull on recovery adds. The martingale `|D=N` branch already used `FirstBasketLotSeries` for consistency; now `|DB` matches.
- **Fallback**: if `FirstBasketLotSeries` returns 0 (no positions), falls back to `ComputeBaseLot()`.
- **Validated**: isolated mar26 test produced bit-identical P&L to WT baseline (+$2980.62, 5447 trades). DB recovery-add branch rarely fires under WT, so practical effect is minimal — fix is for hygiene/correctness.

### Added — Iteration round 4 (2026-05-20) — Path-dependent basket-handling options
- **`MaxBasketLossPctRange` / `MaxBasketLossPctTrendWith` / `MaxBasketLossPctTrendAgainst`** (Inputs.mqh + `EffectiveBasketLossPct()` in Basket.mqh) — regime-direction-aware basket SL thresholds. Defaults 0 = single legacy threshold.
- **`BlockDOnAdverseMMD`** (Inputs.mqh + gate in Signal.mqh ScenarioD path) — pauses martingale adds when MMD opposes basket dir. Default false. Wired directly in ScenarioD (not via TrendBlocksD) to also work when ScenarioE is off.
- **`UseMMDAdverseGateForE`** (Inputs.mqh + gate in ScenarioE.mqh::CheckShouldActivateE) — only activate hedge runner when MMD opposes basket.
- **Empirical findings**: Option 1 nets -55pp on 5 cells at gentler thresholds (8/10/6) and -90pp at aggressive (8/12/4) — clips winning monsters more than saves losers. Options 2 & 3 produce P&L IDENTICAL to WT — targeted conditions don't fire often enough under WT's already-direction-aware operation.
- **Conclusion**: WT really is the path-level ceiling. Backtest-only iteration exhausted across 4 rounds (variant attempts, adaptive params, discriminator search, path-dependent options). Next signal must come from cent forward test. See `runs/decisions/2026-05-20-iteration-round-4-path-dependent.md`.

### Added — Iteration round 3 (2026-05-19) — Adaptive params framework expansion
- **`MinATRPointsForEntry`** (Inputs.mqh) — ATR-floor entry gate. Wired via `ATRGateBlocks()` in `Signal.mqh::HandleSignal`. Default 0 = OFF.
- **`LotMultRange` + `LotMultTrend`** (Inputs.mqh) — regime-aware lot multiplier applied in `ComputeBaseLot()`. Default 1.0 / 1.0 = WT behavior. Only active when `UseMMDClassifier=true`.
- **`CurrentATRPoints()`** helper (Utils.mqh) — reusable ATR cache for adaptive gates.
- Forward declaration of `MMD_RegimeSimple()` in Utils.mqh to handle include order.
- **Empirical findings**:
  - ATR doesn't discriminate weak from monster cells (`runs/decisions/2026-05-19-discriminator-search.md`). S2.A.2 dropped from plan.
  - Burst frequency, tick density, follow-through % don't discriminate either. Jan26 (worst, +0.6%) and Dec25 (monster, +191%) have nearly identical aggregate features.
  - S2.A.3 regime-aware lot (LotMultTrend=0.5) net -8.3% on full 17-month sweep — winning trends (apr25) lose as much as DDs improve.
- **Conclusion**: WT is the backtest ceiling for one-knob-at-a-time iteration. Variance is path-dependent, not feature-aggregate. Next signal must come from live trading. See `runs/decisions/2026-05-19-iteration-round-3-final.md`.

### Added — Sprint 2 / S3.2b (2026-05-18)
- **S3.2b WITH_TREND-only grid** — new `ENUM_REGIME_TREND_MODE` + input `RegimeTrendMode` (default `BLOCK_BOTH` = previous behavior). When set to `WITH_TREND` and `UseMMDClassifier=true`, allows grid entries only in the MMD-flagged trend direction during trend regimes. Range regimes unchanged. New function `RegimeBlocksEntryDir(int signalDir)` in `Regime.mqh`; replaces the boolean `RegimeBlocksGridEntries()` in Signal.mqh's gate.
- **Validation**: full 17-month sweep (Jan 2025 → May 2026, 2-week cells, $5k). WT vs S17: **17/17 vs 12/17 positive, +63.8% vs +31.3% mean / cell, +6.38% vs +3.13%/day, worst +0.6% vs -19.8%, total net 2.04×.** Max DD up 3.4pp (37.1% vs 33.7%). Edge per unit of DD nearly doubled. WT is the new ship.
- **Ship .set updated**: `mt5/2.0/MoneyDancer_2.0/presets/XAUUSD_2.0_S17_ship.set` now sets `RegimeTrendMode=1`.

---

## [2.0] — 2026-05-17

**Sprint 1 (full) + Sprint 2 entry.** A major release driven by the F0 catastrophe (5k-heavy-grid returned -429% in 6 days, Apr 2026) and the Feb-2025 OOS catastrophe (-101% account blow when day-pause silenced the rails for 22 hours). All rails **default OFF** so a 1.x `.set` loaded on 2.0 produces identical behavior; opt-in via the corresponding `Use*`/numeric inputs.

Why MAJOR: 1.x freezes at 3 rails (S1.0+S1.6+S3.2). 2.0 ships a full risk-management stack (7 Sprint-1 rails + 2 Sprint-2 entries) plus the bugfixes that the Feb-2025 catastrophe exposed. The two lineages will diverge; future 1.x bumps add unrelated minor features.

### Added — Sprint 1 rails (in Risk.mqh / Guards.mqh / NewsCalendar.mqh)
- **S1.1 News-calendar blackout** — new `Include/NewsCalendar.mqh`. Tries MT5's native `CalendarValueHistory()` first (works in live; may be empty in tester sandbox). On 0 events, falls back to a hardcoded 140-event table generated from `data/calendar/{2025,2026}_full.csv` (USD/EUR/GBP FOMC/NFP/CPI/PCE/ECB/BoE). Inputs: `UseNewsBlackout` (default OFF), `NewsBlackoutPreMin` (30), `NewsBlackoutPostMin` (15), `NewsBlackoutTier2` (false).
- **S1.2 % thresholds** — new `AfterThisHourMinProfitPct` / `AfterThisHourMaxFloatingLossPct` override the legacy USD values when >0. Makes the same `.set` portable across 5k/100k/200k accounts.
- **S1.3 Intraday daily-loss kill** — new input `MaxDailyLossPct` (default 0=OFF; recommend 15). When today's realized+floating loss vs daily baseline ≥ %, close all + pause until next 00:00. Complements S1.6 (all-time) and the existing `MaxDailyProfitPct` (per-day cap).
- **S1.4 Spread-spike circuit breaker** — new `Include/Guards.mqh` ring-buffer tracks per-tick spread for the last `SpreadSpikeWindowSec` (default 300) seconds. Inputs: `UseSpreadSpikeGuard`, `SpreadSpikeMultK` (3.0), `SpreadSpikeMinSamples` (30). When current spread > median × k, block new entries. Targets rollover/news-edge spikes that static `MaxSpreadPts` misses.
- **S1.5 Auto-scaled LotsBase** — new input `LotsBasePerThousand` (default 0=OFF). When >0, `LotsBase = (equity/1000) × LotsBasePerThousand`, then broker-step-clamped. Same `.set` scales across 5k→100k→200k. `LotsBasePerThousand=0.002` gives 0.01@5k, 0.20@100k, 0.40@200k.
- **S1.7 Friday end-of-week flatten** — new input `FridayFlattenHour` (default 0=OFF; recommend 20). After this hour Friday server-time: close every position and pause until Monday 00:00. Targets the weekend-gap losses (4 of 5 worst OOS-2025 drawdowns started on a Friday and bled through the weekend).

### Added — Sprint 2 entry (in Guards.mqh / Regime.mqh / MMD.mqh)
- **S2.0 Hour-of-day blocklist** — new input `HourBlockList` (CSV list of server hours to skip, e.g. `"18,23"`). Lifted directly from S2.0 hour/DOW analysis: H18 and H23 are the only hours with negative mean P&L across 36,268 closed deals.
- **S3.2a MMD multi-cloud classifier** — new `Include/MMD.mqh` lifted from CashCabaret. Seven SMA/EMA cloud pairs at periods {12, 48, 144, 288, 720, 1440, 3456}. Toggled by `UseMMDClassifier` (default false). When true + `RegimeMode=HARD`, the ADX gate is replaced with `MMD_RegimeSimple()` returning bull/range/bear.

### Bugfixes (Feb-2025 OOS catastrophe)
- **Rails no longer respect `IsAutoPaused()`.** Pause blocks NEW entries (Signal.mqh's gate); rails (`EnforceBasketSL`, `EnforceAllTimeDD`) must keep monitoring existing positions every tick. The Feb-2025 catastrophe (-101% account blow) happened because rails went idle for 22 hours during pause while open positions bled.
- **Series-close failure escalates to CloseAll**. When `CloseSeriesBasketPositions_S10` returns 0 (close failed — broker rejection / margin issue / etc.), the EA now falls through to `CloseAllPositions()` on the same tick. If even that returns 0, log CRITICAL and do NOT increment the daily SL counter (which previously triggered a spurious day-pause).

### New modules (all in `Include/`)
- `MMD.mqh` — 7-cloud regime classifier (lazy-init handles, custom-symbol-safe)
- `Regime.mqh` — ADX + MMD selector (extended from 1.2)
- `NewsCalendar.mqh` — native-first calendar with hardcoded fallback
- `Guards.mqh` — S1.4 spread-spike ring + S2.0 hour-block parser

### Compatibility
- `XAUUSD_1.1.set` and `XAUUSD_1.2.set` both load unchanged on 2.0 — all new inputs default OFF, behavior is identical.
- `XAUUSD_2.0.set` ships the recommended Sprint-1-rails-ON baseline (TBD after validation).

### Platforms
- **MT5** (`mt5/2.0/MoneyDancer_2.0/`) — released 2026-05-17. MT5-only (MT4 stays at 1.1).

### Compile status
`MetaEditor64 /compile` → 0 errors, 0 warnings.

---

## [1.2] — 2026-05-15

Sprint 1 critical-path survival rails (motivated by the F0 Apr-2026 OOS catastrophe: 5k-heavy-grid returned -429% in 6 days under a trend regime that 1.1 had no defense against). The original 2026-05-15 validated cut: S1.0 + S1.6 + S3.2. Later 2026-05-17 work (S1.1, S1.2, S1.3, S1.4, S1.5, S1.7, S2.0, S3.2a, bugfixes) moved to 2.0.

- 2026-05-17 FIX backport: rails no longer respect `IsAutoPaused()`, and `CloseSeriesBasketPositions` failure escalates to `CloseAllPositions()`. Same fix as 2.0 — applied here so the 1.2 rails behave correctly in the Feb-2025-style edge case.

### 2026-05-15: Initial Sprint 1 cut (S1.0 + S1.6 + S3.2)

#### Added — S1.0 Per-basket equity stop-loss
- Close every position in a series when its floating loss reaches a configurable share of the equity at series open. Series is marked dead so Scenario E does not promote leftover positions to runners; a fresh series can start on the next signal (subject to the day pause).
- After `MaxBasketSLPerDay` triggers in a server day, the EA closes all open positions and pauses until the next 00:00 (resets at the existing daily baseline boundary).
- Runs in `OnTick()` immediately **after** `ApplyDailyRiskControls()` and **before** Scenario E bookkeeping so a basket that hits the rail is closed *before* any runner can be spawned.
- Pyramid + runner tickets are excluded from the basket close. The daily-limit kill closes everything.
- Telemetry: `[S1.0] basket SL fired: ...` Print on every trigger.

#### Added — S1.6 All-time peak-to-trough DD trailing kill
- Tracks running max equity since EA start. When `(peak − current) / peak × 100 >= MaxAllTimeDDPct`, the EA closes all positions and pauses until the next 00:00.
- Runs in `OnTick()` immediately after S1.0 and before Scenario E.
- Complementary to the existing intra-day `MaxDailyProfitPct` cap: S1.6 is the all-time floor; the daily cap is the per-day ceiling.
- Caveat: peak resets to current equity on EA restart (no on-disk persistence yet — acceptable for backtest; live restarts will reset the rail once).
- Telemetry: `[S1.6] all-time DD kill: peak=... eq=... dd=...% limit=...%` on trigger.

#### Added — S3.2 Regime gate (rule-based first cut, ADX)
- Classifies the current bar as TREND vs RANGE/CHOP via `iADX(_Symbol, RegimeTimeframe, RegimePeriod)` cached per-bar.
- In `HARD` mode, `HandleSignal()` short-circuits when ADX ≥ `RegimeAdxThresh` — no new grid entries (initial or martingale). Pyramid is unaffected (it runs from `PyramidManage()` on its own slope filter, which is the intended trend-following lane).
- `SOFT` mode is a telemetry-only stub for future logging; behaves like OFF for now.
- A later story (`S3.2a`) will replace the ADX rule with the MMD multi-cloud classifier lifted from CashCabaret.

#### New inputs (all default OFF)
- `MaxBasketLossPct` (default `0.0`; recommend `8.0` once validated)
- `MaxBasketSLPerDay` (default `2`)
- `MaxAllTimeDDPct` (default `0.0`; recommend `40.0` then harden)
- `RegimeMode` (default `REGIME_OFF`)
- `RegimeAdxThresh` (default `30`)
- `RegimePeriod` (default `14`)
- `RegimeTimeframe` (default `PERIOD_M15`)

#### New file
- `Include/Regime.mqh` — ADX wrapper + `RegimeBlocksGridEntries()` accessor. Slots into the include chain after Slope, before Pyramid.

#### Platforms
- **MT5** (`mt5/1.2/MoneyDancer_1.2/`) — released 2026-05-15. MT5-only.

#### Compatibility
- `XAUUSD_1.1.set` loads on 1.2 unchanged — all new inputs default to OFF, behavior is identical.
- `XAUUSD_1.2.set` adds seven keys (see above). Recommended Sprint-1 baseline values: `MaxBasketLossPct=8.0`, `MaxBasketSLPerDay=2`, `MaxAllTimeDDPct=40.0`, `RegimeMode=2` (HARD), `RegimeAdxThresh=30`.

---

## [1.1] — 2026-05-05

### Added
- **Total Profit Target kill-switch** — stops trading once today's *earned + floating* P/L hits a configurable threshold. Mode dropdown (`ProfitTargetMode`) selects between:
  - `0` — Off (default; behaves identically to 1.0)
  - `1` — Percentage of daily baseline balance (`ProfitTargetPct`, default `5.0`)
  - `2` — Fixed USD amount (`ProfitTargetUsd`, default `100.0`)

  On trigger: closes all positions/orders + pauses until next server-time 00:00. Implemented as kill-switch #4 in `ApplyDailyRiskControls()`. Reuses existing `g_dayBaseBalance` / `PauseAutoUntilNextDay()` infrastructure — no new globals.

### Platforms
- **MT5** (modular, `mt5/1.1/MoneyDancer_1.1/`) — released 2026-05-05.
- **MT4** (single-file, `mt4/1.1/MoneyDancer_1.1.mq4`) — ported 2026-05-06. Behavior identical; uses `AccountBalance()` / `AccountEquity()` / `CloseAllOrders()` instead of MT5 equivalents.

### Compatibility
- `XAUUSD_1.0.set` loads on 1.1 unchanged — new inputs default to OFF, behavior is identical.
- `XAUUSD_1.1.set` adds three keys: `ProfitTargetMode=0`, `ProfitTargetPct=5.0`, `ProfitTargetUsd=100.0`.
- The same `.set` file works for both MT4 and MT5 1.1 (input names match exactly).

---

## [1.0] — 2026-04-24

### Added
- **MT4** (`mt4/1.0/MoneyDancer_1.0.mq4`) — cleaned MT4 baseline. Was originally `mt4/MoneyDancer_legacy.mq4`; renamed to `1.0` on 2026-05-06 when the versioning scheme was extended to MT4. Cleaning vs. original: removed AXI broker lock, removed license gating, translated Polish → English, rebranded author tag to JoJo. **No logic changes.**
- **MT5** (`mt5/1.0/MoneyDancer_1.0/`) — initial bare 1:1 port of MT4 baseline to MT5 modular structure. 15 strategy includes (Inputs, Globals, Utils, Persistence, Orders, Slope, Pyramid, Series, Basket, ScenarioD, Risk, ScenarioE, Dashboard stub, Telemetry stub, Signal).
- Three daily kill-switches present on both platforms: daily profit cap (`MaxDailyProfitPct`), after-hour profit-protect (`AfterThisHour*`), profit-lock floor (`RiskFromCurrentProfit`).
- Position + pyramid state persistence (CSV).
- Series-ID basket isolation, MA slope cache, tick-burst signal detector.

### Notes
- Frozen baseline. Active development continues in subsequent versions.
- Active research (MMD clouds, telemetry, prop-compliance SL) lives in the sibling `CashCabaret` repo, not here.
