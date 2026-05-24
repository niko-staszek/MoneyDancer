# MoneyDancer Naming Conventions

Codified naming rules. Mixed conventions exist for historical reasons (1:1 MT4 port preserved legacy names); this doc states the **target** for new code and flags **deferred refactors** that would break user `.set` files.

---

## Current state (post code-review 2026-05-23)

### Input parameters (`Inputs.mqh`)

| Convention | Count | Examples | Status |
|---|---|---|---|
| **PascalCase** (target) | ~90% | `UseTradingHours`, `MaxBasketLossPct`, `RegimeMode`, `Magic` | majority — keep |
| **camelCase** (legacy MT4) | ~15 | `maPeriod`, `slopeLookbackBars`, `startBe`, `lotMultiplier`, `bePoints`, `maxLot`, `lotMultiplierRange` | **deferred** — renaming breaks `.set` files |
| **PascalCase_with_underscore** (legacy MT4) | ~10 | `MonStart1_Hour`, `TP_Points`, `SL_Points`, `MaxBasketDD_Pct`, `RunnerBE_StartPts` | **deferred** — renaming breaks `.set` files |
| **Mixed `XxxYyy_ZZZ`** | 7 | `MMDPeriod_Red`, `MMDPeriod_Orange`, etc. | acceptable (domain-specific prefix) |

### Separator labels (visible in MT5 input dialog)

| Pattern | Count | Examples |
|---|---|---|
| `__sec_xxx__` (target) | 8 | `__sec_working_hours__`, `__sec_loss_control__` |
| `__xxx_sep__` (legacy) | 4 | `__risk_sep__`, `__profit_target_sep__`, `__dash_sep__`, `__mark_sep__` |

**Safe to rename** — separators are UI labels only, not part of the strategy contract. **Done in this pass.**

### Global variables (`Globals.mqh`)

| Convention | Examples | Status |
|---|---|---|
| **`g_camelCase`** (target) | `g_basketSLToday`, `g_buySeriesActive`, `g_peakEquityEver`, `g_tradePauseUntil` | majority — keep |
| **`g_snake_case`** (legacy CashCabaret-style) | `g_mmd_periods[]`, `g_news_events[]`, `g_spread_t[]`, `g_hour_blocked[]`, `g_tele_file` | **deferred** — renaming is mechanical but cross-cuts many modules |

### Functions

| Style | Convention | Examples |
|---|---|---|
| Module operations | `Module_Action()` or `ModuleAction()` | `Telemetry_Init`, `Telemetry_LogEvent`, `MMD_Init`, `Slope_Init`, `News_Init`, `Guards_Init`, `Dashboard_Init` |
| Predicates | `IsXxx()` | `IsMine`, `IsRunner`, `IsAutoPaused`, `IsRetcodeTerminal` |
| Computations | `ComputeXxx()` / `CalcXxx()` | `ComputeBaseLot`, `CalcGroupBE`, `EffectiveBasketLossPct` |
| Side-effects | `Verb*()` | `Enforce*`, `Sync*`, `Mark*`, `Apply*`, `Open*`, `Close*`, `Save*`, `Load*` |

Function naming is **consistent and clear**. No deferred work here.

### Module / file naming

`Module.mqh` PascalCase. Consistent across the codebase (Risk, Basket, Series, Pyramid, ScenarioD/E, Dashboard, Telemetry, NewsCalendar, Guards, Signal, RailStatePersist, SymbolSpec, Webhook).

---

## Deferred refactors

These are **acknowledged but not fixed** because the risk/reward is unfavorable right now:

### Legacy camelCase inputs (~15 fields)

Examples: `maPeriod`, `slopeLookbackBars`, `slopeThresholdPts`, `strongTrendPts`, `startBe`, `lotMultiplier`, `lotMultiplierRange`, `bePoints`, `maxLot`.

**Why deferred**: Renaming changes the `.set` file schema. Every user-saved `.set` file (including our shipped `XAUUSD_2.0_STEP_ship.set`) would silently load defaults for renamed inputs after a rename. The strategic damage is real money on a wrong config.

**Future refactor path**: when we cut a `3.0` MAJOR version with a deliberate breaking-change bump, rename and ship migration guide.

### Legacy PascalCase_underscore inputs (~10 fields)

Examples: `MonStart1_Hour`, `TP_Points`, `SL_Points`, `MaxBasketDD_Pct`, `MaxEquityDD_Pct`, `RunnerBE_StartPts`.

**Why deferred**: Same — breaks `.set` files. Same path: bump to 3.0 to consolidate.

### Snake-case global variables (~10 vars)

`g_mmd_periods[]`, `g_mmd_hSMA[]`, `g_mmd_hEMA[]`, `g_news_events[]`, `g_spread_t[]`, `g_spread_v[]`, `g_hour_blocked[]`, `g_tele_file`, `g_tele_dayKey`, `g_webhook_lastPushDayKey`.

**Why deferred**: All purely internal; refactor is mechanical (~30 min) but cross-cuts 6 modules. Low risk but currently no behavior payoff. Park as a `cleanup/naming` ticket; do when next touching one of those modules anyway.

---

## Standards going forward

When adding NEW code:

1. **Inputs**: PascalCase, no underscores. E.g., `DailyPreCloseHour`, `WebhookEnabled`. ✓ (PL.1-PL.5 followed this.)
2. **Separator inputs**: `__sec_xxx__`. ✓ (Done in this pass.)
3. **Globals**: `g_camelCase`. E.g., `g_webhook_lastPushDayKey` should have been `g_webhookLastPushDayKey`. Fixed in PL.5 code revision below.
4. **Functions**: `Module_Action()` for module operations, `Verb*()` for actions, `IsXxx()` for predicates, `ComputeXxx`/`CalcXxx` for pure calculations.
5. **Files**: `PascalCase.mqh`.
6. **Magic numbers in inputs**: use descriptive constants or named inputs, not bare integers. Document in a header comment if a hardcoded value is required.

---

## Naming-related issues from the CR pass

| ID | Issue | Status |
|---|---|---|
| CR-M1 | `g_snake_case` vs `g_camelCase` inconsistent | Deferred (see above) |
| CR-M2 | Separator labels inconsistent (`__sec_xxx__` vs `__xxx_sep__`) | **Fixed this pass** (all renamed to `__sec_xxx__`) |
| CR-S1 | Doc drift (phase A2 references) | Deferred (cosmetic) |
| CR-S3 | Default `Magic=21010` warning needed | Deferred (will document in runbook instead) |
| CR-S4 | Verb-first function names | ✓ Already compliant |

---

## How to use this doc

Before adding a new input, global, or function — check this doc for the target convention. If a legacy name conflicts with the target, follow the **legacy** convention if you're modifying existing API surface, **target** convention if you're adding NEW code.
