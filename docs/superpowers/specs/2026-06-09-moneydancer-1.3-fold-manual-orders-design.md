# MoneyDancer 1.3 — Fold Manual Orders Into Basket — Design

**Branch:** `claude/reverent-panini-6271e7`. **Date:** 2026-06-09. **Base:** MoneyDancer 1.2 (`mt5/1.2/MoneyDancer_1.2/`).
**Governing skill:** trading-audit-trail (verification = bit-identical-when-off + demo forward-test for the on path).

## 1. Why

MoneyDancer only manages its own magic-tagged positions. A trader who opens a hand-placed order on the
same symbol gets no help from the EA — the manual order sits outside the basket's breakeven, take-profit,
exposure, and kill-switch math. v1.3 adds an **opt-in** feature that folds genuinely manual (`magic==0`)
positions into the basket so the EA carries them to a combined breakeven and closes them with the basket.
Off by default → byte-identical to 1.2.

## 2. Versioning

v1.3 is a **verbatim fork** of `mt5/1.2/MoneyDancer_1.2/` to `mt5/1.3/MoneyDancer_1.3/` — files copied,
internal version strings/`#property version` bumped to `1.3`, EA renamed `MoneyDancer_1.3.mq5`. NO input
renaming (the 1.2 underscore/camelCase naming is the kept canonical scheme). The only logic change is the
feature below.

## 3. Decisions (locked in brainstorming)

1. **Foldable = `magic==0` only** (genuinely hand-placed). Foreign-EA magic numbers are never absorbed.
2. **Full manage:** a folded order counts in breakeven/TP/exposure AND the EA closes it with the basket.
3. **No manual-driven martingale:** a folded order shifts the TP target but never triggers grid adds — the
   EA opens new orders only from its own burst/step logic.
4. **Deterministic single attachment:** a manual order folds into exactly one series — the lowest active
   series id in its direction — so concurrent same-direction series never double-count it.

## 4. Mechanism

### 4.1 New input (`Include/Inputs.mqh`)
```cpp
input bool FoldManualOrders = false;  // include hand-placed (magic==0) same-symbol orders in the basket
```
When `false`, every code path below early-returns to the exact 1.2 behavior.

### 4.2 Helpers (`Include/Utils.mqh`)
```cpp
bool IsManualPosition()   // currently-selected position: symbol matches and magic==0
{
   return (PositionGetString(POSITION_SYMBOL) == _Symbol
           && PositionGetInteger(POSITION_MAGIC) == 0);
}
```
`IsMinePosition()` gains the opt-in fold (this is the ONLY behavioral edit to the existing function):
```cpp
bool IsMinePosition()
{
   if(PositionGetString(POSITION_SYMBOL) != _Symbol) return false;
   if(PositionGetInteger(POSITION_MAGIC) == (long)Magic) return true;
   if(FoldManualOrders && PositionGetInteger(POSITION_MAGIC) == 0) return true;  // v1.3
   return false;
}
```
Effect (exposure / risk / close scope): manual orders now count in `SumLotsDir` (exposure),
`BasketFloatingAllMine` (equity/DD guards), and `CloseAllOrders` / `CloseAllOrdersType` (kill-switches AND
basket close — the EA closes the manual order when it closes the basket).

### 4.3 Lowest-active-series helper (`Include/Series.mqh`)
```cpp
// Smallest series id with an open EA (magic==Magic) position in this direction; -1 if none.
int LowestActiveSeriesId(int dir)
{
   int lowest = -1;
   int total  = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)Magic) continue;   // EA-owned only (not manual)
      long typ = PositionGetInteger(POSITION_TYPE);
      if(dir > 0 && typ != POSITION_TYPE_BUY)  continue;
      if(dir < 0 && typ != POSITION_TYPE_SELL) continue;
      int id = ExtractSeriesIdFromComment(PositionGetString(POSITION_COMMENT), dir);
      if(id >= 0 && (lowest < 0 || id < lowest)) lowest = id;
   }
   return lowest;
}
```

### 4.4 Series adoption (combined breakeven / TP rescue)
The live exit `ApplyBasketTPSeries(dir, seriesKey)` and `CalcBasketBEWithCostsSeries(dir, seriesKey, be)`
decide membership via `IsSelectedPositionInSeries(seriesKey)`. Introduce a membership predicate that also
adopts the manual order into the lowest active series of the direction:
```cpp
// True if the currently-selected position should be managed under seriesKey for `dir`.
bool PositionInManagedSeries(string seriesKey, int dir)
{
   if(IsSelectedPositionInSeries(seriesKey)) return true;           // EA's own series member
   if(FoldManualOrders && IsManualPosition())
   {
      long typ = PositionGetInteger(POSITION_TYPE);
      if((dir > 0 && typ == POSITION_TYPE_BUY) || (dir < 0 && typ == POSITION_TYPE_SELL))
      {
         int low = LowestActiveSeriesId(dir);
         if(low >= 0 && seriesKey == SeriesKey(dir, low)) return true;   // adopt into oldest series only
      }
   }
   return false;
}
```
- `CalcBasketBEWithCostsSeries` gains a `bool includeManual=false` parameter. Its membership check is
  `includeManual ? PositionInManagedSeries(seriesKey, dir) : IsSelectedPositionInSeries(seriesKey)`.
  `ApplyBasketTPSeries` calls it (and applies the same `PositionInManagedSeries` predicate in its own
  TP-setting loop) with manual-awareness ON. Result: the combined BE includes the manual lot; the common
  TP (BE ± `bePoints`) is set on the manual order too → it closes with the basket at the shared breakeven.
- If `LowestActiveSeriesId(dir) < 0` (no active EA series in the direction), no adoption occurs — a lone
  manual order is only counted in exposure/DD/close (§4.2), never TP-managed, and never bootstraps a grid.

### 4.5 Add-side stays EA-only (no manual-driven martingale)
The entry/add-trigger paths must NOT see the manual order, so adds run exactly as 1.2:
`StepGateFromBasketBESeries`, `IsMovingAwayFromBESeries`, and `IsPriceFavorableOrAtBE` keep using
`IsSelectedPositionInSeries(seriesKey)` (unchanged), NOT `PositionInManagedSeries`. Only the TP/BE rescue
path (§4.4) adopts manual orders. This guarantees a manual order shifts the TP target but never changes
when/whether the EA adds grid orders.

> Implementation note: to avoid divergence, `CalcBasketBEWithCostsSeries` takes an added
> `bool includeManual=false` parameter. The TP path (`ApplyBasketTPSeries`) calls it with `true`; the
> add-side gates call it with `false` (default) — so the same BE function serves both, manual-aware only
> on the rescue path.

## 5. Backward-compat guarantee

Every branch is gated on `FoldManualOrders`. When false: `IsMinePosition` reverts to the magic check,
`PositionInManagedSeries` reduces to `IsSelectedPositionInSeries`, and `includeManual` is false everywhere.
OFF ⇒ byte-identical to 1.2.

## 6. Verification (trading-audit-trail)

1. **OFF bit-identical:** run an author set on v1.3 vs the same set on 1.2 (same symbol/window/deposit,
   `FoldManualOrders=false`). Per-deal identical — same sha256 on both `trades.csv`. Proves OFF changes
   nothing. (The strategy tester only ever runs EA-magic orders, so this fully exercises the OFF path.)
2. **ON — demo forward-test (the tester cannot inject hand-placed orders):** attach v1.3 with
   `FoldManualOrders=true` to a demo chart; once the EA has an active basket, open a `magic==0` order by
   hand in the basket's direction. Confirm from the journal/dashboard: (a) the basket breakeven shifts to
   include the manual lot, (b) the common TP re-levels and a TP is set on the manual order, (c) when the
   basket hits TP/kill, the manual order closes with it, (d) the EA's add cadence is unchanged (no extra
   grid orders caused by the manual order). Also do a logic self-review of the four touched call paths.
3. **Compile** 0 errors.

## 7. Deliverables (audit folder `reports/md1.3-foldmanual-<UTCstamp>/`)

The modified files (compile clean), the OFF bit-identical pair (`trades.csv` ×2 + sha match), a written
forward-test checklist + observed results (or a clear "pending demo" marker if not yet run), and
`manifest.md` (sha256 + verdict). No metric reported unless it traces to evidence there.

## 8. Out of scope

Foreign-EA magic absorption; manual-driven martingale; per-manual-order configurable lot caps; multi-symbol.
v1.3 adds only the one opt-in input + `IsManualPosition`/`LowestActiveSeriesId`/`PositionInManagedSeries`
helpers + the `includeManual` plumbing on the rescue path. No behavior change when off.

## 9. Reused assets

1.2 source (`mt5/1.2/MoneyDancer_1.2/`), `ExtractSeriesIdFromComment` / `SeriesKey` / `IsSelectedPositionInSeries`
(Series.mqh), `IsMinePosition` (Utils.mqh), `ApplyBasketTPSeries` / `CalcBasketBEWithCostsSeries` (Basket/ScenarioD),
`scripts/f0_runner.py` (Model=0) + `extract_trades_from_report.py`, RoboForex terminal `5FFA5681` +
`metaeditor64.exe`, duka `XAUUSD.duk_robo`.
