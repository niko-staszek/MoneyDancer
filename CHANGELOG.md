# Changelog

All notable changes to MoneyDancer (MT5) are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning is **`MAJOR.MINOR`** — chosen to match the format MQL5 Market expects in `#property version`. Bug-fix releases (FIX bumps) edit the existing `MAJOR.MINOR` folder in place and document the fix as a sub-bullet under the same heading with a date stamp.

- **MAJOR** — breaking changes (new core mechanic, incompatible `.set` schema)
- **MINOR** — additive features (new inputs default to OFF; old `.set` files still load)
- **FIX**   — bug fixes only, no behavior changes — applied in-place to the MAJOR.MINOR folder

> MT4 (`mt4/MoneyDancer_legacy.mq4`) is a single legacy build; not tracked here.

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

  On trigger: `CloseAllPositions()` + pause until next server-time 00:00. Implemented as kill-switch #4 in `Risk.mqh::ApplyDailyRiskControls()`. Reuses existing `g_dayBaseBalance` / `PauseAutoUntilNextDay()` infrastructure — no new globals.

### Compatibility
- `XAUUSD_1.0.set` loads on 1.1 unchanged — new inputs default to OFF, behavior is identical.
- `XAUUSD_1.1.set` adds three keys: `ProfitTargetMode=0`, `ProfitTargetPct=5.0`, `ProfitTargetUsd=100.0`.

---

## [1.0] — 2026-04-24

### Added
- Initial bare 1:1 port of MT4 EA `mt4/MoneyDancer_legacy.mq4` to MT5 modular structure.
- 15 strategy includes (Inputs, Globals, Utils, Persistence, Orders, Slope, Pyramid, Series, Basket, ScenarioD, Risk, ScenarioE, Dashboard stub, Telemetry stub, Signal).
- Three daily kill-switches ported intact: daily profit cap (`MaxDailyProfitPct`), after-hour profit-protect (`AfterThisHour*`), profit-lock floor (`RiskFromCurrentProfit`).
- Position + pyramid state persistence (CSV, MQL5 Files folder).
- Series-ID basket isolation, MA slope cache, tick-burst signal detector.

### Notes
- Frozen reference build. Active development continues in subsequent versions.
- Active project work using MMD clouds, telemetry, and prop-compliance SL lives in the sibling `CashCabaret` repo, not here.
