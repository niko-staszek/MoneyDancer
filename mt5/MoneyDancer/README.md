# MoneyDancer — MT5

EA source of truth for the MT5 port. Plan: `../../docs/PLAN.md`.

## Current phase

**Phase A1 — scaffolding.** Compiling skeleton only. No behavior yet.

## Layout

```
MoneyDancer.mq5         Main EA (lifecycle functions, includes everything)
Include/
  Inputs.mqh            input parameters (A2)
  Globals.mqh           runtime state variables (A3-A5)
  Utils.mqh             helpers — time, lot, color, strings (A3)
  Persistence.mqh       save/load position + pyramid CSVs (A3)
  Orders.mqh            CTrade wrapper — open/modify/close (A4)
  Series.mqh            buy/sell series ID tracking (A4)
  Basket.mqh            BE calc, floating PL, step gates (A5)
  Pyramid.mqh           pyramid bookkeeping + management (A5)
  ScenarioD.mqh         martingale / basket grid (A5)
  ScenarioE.mqh         hedge runners (A5)
  Signal.mqh            tick burst + signal dispatch (A5)
  Slope.mqh             MA slope cache (A5)
  Risk.mqh              daily baseline + risk controls + IDLE foundation (A5 + B)
  Dashboard.mqh         dashboard, markers, buttons (A5 + B)
  Telemetry.mqh         CSV logger for ML training data (A7)
```

Each `.mqh` has TODO comments describing what gets filled in and during which phase.

## Deploy

```
cp -r mt5/MoneyDancer \
  "C:/Users/nikof/AppData/Roaming/MetaQuotes/Terminal/81A933A9AFC5DE3C23B15CAB19C63850/MQL5/Experts/"
```

Then in MetaEditor: File → Open → navigate to the Experts folder → open `MoneyDancer.mq5` → F7 to compile.

## Conventions

- Include guards: `__MD_<NAME>_MQH__`
- All risk thresholds are **% of balance**, never fixed dollars.
- ML never touches lot size, multiplier, stops, or kill-switches.
- Preserve MT4 behavior 1:1 through Phase A. New features start in Phase B.

## Revision / port notes

MT4 source (frozen reference): `../../mt4/MoneyDancer_legacy.mq4`.

Documented MT4→MT5 semantic adaptations: see `docs/PLAN.md` §18.2.
