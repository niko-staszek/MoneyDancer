# MoneyDancer 3.2 — ATR-Adaptive Grid Spacing — Design

**Branch:** `claude/reverent-panini-6271e7`. **Date:** 2026-06-08. **Base:** MoneyDancer 3.1 (clean 3.0 rename + equity auto-lot).
**Governing skill:** trading-audit-trail (verification = bit-identical-when-off + A/B-beats-fixed-on-OOS-or-drop).

## 1. Why

3.0/3.1 size grid spacing from **fixed** point inputs (`StepPoints`, `MinOrderDistancePts`) regardless of market
volatility. Hypothesis: spacing that scales with ATR (wider in volatile regimes, tighter in quiet ones) gives a
smoother equity curve at comparable return. The hypothesis is **unproven and suspect** — an earlier per-cell
ATR-vs-LotMult probe (reports/detune-multicell-probe, 84dd4d9) showed only a weak, partly *inverted* signal. So
v3.2 adds the mechanism **opt-in** and **A/B-tests it against fixed on OOS**; if it does not beat fixed it is
**dropped** (left in the EA, flagged not-recommended), not shipped on faith.

## 2. Scope

ATR-adaptive applies to **exactly two** params:
- `StepPoints` — distance from basket breakeven that triggers the next martingale add (Basket.mqh:331, :344).
- `MinOrderDistancePts` — minimum gap enforced between orders (Basket.mqh:477).

Out of scope (deferred unless spacing proves out): `MinMovePoints` (burst entry), `TpPoints` (exit), breakeven
params. No changes to safety rails (DD kill, basket-SL, equity-DD), the martingale lot series, or entry logic.

## 3. What it adds (new inputs — all default OFF = bit-identical to 3.1)

```cpp
input int             AtrSpacingMode      = 0;            // 0=OFF(fixed,3.1-identical) 1=freeze-at-basket-open 2=live-per-bar
input ENUM_TIMEFRAMES AtrTimeframe        = PERIOD_H1;    // TF for ATR measurement
input int             AtrPeriod           = 14;           // ATR averaging period
input double          StepAtrMult         = 0.30;         // effective Step = ATR_points * this (mode>0)
input double          MinOrderDistAtrMult = 0.25;         // effective MinOrderDist = ATR_points * this (mode>0)
input double          AtrSpacingFloorFrac = 0.25;         // clamp floor = this * fixed input value
input double          AtrSpacingCeilFrac  = 4.0;          // clamp ceil  = this * fixed input value
```

When `AtrSpacingMode == 0`, every multiplier/frac is ignored and the EA uses the literal fixed inputs — the
existing 3.1 code path, unchanged.

## 4. Mechanism

**ATR handle (main `.mq5`):**
- `OnInit`: if `AtrSpacingMode > 0`, `g_atrHandle = iATR(_Symbol, AtrTimeframe, AtrPeriod)`; if
  `g_atrHandle == INVALID_HANDLE`, log + treat as not-ready (fixed fallback). `OnDeinit`: `IndicatorRelease`.
- A small reader `double AtrPoints()` returns the latest completed-bar ATR in **points** (`atr_price / _Point`),
  or `-1` if the handle is invalid or `CopyBuffer` returns < 1 value (early bars / not ready).

**Effective-value helpers (Utils.mqh):**
```cpp
int EffectiveSpacing(int fixedVal, double mult)
{
   if(AtrSpacingMode == 0) return fixedVal;              // OFF: identical path
   double atrPts = (AtrSpacingMode == 1) ? g_basketAtrPts : AtrPoints();  // mode1 frozen, mode2 live
   if(atrPts <= 0.0) return fixedVal;                    // not-ready / invalid -> fixed fallback
   double v   = MathRound(atrPts * mult);
   double lo  = AtrSpacingFloorFrac * fixedVal;
   double hi  = AtrSpacingCeilFrac  * fixedVal;
   return (int)MathMax(lo, MathMin(hi, v));
}
int EffectiveStepPoints()      { return EffectiveSpacing(StepPoints,          StepAtrMult); }
int EffectiveMinOrderDistPts() { return EffectiveSpacing(MinOrderDistancePts, MinOrderDistAtrMult); }
```

**Freeze (mode 1):** when a basket's first order opens, store `g_basketAtrPts = AtrPoints()` in basket state;
hold it for the basket's life. Reset on basket close. (mode 2 ignores `g_basketAtrPts` and reads live each call.)

**Call-site swaps (Basket.mqh):** `StepPoints` → `EffectiveStepPoints()` at :331 and :344;
`MinOrderDistancePts` → `EffectiveMinOrderDistPts()` at :477. No other reads of these two inputs change behavior
(preset/echo/validation reads, if any, keep the raw input).

## 5. Backward-compat guarantee

`AtrSpacingMode == 0` makes both helpers return the literal fixed input through the same branch, so no ATR handle
is created and no math runs. OFF ⇒ **byte-identical** to 3.1.

## 6. Verification (trading-audit-trail; v3.2 accepted/dropped per these)

1. **Gate A — OFF bit-identical:** run a baseline set (13a, ported to 3.0 names) with no Atr* overrides
   (`AtrSpacingMode=0`) on v3.2 vs the 3.1 baseline `reports/md3.1-autolot-20260608/OFF_trades.csv`
   (sha `649b28256781da82`), same symbol/window/deposit. **Same sha256.** Proves OFF changes nothing.
2. **A/B — beats-fixed-or-drop:** one baseline set, N cells spanning IS-2025 ∧ OOS-2026
   (reuse the detune cell windows). Arms: `mode=0` (fixed control) vs `mode=1` vs `mode=2`, each over a small
   `StepAtrMult` × `MinOrderDistAtrMult` grid. Score every run with `detune_metrics.py`
   (Ulcer Index, max DD, daily-avg %, losing-basket count, consistency). **KEEP** the feature only if some ATR arm
   beats the fixed control on **Ulcer + max DD at ≥ comparable net**, across **multiple cells**, with the win
   holding in **both** IS(2025) and OOS(2026). Single-cell wins do NOT count. Otherwise **DROP**: leave the code in
   (off by default) and record in the audit + memory that ATR-adaptive spacing did not beat fixed.
3. **Compile** 0 errors (RoboForex metaeditor64; rc=1 = its convention, log must say 0 errors 0 warnings).

## 7. Deliverables (audit folder `reports/md3.2-atr-spacing-<UTCstamp>/`)

Modified files (compile clean), Gate-A off-identical pair (trades.csv ×2 + sha match), the A/B run matrix
(per-arm trades.csv + `detune_metrics` table + the KEEP/DROP verdict with the winning/failing numbers), the `.set`
configs used, and `manifest.md` (sha256 + verdict). No metric reported unless it traces to a trades.csv there.

## 8. Out of scope

MinMovePoints / TpPoints / breakeven ATR-scaling; any safety-rail change; multi-symbol. v3.2 adds only the seven
opt-in inputs + the two helpers + ATR handle; it changes no behavior when off.

## 9. Reused assets

3.1 source (`mt5/3.0/MoneyDancer_3.0/`), `ComputeBaseLot`/`ClampLot` (Utils.mqh) untouched, `scripts/f0_runner.py`
(+`--input-override`, `--model 0` mandatory) + `extract_trades_from_report.py`, `detune_metrics.py`, the v3.1
bit-identical baseline, RoboForex terminal `5FFA5681` + `metaeditor64.exe`, duka `XAUUSD.duk_robo`
(2026 OOS) + `_robo_2025` (IS), the detune cell windows.
