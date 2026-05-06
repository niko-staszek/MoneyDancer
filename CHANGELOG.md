# Changelog

All notable changes to MoneyDancer (MT4 + MT5) are documented here. Both platforms ship the same version numbers in lockstep.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning is **`MAJOR.MINOR`** — chosen to match the format both MQL4 and MQL5 Market expect in `#property version`. Bug-fix releases (FIX bumps) edit the existing `MAJOR.MINOR` folder in place and document the fix as a sub-bullet under the same heading with a date stamp.

- **MAJOR** — breaking changes (new core mechanic, incompatible `.set` schema)
- **MINOR** — additive features (new inputs default to OFF; old `.set` files still load)
- **FIX**   — bug fixes only, no behavior changes — applied in-place to the MAJOR.MINOR folder

---

## [Unreleased]

_Nothing yet._

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
