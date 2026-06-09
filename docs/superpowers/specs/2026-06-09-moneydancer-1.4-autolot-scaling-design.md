# MoneyDancer 1.4 — Account-Scaled Position Size — Design

**Branch:** `claude/reverent-panini-6271e7`. **Date:** 2026-06-09. **Base:** MoneyDancer 1.3 (`mt5/1.3/MoneyDancer_1.3/`).
**Governing skill:** trading-audit-trail (verification = bit-identical-when-off + formula-correct-when-on).

## 1. Why

MoneyDancer sizes every basket from a fixed `LotsBase` (0.01), so risk-per-dollar is constant regardless of
account size and the EA can neither compound nor derisk as the account grows or draws down. v1.4 adds an
**opt-in** auto-lot: the base lot scales with account equity (or balance). Off by default → byte-identical
to 1.3 (which is byte-identical to 1.2).

This re-implements, on the clean 1.x line, the feature the deleted v3.1 proved out (equity-scaled base lot,
verified proportional). v3.1 used only a *multiply* model; v1.4 adds a selectable **add** model (linear,
gentler) and makes it the default — which directly addresses the v3.1 gotcha that small deposit + the
hyper-martingale grid can margin-blow under proportional scaling.

## 2. Versioning

Verbatim fork of `mt5/1.3/MoneyDancer_1.3/` → `mt5/1.4/MoneyDancer_1.4/` — files copied, EA renamed
`MoneyDancer_1.4.mq5`, version strings bumped to `1.4` (header comment line ~2, `#property version`, init
`Print`). NO input renaming. The only logic change is the feature below.

## 3. Decisions (locked in brainstorming)

1. **On/off** master toggle.
2. **Metric** selectable: equity (default) or balance.
3. **Mode** selectable: add (default) or multiply.
4. **Divisor** ("by how much") default 1000.
5. **Increment** (add step) default 0.01.
6. **Units are continuous** (`metric/divisor`, not floored) — broker volume-step rounding via `ClampLot`
   handles granularity.
7. Selectables are **enums** (`AutoLotType`, `AutoLotMode`), not bools.
8. **No new lot cap** — the existing `ClampLot` (broker min/step/max + `MaxLot`) bounds the result. This is
   the v3.1 lesson: an extra cap muddies behavior; reuse the one already there.

## 4. New inputs (`Include/Inputs.mqh`, added after `LotsBase` at line 96)

```cpp
enum AutoLotMetric { Metric_Equity, Metric_Balance };   // input dropdown: Equity / Balance
enum AutoLotCalc   { Calc_Add,      Calc_Multiply  };   // input dropdown: Add / Multiply

input bool          AutoLotScaling   = false;           // master on/off (off => fixed LotsBase, 1.3-identical)
input AutoLotMetric AutoLotType      = Metric_Equity;   // scale by Equity (default) or Balance
input AutoLotCalc   AutoLotMode      = Calc_Add;         // Add (default) or Multiply
input double        AutoLotDivisor   = 1000;            // account units per step ("by how much")
input double        AutoLotIncrement = 0.01;            // lot added per unit (Add mode only)
```
Enums are declared at the top of `Inputs.mqh` (before the `input` lines that use them). Default enumerators
are the first member (`Metric_Equity`, `Calc_Add`), matching the chosen defaults. When `AutoLotScaling` is
false, every other AutoLot input is ignored.

## 5. Formula — `ComputeBaseLot()` (new, `Include/Utils.mqh`, near `ClampLot`)

```cpp
double ComputeBaseLot()
{
   if(!AutoLotScaling) return LotsBase;                                  // OFF: exact 1.3 path
   double metric = (AutoLotType == Metric_Balance) ? AccountInfoDouble(ACCOUNT_BALANCE)
                                                    : AccountInfoDouble(ACCOUNT_EQUITY);
   double units  = (AutoLotDivisor > 0.0) ? (metric / AutoLotDivisor) : 0.0;   // continuous; guard div0
   double lot    = (AutoLotMode == Calc_Multiply) ? (LotsBase * units)             // MULTIPLY
                                                  : (LotsBase + AutoLotIncrement * units);  // ADD (default)
   return ClampLot(lot);                                                // broker min/step/max + MaxLot
}
```
Worked examples (LotsBase 0.01, divisor 1000, increment 0.01; pre-ClampLot):
- ADD, equity 5000 → `0.01 + 0.01×5 = 0.06`; equity 50000 → `0.01 + 0.01×50 = 0.51`.
- MULTIPLY, equity 5000 → `0.01×5 = 0.05`; equity 100000 → `1.0` (= the v3.1 proportional model).
- `AutoLotDivisor <= 0` → units 0 → ADD returns `LotsBase`, MULTIPLY returns 0 → `ClampLot` floors to broker
  min. No division-by-zero.

## 6. Where it plugs in (5 trade-path sites — identical set to v3.1)

Swap `LotsBase` → `ComputeBaseLot()` at:
- `Signal.mqh:256` — first basket order.
- `Signal.mqh:202`, `:203` — pyramid / fallback base lot.
- `Signal.mqh:303` — base-lot "DB" add (currently `lot = ClampLot(LotsBase)` → `lot = ClampLot(ComputeBaseLot())`;
  the double clamp is harmless).
- `ScenarioE.mqh:220` — runner lot (`MathMin(LotsBase, remaining)` → `MathMin(ComputeBaseLot(), remaining)`).

**Martingale escalation is NOT touched** (`firstLot * LotMultiplier^N`): `firstLot` reads the first order's
*actual* volume (`FirstBasketLotSeries`), so the whole grid auto-scales once the first order uses
`ComputeBaseLot()`. Each new basket recomputes off live equity/balance at its open → effectively a
per-basket snapshot, no separate freeze input needed. Do NOT touch `LotsBase`'s declaration or `ClampLot`.

## 7. Backward-compat guarantee

`AutoLotScaling == false` ⇒ `ComputeBaseLot()` returns the literal `LotsBase` through an early return ⇒ all
5 sites behave exactly as 1.3. OFF ⇒ byte-identical to 1.3 (and 1.3 is byte-identical to 1.2).

## 8. Verification (trading-audit-trail — the tester fully covers this; no manual orders needed)

1. **OFF bit-identical:** run an author set on v1.4 with `AutoLotScaling=false` vs 1.3 (same
   symbol/window/deposit). Same sha256 on both `trades.csv`.
2. **ON formula-correct:** with `AutoLotScaling=true`, default ADD/equity, run the same set at deposit 5000
   and 50000; the first basket order's volume must equal `ClampLot(0.01 + 0.01×deposit/1000)` →
   ~0.06 and ~0.51. Then a **MULTIPLY** spot-check (deposit 50000 → `ClampLot(0.01×50)=0.50`) and a
   **balance-metric** spot-check (`AutoLotType=Metric_Balance`, deposit 50000 → same 0.51 as equity at
   t0 since equity≈balance at start). Each value must trace to the run's `trades.csv` first in-deal volume.
3. **Compile** 0 errors.

## 9. Deliverables (audit folder `reports/md1.4-autolot-<UTCstamp>/`)

Modified files (compile clean), the OFF bit-identical pair (`trades.csv` ×2 + sha match), the ON formula
runs' `trades.csv` with the first-order-lot vs expected-formula table, the `.set`/override configs used, and
`manifest.md` (sha256 + verdict). No metric reported unless it traces to evidence there.

## 10. Out of scope

Per-series freeze input (martingale already anchors via the first order); additional lot caps (`ClampLot`
suffices); ATR/regime-driven lot modifiers; multi-symbol. v1.4 adds only the five opt-in inputs + two enums
+ `ComputeBaseLot` + the five call-site swaps. No behavior change when off.

## 11. Reused assets

1.3 source (`mt5/1.3/MoneyDancer_1.3/`), `ClampLot` (Utils.mqh:23), `LotsBase` (Inputs.mqh:96),
`scripts/f0_runner.py` (Model=0, `--input-override`, `--deposit`) + `extract_trades_from_report.py`,
RoboForex terminal `5FFA5681` + `metaeditor64.exe`, duka `XAUUSD.duk_robo`. Author set
`mt5/1.4/MoneyDancer_1.4/presets/author-reference/TEST 13a M30+.set`.
