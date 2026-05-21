# mt5/ — MT5 versioned releases

Each subfolder under `mt5/` is a self-contained release of the EA, named **`MAJOR.MINOR`** (matches MQL5 Market's `#property version` format). Older releases stay frozen; new minor/major features land in new folders. FIX bumps update the existing folder in place and are documented in [`../CHANGELOG.md`](../CHANGELOG.md).

## Releases

| Version | Status | Folder                          | What's new                                                                |
|---------|--------|---------------------------------|---------------------------------------------------------------------------|
| 1.0     | Frozen | `1.0/MoneyDancer_1.0/`          | Bare 1:1 MT4→MT5 port. Three daily kill-switches.                         |
| 1.1     | Frozen | `1.1/MoneyDancer_1.1/`          | Adds **Total Profit Target** kill-switch (% of baseline OR fixed USD).    |
| 1.2     | Frozen | `1.2/MoneyDancer_1.2/`          | Initial 3 Sprint-1 rails (S1.0 basket-SL + S1.6 all-time DD + S3.2 ADX regime); + bugfix backport from 2.0. |
| 2.0     | Active | `2.0/MoneyDancer_2.0/`          | Full Sprint 1 (7 rails) + Sprint 2 entries (hour-block + MMD regime). See below. |

Each release ships with:
- `MoneyDancer_<ver>.mq5` — main EA
- `Include/` — strategy modules
- `presets/` — example `.set` files for that version

Both releases can be deployed to the same MT5 terminal simultaneously — they appear as distinct entries in Navigator.

## 1.1 highlight: Total Profit Target

A 4th daily kill-switch. Stops trading once today's **realized + floating** P/L hits a target, then pauses until next server-time 00:00 (same daily-reset behavior as the existing locks). Selectable mode in `.set` / inputs:

```
ProfitTargetMode=0      ; 0=Off, 1=Percentage of baseline, 2=Fixed USD amount
ProfitTargetPct=5.0     ; used when Mode=1
ProfitTargetUsd=100.0   ; used when Mode=2
```

Default is `Mode=0` (off) — a 1.0 `.set` file loaded on 1.1 produces identical behavior.

## 1.2 highlights: initial Sprint 1 cut (3 rails)

Motivated by the F0 Apr-2026 catastrophe (5k-heavy-grid: +88% Jan range → −429% Apr trend in 6 days). The 1.x lineage stays small; full Sprint 1 + Sprint 2 lives in 2.0.

- **S1.0** per-basket equity SL (with close-failure escalation to CloseAll, backported from 2.0)
- **S1.6** all-time peak-to-trough DD trailing kill
- **S3.2** ADX regime gate

All default OFF — a 1.1 `.set` loaded on 1.2 behaves identically.

## 2.0 highlights: full Sprint 1 + Sprint 2 entry

Motivated by the Feb-2025 OOS catastrophe (-101% account blow when day-pause silenced the rails for 22 hours) and the structural finding that 4 of 5 worst OOS-2025 drawdowns started on a Friday and bled through the weekend.

### Sprint 1 rails (Risk.mqh / Guards.mqh / NewsCalendar.mqh)
- **S1.0** per-basket equity SL (close-failure escalation)
- **S1.1** news-calendar blackout (MT5 native + 140 fallback events)
- **S1.2** % thresholds (scale-portable)
- **S1.3** intraday daily-loss kill
- **S1.4** rolling-spread spike circuit breaker
- **S1.5** auto-scaled LotsBase (`equity/1000 × LotsBasePerThousand`)
- **S1.6** all-time peak-to-trough DD trailing kill
- **S1.7** Friday end-of-week flatten (close Fri 20:00, pause to Mon 00:00)

### Sprint 2 entry
- **S2.0** hour-block list (`HourBlockList="18,23"` from H18/H23 negative-hour analysis)
- **S3.2** ADX regime gate
- **S3.2a** MMD multi-cloud regime classifier (lifted from CashCabaret)

### Critical bugfixes baked in
- Rails no longer respect `IsAutoPaused()`. Pause blocks new entries; existing positions still get checked every tick.
- Series-close failure escalates to `CloseAllPositions()` on the same tick and does NOT increment the daily SL counter.

### S1.0 — Per-basket equity SL
Reference equity is snapshotted when a series opens. When floating loss reaches `MaxBasketLossPct` of that snapshot, every basket position in the series is closed. The series is marked dead so Scenario E does not spawn runners on it; a fresh series can start on the next signal. After `MaxBasketSLPerDay` triggers in a server day the EA flattens everything and pauses until next 00:00.

```
MaxBasketLossPct=0.0   ; 0=Off; e.g. 8.0 caps each basket at -8% of equity-at-open
MaxBasketSLPerDay=2    ; pause the day after this many basket-SL triggers
```

### S1.6 — All-time peak-to-trough DD trailing kill
Tracks the running max equity since EA start. When `(peak − current) / peak × 100 >= MaxAllTimeDDPct`, the EA closes all + pauses until next 00:00.

```
MaxAllTimeDDPct=0.0    ; 0=Off; recommend 40.0 then harden (40 -> 30 -> 25)
```

Caveat: peak resets on EA restart (no persistence yet — fine for backtest; live restarts reset once).

### S3.2 — Regime gate (ADX, rule-based first cut)
Classifies each bar as TREND vs RANGE/CHOP. In `HARD` mode, blocks new grid entries (initial *and* martingale) when `ADX(period, tf) >= threshold`. Pyramid is unaffected — it runs from its own slope filter, which is the intended trend-following lane.

```
RegimeMode=0           ; 0=Off, 1=Soft (log-only), 2=Hard (block)
RegimeAdxThresh=30
RegimePeriod=14
RegimeTimeframe=PERIOD_M15
```

A later story will replace ADX with the MMD multi-cloud regime classifier from CashCabaret.

### Recommended Sprint-1 baseline `.set` overlay (on top of any 1.1 baseline)

```
MaxBasketLossPct=8.0
MaxBasketSLPerDay=2
MaxAllTimeDDPct=40.0
RegimeMode=2
RegimeAdxThresh=30
RegimePeriod=14
RegimeTimeframe=16    ; PERIOD_M15 = 16
```

## Modules (per release)

| File              | Purpose                                    |
|-------------------|--------------------------------------------|
| `Inputs.mqh`      | All `input` parameters                     |
| `Globals.mqh`     | Runtime state variables                    |
| `Utils.mqh`       | Time / lot / color / string helpers        |
| `Persistence.mqh` | Position + pyramid state save/load (CSV)   |
| `Orders.mqh`      | `CTrade` wrapper — open / modify / close   |
| `Slope.mqh`       | MA slope cache                             |
| `Regime.mqh`      | ADX-based regime gate (S3.2, new in 1.2)   |
| `Series.mqh`      | Buy/sell series ID tracking                |
| `Pyramid.mqh`     | Pyramid bookkeeping + management           |
| `Basket.mqh`      | BE calc, floating PL, step gates           |
| `ScenarioD.mqh`   | Martingale / basket grid                   |
| `Risk.mqh`        | Daily baseline + risk controls + Sprint 1 rails |
| `ScenarioE.mqh`   | Hedge runners                              |
| `Dashboard.mqh`   | Stub                                       |
| `Telemetry.mqh`   | Stub                                       |
| `Signal.mqh`      | Tick burst + signal dispatch               |

Include order matters — downstream modules reference upstream symbols:

```
Inputs → Globals → Utils → Persistence → Orders → Slope → Regime →
Pyramid → Series → Basket → ScenarioD → Risk → ScenarioE →
Dashboard → Telemetry → Signal
```

## How to build

Pick a version and copy its EA folder into the MT5 terminal data folder:

- 1.0: copy `mt5/1.0/MoneyDancer_1.0/` to `<MT5_DATA>/MQL5/Experts/MoneyDancer_1.0/`
- 1.1: copy `mt5/1.1/MoneyDancer_1.1/` to `<MT5_DATA>/MQL5/Experts/MoneyDancer_1.1/`
- 1.2: copy `mt5/1.2/MoneyDancer_1.2/` to `<MT5_DATA>/MQL5/Experts/MoneyDancer_1.2/`
- 2.0: copy `mt5/2.0/MoneyDancer_2.0/` to `<MT5_DATA>/MQL5/Experts/MoneyDancer_2.0/`

Open the matching `MoneyDancer_<ver>.mq5` in MetaEditor, press **F7**.

## Release rules

- **MAJOR** — breaking changes (new core mechanic, incompatible `.set` schema).
- **MINOR** — additive features (new inputs default to OFF; old `.set` still loads).
- **FIX**   — bug fixes only, no behavior changes — applied in-place to the MAJOR.MINOR folder; `#property version` stays the same; CHANGELOG entry gets a sub-bullet with the fix date.
- Each MAJOR.MINOR release is a **full copy** of the previous: own `Include/`, own `presets/`. No cross-version sharing — duplication is intentional, lets older versions stay frozen.

## Conventions

- Include guards: `__MD_<NAME>_MQH__` (same across releases — each release compiles standalone).
- Risk thresholds are always **% of balance** when expressed as ratios; fixed-USD options must be explicitly opted into (e.g. `ProfitTargetMode=2`).
- 1.0 is a literal 1:1 MT4 port — no refactoring there ever. Refactors land in newer versions.
