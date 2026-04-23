# mt5/ — MT5 port

Bare 1:1 translation of `../mt4/MoneyDancer_legacy.mq4`.

## Layout

```
MoneyDancer/
  MoneyDancer.mq5        Main EA — lifecycle + include order
  Include/               Strategy modules
```

## Modules

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

Copy `mt5/MoneyDancer/` into the MT5 terminal's data folder under `MQL5\Experts\MoneyDancer\`, open `MoneyDancer.mq5` in MetaEditor, press **F7**.

## Conventions

- Include guards: `__MD_<NAME>_MQH__`
- Risk thresholds are always **% of balance**, never fixed dollars.
- Literal 1:1 port of the MT4 EA. No refactoring here.
