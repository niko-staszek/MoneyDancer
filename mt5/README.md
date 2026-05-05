# mt5/ — MT5 versioned releases

Each subfolder under `mt5/` is a self-contained release of the EA, named **`MAJOR.MINOR`** (matches MQL5 Market's `#property version` format). Older releases stay frozen; new minor/major features land in new folders. FIX bumps update the existing folder in place and are documented in [`../CHANGELOG.md`](../CHANGELOG.md).

## Releases

| Version | Status | Folder                          | What's new                                                                |
|---------|--------|---------------------------------|---------------------------------------------------------------------------|
| 1.0     | Frozen | `1.0/MoneyDancer_1.0/`          | Bare 1:1 MT4→MT5 port. Three daily kill-switches.                         |
| 1.1     | Active | `1.1/MoneyDancer_1.1/`          | Adds **Total Profit Target** kill-switch (% of baseline OR fixed USD).    |

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

## Modules (per release)

| File              | Purpose                                    |
|-------------------|--------------------------------------------|
| `Inputs.mqh`      | All `input` parameters                     |
| `Globals.mqh`     | Runtime state variables                    |
| `Utils.mqh`       | Time / lot / color / string helpers        |
| `Persistence.mqh` | Position + pyramid state save/load (CSV)   |
| `Orders.mqh`      | `CTrade` wrapper — open / modify / close   |
| `Slope.mqh`       | MA slope cache                             |
| `Series.mqh`      | Buy/sell series ID tracking                |
| `Pyramid.mqh`     | Pyramid bookkeeping + management           |
| `Basket.mqh`      | BE calc, floating PL, step gates           |
| `ScenarioD.mqh`   | Martingale / basket grid                   |
| `Risk.mqh`        | Daily baseline + risk controls             |
| `ScenarioE.mqh`   | Hedge runners                              |
| `Dashboard.mqh`   | Stub                                       |
| `Telemetry.mqh`   | Stub                                       |
| `Signal.mqh`      | Tick burst + signal dispatch               |

Include order matters — downstream modules reference upstream symbols:

```
Inputs → Globals → Utils → Persistence → Orders → Slope →
Pyramid → Series → Basket → ScenarioD → Risk → ScenarioE →
Dashboard → Telemetry → Signal
```

## How to build

Pick a version and copy its EA folder into the MT5 terminal data folder:

- 1.0: copy `mt5/1.0/MoneyDancer_1.0/` to `<MT5_DATA>/MQL5/Experts/MoneyDancer_1.0/`
- 1.1: copy `mt5/1.1/MoneyDancer_1.1/` to `<MT5_DATA>/MQL5/Experts/MoneyDancer_1.1/`

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
