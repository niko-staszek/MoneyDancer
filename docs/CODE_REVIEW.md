# MoneyDancer 2.0 Code Review (2026-05-23)

Full code review of `mt5/2.0/MoneyDancer_2.0/` after pre-live engineering shipped (PL.1-PL.6). 21 `.mqh` + 1 `.mq5` ≈ 6.5k LOC.

Severity tiers:
- **CRITICAL** — data loss / real-money risk / guaranteed wrong behavior
- **IMPORTANT** — latent bug / design smell
- **MINOR** — cleanup / dead code
- **STYLE** — naming / docs / formatting

---

## Fixed in this pass

### CRITICAL — all 4 fixed

| ID | Title | Fix | File |
|---|---|---|---|
| **C1** | `EnforceBasketSL()` ignored regime-aware S2.A.7 thresholds when base `MaxBasketLossPct=0` | Added `any_override` check before short-circuit | `Risk.mqh` |
| **C2** | Dashboard `FinalizeSeriesIfEnded()` left series-active flag stuck when `ShowBasketLabels=false` | Separated state mutation from label drawing | `Dashboard.mqh` |
| **C3** | `Dashboard_Init()` overwrites PL.1-loaded `g_peakEquityEver` | Only set if `<= 0` (loaded value takes precedence) | `Dashboard.mqh` |
| **C4** | `IsMarketCurrentlyClosed()` pre-check was dead code | Deleted; post-attempt error path is the real handler | `Risk.mqh` |

### IMPORTANT — 5 of 11 fixed in this pass

| ID | Title | Fix | File |
|---|---|---|---|
| **I1** | `g_basketSLDayKey` written but never read | Now gates basket-SL counter reset (independent of `g_baseDayKey`) | `Risk.mqh` |
| **I2** | `g_lastPeak`, `g_lastMovePts` write-only | Deleted from Globals + Signal | `Globals.mqh` / `Signal.mqh` |
| **I4** | ScenarioE runner sizing ignores S1.5 equity scaling | `LotsBase` → `ComputeBaseLot()` | `ScenarioE.mqh` |
| **I5** | `EnforceDailyPreClose` only excludes Saturday, not Sunday | Added Sunday (`day_of_week==0`) to weekend guard | `Risk.mqh` |
| **I9** | `EnforceDailyPreClose` conditional mode leaves runners/pyramid open during closed window | If any basket closed via threshold, sweep up runners + pyramid via `CloseAllPositions()` | `Risk.mqh` |
| **I11** | S1.6 doc comment placed above S1.3 function | Moved S1.6 doc to immediately precede `EnforceAllTimeDD` | `Risk.mqh` |

### MINOR — 2 fixed

| ID | Title | Fix | File |
|---|---|---|---|
| **M3** | `ApplyBasketTP` non-series variant — no callers | Deleted | `ScenarioD.mqh` |
| **M4** | `CloseProfitPositions` in Orders.mqh — no callers (Dashboard has its own) | Deleted | `Orders.mqh` |

---

## Deferred (lower priority, larger scope)

### IMPORTANT — 6 deferred

| ID | Title | Why deferred |
|---|---|---|
| I3 | Inconsistent `(ulong)Magic` cast across modules | Fixed in Dashboard.mqh (C3 edit also adjusted casts there); other call sites are 1-line cosmetic |
| I6 | `OnChartEvent` empty but Dashboard has buttons | Stale comment vs valid polling implementation. Polling works; CHARTEVENT wiring is an optimization |
| I7 | `g_minMoveCached` not reset on TF input change | Self-resolves on next bar; only matters if user changes TF mid-run via Modify Expert |
| I8 | `Persistence.SyncPositionsWithTerminal` overwrites stored TP/SL | Needs semantic review — current overwrite is intentional for "current snapshot" use case |
| I10 | News currency hardcoded to USD/EUR/GBP at load | Doesn't matter for XAU; revisit when adding non-USD symbols |
| (PL.4 hook into entry/exit events not done) | Per-event logging added at rail-fire sites; entry/exit covered by MT5 Deals tab |

### MINOR — 10 deferred

M1 (snake_case vs camelCase globals), M2 (separator naming), M5 (basket BE magic 200), M6 (`OnTester` stale), M7 (XAU hardcoded), M8 (Guards ring buffer linear scan), M9-M10 (Dashboard private state), M11 (Webhook startup-hour fire), M12 (CloseAll runner exclusion difference) — all valid but low-leverage relative to live deploy.

### STYLE — all 4 deferred

S1 (doc drift), S2 (mojibake in NewsCalendar), S3 (default Magic warning), S4 (verb-first compliance — already good).

---

## Master plan landmines spot-check

The agent verified the common MT5-port landmines are addressed:
- ulong vs int tickets: consistent
- `PositionSelectByTicket` vs implicit selection: consistent
- `HistoryDealGet*` with `HistorySelect` window: used in ScenarioE + Dashboard
- CTrade fill mode: set in `OrdersInit` via `SetTypeFillingBySymbol`
- `_Symbol` / `_Point` / `_Digits` predefined: used consistently

The agent additionally found 4 critical landmines that the plan Appendix didn't enumerate: C1, C2, C3, I4. **All four are now fixed.**

---

## Performance findings (no code change, documented for future)

The agent surfaced 3 per-tick hot-path concerns:
1. `ScenarioE_ScanNewRunnerClosures` calls `HistorySelect(now-86400, now)` every tick. MT5 caches internally; add 5s throttle if profiling shows it hot.
2. `Dashboard_OnTick → ScanHistoryNewAndUpdatePnLAndMarkers` calls `HistorySelect(now-40d, now)` every tick (early-exits on stale `g_lastHistTotal` but the syscall still fires). Add 1s throttle.
3. Multiple `BasketFloatingPL` / `SumLotsDir` calls per tick each iterate `PositionsTotal()`. ~350 `PositionGetTicket` calls per tick with 50-position basket. Acceptable in practice but consider a per-tick snapshot helper if profiling shows it hot.

None affect correctness; deferred until cent forward live profiling either confirms or refutes the concern.

---

## Backtest invariance

All shipped fixes were designed for backtest invariance. The activate conditions don't apply to STEP backtests:
- C1: STEP ship has `MaxBasketLossPct=8.0` (non-zero) so `any_override` path doesn't change behavior
- C2: STEP ship has `ShowBasketLabels=true` so label was drawn + state cleared (unchanged)
- C3: tester mode skips `LoadRailState`, so `g_peakEquityEver` is always 0 at Dashboard_Init time → fresh-set runs (unchanged)
- C4: dead code removal
- I1: `g_basketSLDayKey` starts -1, first day-tick `dk != -1` triggers reset (same as before)
- I2: removed write-only state, no consumer affected
- I4: STEP ship has `ScenarioE=false` so this branch never runs
- I5: STEP ship has `DailyPreCloseHour=0` so function returns immediately
- I9: same — function returns immediately
- M3, M4: no callers

**Verification result (commit `153fe91`, ran 2026-05-23)**: mar25 H1 cell with fixes = **$1850.91 / 22.18% DD / 1722 trades / PF 1.33** — **BIT-IDENTICAL** to STEP baseline. All 12 fixes confirmed backtest-invariant. The activate conditions don't trip in tester (overrides off, ScenarioE off, DailyPreClose off, persistence off). See `runs/CR_VERIFY-5k-mar25/result.yaml`.

---

## How to use this doc

When fixing more code-review items:
1. Pick from the "Deferred" tables based on what's blocking work
2. Apply the fix, add `CR-<ID>` reference comment in code
3. Update this doc — move item from "Deferred" to "Fixed in this pass"
4. Commit fix + doc update together

Code review is not a one-shot event. Re-run a similar review pass after any significant feature lands (e.g., after S2.C.9 if regime telemetry gets built).
