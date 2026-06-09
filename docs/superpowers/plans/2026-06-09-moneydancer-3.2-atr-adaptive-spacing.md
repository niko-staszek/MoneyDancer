# MoneyDancer 3.2 — ATR-Adaptive Grid Spacing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add opt-in ATR-adaptive scaling to two grid-spacing params (`StepPoints`, `MinOrderDistancePts`) on the MoneyDancer 3.1 base, then A/B-prove it beats fixed on OOS or drop it.

**Architecture:** New self-contained `Include/AtrSpacing.mqh` module (mirrors the `Slope.mqh`/`Regime.mqh` handle-lifecycle pattern) owns the `iATR` handle, a points-reader, and `EffectiveStepPoints()`/`EffectiveMinOrderDistPts()` helpers that return the literal fixed input when `AtrSpacingMode==0` (so OFF is byte-identical to 3.1). `Basket.mqh`'s three fixed reads call the helpers; a single per-tick freeze hook snapshots ATR for mode 1. Verification is behavioral (bit-identical-when-off + A/B), matching the v3.0/v3.1 discipline — this EA has no unit-test harness.

**Tech Stack:** MQL5 (RoboForex MT5 terminal `5FFA568149E88FCD5B44D926DCFEAA79`, `metaeditor64.exe`), Python harness (`scripts/f0_runner.py` Model=0, `extract_trades_from_report.py`, `detune_metrics.py`), duka symbols `XAUUSD.duk_robo` (2026) / `XAUUSD._robo_2025` (2025).

**Spec:** `docs/superpowers/specs/2026-06-08-moneydancer-3.2-atr-adaptive-spacing-design.md`

---

### Task 1: Inputs + AtrSpacing.mqh module + lifecycle wiring

**Files:**
- Modify: `mt5/3.0/MoneyDancer_3.0/Include/Inputs.mqh:112` (add 7 inputs after `MinOrderDistancePts`)
- Create: `mt5/3.0/MoneyDancer_3.0/Include/AtrSpacing.mqh`
- Modify: `mt5/3.0/MoneyDancer_3.0/MoneyDancer_3.0.mq5` (include + OnInit + OnDeinit)

- [ ] **Step 1: Add the 7 opt-in inputs**

In `Include/Inputs.mqh`, find (line 111-112):
```cpp
input int    StepPoints            = 120;   // After X points let MOE run
input int    MinOrderDistancePts   = 100;   // Min distance between orders (points)
```
Insert immediately after line 112:
```cpp
// --- v3.2 ATR-adaptive grid spacing (opt-in; AtrSpacingMode=0 => fixed, 3.1-identical) ---
input int             AtrSpacingMode      = 0;          // 0=OFF(fixed) 1=freeze-at-basket-open 2=live-per-bar
input ENUM_TIMEFRAMES AtrTimeframe        = PERIOD_H1;  // TF for ATR measurement
input int             AtrPeriod           = 14;         // ATR averaging period
input double          StepAtrMult         = 0.30;       // effective StepPoints = ATR_points * this (mode>0)
input double          MinOrderDistAtrMult = 0.25;       // effective MinOrderDistancePts = ATR_points * this (mode>0)
input double          AtrSpacingFloorFrac = 0.25;       // clamp floor = this * fixed input value
input double          AtrSpacingCeilFrac  = 4.0;        // clamp ceil  = this * fixed input value
```

- [ ] **Step 2: Create the AtrSpacing.mqh module**

Create `Include/AtrSpacing.mqh` with exactly:
```cpp
//+------------------------------------------------------------------+
//| AtrSpacing.mqh — ATR-adaptive grid spacing (v3.2, opt-in)        |
//| OFF (AtrSpacingMode==0) => returns the fixed inputs, 3.1-ident.  |
//| Mirrors the Slope.mqh / Regime.mqh handle-lifecycle pattern.     |
//+------------------------------------------------------------------+
#ifndef __MD_ATRSPACING_MQH__
#define __MD_ATRSPACING_MQH__

int    g_atrHandle    = INVALID_HANDLE;
double g_basketAtrPts = -1.0;   // mode 1: ATR(points) frozen for the current basket's life

bool AtrSpacingInit()
{
   g_atrHandle    = INVALID_HANDLE;
   g_basketAtrPts = -1.0;
   if(AtrSpacingMode <= 0) return true;                 // OFF: no handle, no work
   g_atrHandle = iATR(_Symbol, AtrTimeframe, AtrPeriod);
   if(g_atrHandle == INVALID_HANDLE)
      Print("AtrSpacingInit: iATR handle failed (tf=", EnumToString(AtrTimeframe),
            " period=", AtrPeriod, ") — falling back to fixed spacing");
   return true;                                         // non-fatal: helpers fall back to fixed
}

void AtrSpacingDeinit()
{
   if(g_atrHandle != INVALID_HANDLE)
   {
      IndicatorRelease(g_atrHandle);
      g_atrHandle = INVALID_HANDLE;
   }
   g_basketAtrPts = -1.0;
}

// Latest completed-bar ATR in POINTS, or -1 if not ready / invalid.
double AtrPoints()
{
   if(g_atrHandle == INVALID_HANDLE) return -1.0;
   double buf[];
   if(CopyBuffer(g_atrHandle, 0, 0, 1, buf) < 1) return -1.0;
   if(buf[0] <= 0.0) return -1.0;
   return buf[0] / _Point;
}

// Effective spacing in points: fixed when OFF/not-ready, else clamped ATR*mult.
int EffectiveSpacing(int fixedVal, double mult)
{
   if(AtrSpacingMode == 0) return fixedVal;                            // OFF: identical path
   double atrPts = (AtrSpacingMode == 1) ? g_basketAtrPts : AtrPoints();
   if(atrPts <= 0.0) return fixedVal;                                  // not-ready -> fixed fallback
   double v  = MathRound(atrPts * mult);
   double lo = AtrSpacingFloorFrac * fixedVal;
   double hi = AtrSpacingCeilFrac  * fixedVal;
   return (int)MathMax(lo, MathMin(hi, v));
}

int EffectiveStepPoints()      { return EffectiveSpacing(StepPoints,          StepAtrMult); }
int EffectiveMinOrderDistPts() { return EffectiveSpacing(MinOrderDistancePts, MinOrderDistAtrMult); }

#endif // __MD_ATRSPACING_MQH__
```

- [ ] **Step 3: Include the module (before Basket.mqh, which consumes the helpers)**

In `MoneyDancer_3.0.mq5`, find (line 33):
```cpp
#include "Include/Regime.mqh"
```
Insert immediately after it:
```cpp
#include "Include/AtrSpacing.mqh"
```
(Inputs.mqh at line 27 precedes it; Basket.mqh at line 36 follows it — so the helpers are declared before their call sites.)

- [ ] **Step 4: Wire OnInit / OnDeinit**

In `MoneyDancer_3.0.mq5` `OnInit()`, find:
```cpp
   // regime gate (lazy iADX init in GetCurrentADX).
   if(!RegimeInit()) return(INIT_FAILED);
```
Insert immediately after:
```cpp

   // v3.2 ATR-adaptive spacing handle (no-op when AtrSpacingMode==0).
   AtrSpacingInit();
```
In `OnDeinit()`, find:
```cpp
   SlopeDeinit();
   RegimeDeinit();
```
Replace with:
```cpp
   SlopeDeinit();
   RegimeDeinit();
   AtrSpacingDeinit();
```

- [ ] **Step 5: Deploy + compile**

Run (bash, from WT):
```bash
TD="C:/Users/nikof/AppData/Roaming/MetaQuotes/Terminal/5FFA568149E88FCD5B44D926DCFEAA79"
cp -r mt5/3.0/MoneyDancer_3.0/. "$TD/MQL5/Experts/MoneyDancer_3.0/"
"C:/Program Files/RoboForex MT5 Terminal/metaeditor64.exe" /compile:"$TD/MQL5/Experts/MoneyDancer_3.0/MoneyDancer_3.0.mq5" /log:"$TD/compile_md32.log"
python -c "print(open(r'$TD/compile_md32.log',encoding='utf-16').read())"
```
Expected: `0 errors, 0 warnings`. (metaeditor64 rc=1 is its normal convention; trust the log text.)
If `EffectiveStepPoints`/`EffectiveMinOrderDistPts` are "undeclared" — the include at Step 3 is misplaced; ensure `#include "Include/AtrSpacing.mqh"` sits before `#include "Include/Basket.mqh"`. Do not proceed past errors.

- [ ] **Step 6: Commit**

```bash
git add mt5/3.0/MoneyDancer_3.0/Include/Inputs.mqh \
        mt5/3.0/MoneyDancer_3.0/Include/AtrSpacing.mqh \
        mt5/3.0/MoneyDancer_3.0/MoneyDancer_3.0.mq5
git commit -m "feat(3.2): ATR-adaptive spacing module + inputs (opt-in, helpers default to fixed)"
```

---

### Task 2: Freeze hook + call-site swaps

**Files:**
- Modify: `mt5/3.0/MoneyDancer_3.0/Include/Basket.mqh:331`, `:344`, `:477` (call-site swaps) + add `AtrUpdateBasketFreeze()` after `SumRunnerLotsDir` (ends ~line 99)
- Modify: `mt5/3.0/MoneyDancer_3.0/MoneyDancer_3.0.mq5` `OnTick()` (call the freeze hook)

- [ ] **Step 1: Add the freeze hook in Basket.mqh**

In `Include/Basket.mqh`, find the end of `SumRunnerLotsDir` (the `return s;` + closing `}` near line 98-99, immediately before `double BasketFloatingPL(...)` at line 101). Insert this function between them:
```cpp
// v3.2: freeze ATR(points) for the current basket's life (AtrSpacingMode==1).
// One shared snapshot across both directions (the gold grid runs effectively one-sided);
// cleared once the EA is flat of grid orders so the next basket resamples.
void AtrUpdateBasketFreeze()
{
   if(AtrSpacingMode != 1) return;
   double openLots = SumLotsDir(1, false) + SumLotsDir(-1, false);  // exclude runners
   if(openLots <= 0.0) { g_basketAtrPts = -1.0; return; }           // flat -> clear
   if(g_basketAtrPts <= 0.0) g_basketAtrPts = AtrPoints();          // basket just opened -> freeze
}
```
(`SumLotsDir`, `AtrPoints`, `g_basketAtrPts`, and `AtrSpacingMode` are all declared in earlier-included files, so this compiles.)

- [ ] **Step 2: Call the freeze hook once per tick**

In `MoneyDancer_3.0.mq5` `OnTick()`, find (line 117-118):
```cpp
   // Slope cache refresh on new bar (cheap no-op otherwise).
   UpdateSlopeCacheIfNewBar();
```
Insert immediately after:
```cpp

   // v3.2: snapshot/clear ATR for mode-1 basket-frozen spacing (no-op in modes 0/2).
   AtrUpdateBasketFreeze();
```

- [ ] **Step 3: Swap the StepPoints call sites**

In `Include/Basket.mqh`, there are two identical lines (at :331 and :344):
```cpp
   return (distPts >= StepPoints);
```
Replace BOTH occurrences with:
```cpp
   return (distPts >= EffectiveStepPoints());
```
(Use replace-all; both are inside `StepGateFromBasketBE` / `StepGateFromBasketBESeries` and both must change.)

- [ ] **Step 4: Swap the MinOrderDistancePts call site**

In `Include/Basket.mqh`, find (line 477):
```cpp
      if(distancePts < MinOrderDistancePts) return false;
```
Replace with:
```cpp
      if(distancePts < EffectiveMinOrderDistPts()) return false;
```

- [ ] **Step 5: Deploy + compile**

Run (bash, from WT):
```bash
TD="C:/Users/nikof/AppData/Roaming/MetaQuotes/Terminal/5FFA568149E88FCD5B44D926DCFEAA79"
cp -r mt5/3.0/MoneyDancer_3.0/. "$TD/MQL5/Experts/MoneyDancer_3.0/"
"C:/Program Files/RoboForex MT5 Terminal/metaeditor64.exe" /compile:"$TD/MQL5/Experts/MoneyDancer_3.0/MoneyDancer_3.0.mq5" /log:"$TD/compile_md32.log"
python -c "print(open(r'$TD/compile_md32.log',encoding='utf-16').read())"
```
Expected: `0 errors, 0 warnings`. Do not proceed past errors.

- [ ] **Step 6: Commit**

```bash
git add mt5/3.0/MoneyDancer_3.0/Include/Basket.mqh mt5/3.0/MoneyDancer_3.0/MoneyDancer_3.0.mq5
git commit -m "feat(3.2): wire ATR spacing — 3 call-site swaps + mode-1 per-tick freeze hook"
```

---

### Task 3 (run-task): Gate A — OFF bit-identical to 3.1

**Files:**
- Create: `reports/md3.2-atr-spacing-<UTCstamp>/` (audit evidence, committed)

trading-audit-trail governs. Kill terminal+metatester ONCE before; never between runs.

- [ ] **Step 1: Run OFF leg (AtrSpacingMode defaults 0) on the 3.1 baseline window**

Run (bash, from WT) — 13a, same symbol/window/deposit as the committed 3.1 OFF baseline:
```bash
taskkill //IM terminal64.exe //F 2>/dev/null; taskkill //IM metatester64.exe //F 2>/dev/null; sleep 5
python -c "import sys; sys.path.insert(0,'scripts'); from translate_set import to_3_0; to_3_0(r'C:/Users/nikof/Downloads/TEST 13a M30+.set','test13a_3.0.set')"
python scripts/f0_runner.py --set-file "$PWD/test13a_3.0.set" --run-id V32-OFF --symbol XAUUSD.duk_robo --period M30 --model 0 --from-date 2026.04.06 --to-date 2026.04.13 --deposit 10000 --input-override "MaxSpreadPts=45" --expert "MoneyDancer_3.0\\MoneyDancer_3.0.ex5" --timeout 3000
python scripts/extract_trades_from_report.py --report runs/V32-OFF/V32-OFF-report.htm --out runs/V32-OFF/trades.csv
```

- [ ] **Step 2: Assert bit-identical to the 3.1 OFF baseline**

Run (bash, from WT):
```bash
python - <<'PY'
import hashlib
new  = open("runs/V32-OFF/trades.csv","rb").read()
base = open("reports/md3.1-autolot-20260608/OFF_trades.csv","rb").read()
hn, hb = hashlib.sha256(new).hexdigest()[:16], hashlib.sha256(base).hexdigest()[:16]
print("V32-OFF sha:", hn, "| 3.1 baseline sha:", hb)
print("GATE A (OFF==3.1):", "PASS" if new==base else "FAIL")
assert new==base, "OFF changed behavior — a Task-2 swap altered the off path; EffectiveSpacing must return the literal fixed input when AtrSpacingMode==0."
PY
```
Expected: `PASS`, sha `649b28256781da82` on both. If FAIL, the OFF path is not identical — inspect `EffectiveSpacing` (must early-return `fixedVal` when mode 0) and re-verify before any A/B.

---

### Task 4 (run-task): A/B — beats-fixed-or-drop + audit folder

**Files:**
- Create/append: `reports/md3.2-atr-spacing-<UTCstamp>/` (matrix CSVs, metrics table, verdict, manifest)

A/B matrix on the 13a baseline set. Per-run ~17 min (M30, 1-week); run as a background batch, serial.

- [ ] **Step 1: Confirm each A/B cell has tick data (mode-0 control smoke)**

Cells (window, symbol): OOS-2026 = {2026.03.09–03.16, 2026.04.06–04.13, 2026.05.04–05.11} on `XAUUSD.duk_robo`; IS-2025 = {2025.09.01–09.08, 2025.11.03–11.10} on `XAUUSD._robo_2025`.
Run a mode-0 control per cell first; if a cell yields **0 deals**, it lacks ticks — drop/replace it (try an adjacent week) and note the swap in the audit. Driver (bash, from WT):
```bash
taskkill //IM terminal64.exe //F 2>/dev/null; taskkill //IM metatester64.exe //F 2>/dev/null; sleep 5
run() { # args: runid symbol from to extra_overrides...
  local rid="$1" sym="$2" f="$3" t="$4"; shift 4
  local ov=(); for o in "$@"; do ov+=(--input-override "$o"); done
  python scripts/f0_runner.py --set-file "$PWD/test13a_3.0.set" --run-id "$rid" --symbol "$sym" --period M30 --model 0 \
    --from-date "$f" --to-date "$t" --deposit 10000 --input-override "MaxSpreadPts=45" "${ov[@]}" \
    --expert "MoneyDancer_3.0\\MoneyDancer_3.0.ex5" --timeout 3000
  python scripts/extract_trades_from_report.py --report "runs/$rid/$rid-report.htm" --out "runs/$rid/trades.csv"
}
# control smoke (mode 0) per cell:
run AB-c1-m0 XAUUSD.duk_robo   2026.03.09 2026.03.16 "AtrSpacingMode=0"
run AB-c2-m0 XAUUSD.duk_robo   2026.04.06 2026.04.13 "AtrSpacingMode=0"
run AB-c3-m0 XAUUSD.duk_robo   2026.05.04 2026.05.11 "AtrSpacingMode=0"
run AB-c4-m0 XAUUSD._robo_2025 2025.09.01 2025.09.08 "AtrSpacingMode=0"
run AB-c5-m0 XAUUSD._robo_2025 2025.11.03 2025.11.10 "AtrSpacingMode=0"
```

- [ ] **Step 2: Run the ATR arms (mode 1 + mode 2 over a small mult grid)**

For each cell that passed the smoke, run mode 1 and mode 2 at two `StepAtrMult` values (0.20, 0.35), `MinOrderDistAtrMult=0.25` fixed. Reuse the `run` function from Step 1 (same shell). Example for cell c2 (repeat the 4 lines per cell, substituting runid/symbol/window):
```bash
run AB-c2-m1-s20 XAUUSD.duk_robo 2026.04.06 2026.04.13 "AtrSpacingMode=1" "StepAtrMult=0.20" "MinOrderDistAtrMult=0.25"
run AB-c2-m1-s35 XAUUSD.duk_robo 2026.04.06 2026.04.13 "AtrSpacingMode=1" "StepAtrMult=0.35" "MinOrderDistAtrMult=0.25"
run AB-c2-m2-s20 XAUUSD.duk_robo 2026.04.06 2026.04.13 "AtrSpacingMode=2" "StepAtrMult=0.20" "MinOrderDistAtrMult=0.25"
run AB-c2-m2-s35 XAUUSD.duk_robo 2026.04.06 2026.04.13 "AtrSpacingMode=2" "StepAtrMult=0.35" "MinOrderDistAtrMult=0.25"
```
(5 runs/cell: 1 control + 4 arms. Run in background; ~17 min each. Skip any cell dropped in Step 1.)

- [ ] **Step 3: Score every run with the smoothness panel**

Run (bash, from WT) — builds the per-run metrics table and the per-cell arm-vs-control deltas:
```bash
python - <<'PY'
import sys, glob, os, pandas as pd, numpy as np
sys.path.insert(0,'scripts'); import detune_metrics as dm
DEP=10000.0
def score(csv):
    t=pd.read_csv(csv); o=t[t.direction=='out']
    bal=np.concatenate([[DEP], DEP+o['profit'].cumsum().values]) if len(o) else np.array([DEP])
    return dict(deals=len(t), net=float(o['profit'].sum()),
                ulcer=dm.ulcer_index(bal), max_dd=dm.max_dd_pct(bal),
                daily=dm.daily_avg_pct(t,DEP), losing=dm.losing_basket_count(t))
rows=[]
for d in sorted(glob.glob('runs/AB-*')):
    c=os.path.join(d,'trades.csv')
    if os.path.exists(c):
        r=score(c); r['run']=os.path.basename(d); rows.append(r)
df=pd.DataFrame(rows).set_index('run')
df['cell']=df.index.str.extract(r'(AB-c\d+)')[0].values
df['arm'] =df.index.str.replace(r'AB-c\d+-','',regex=True)
print(df[['cell','arm','deals','net','ulcer','max_dd','daily','losing']].to_string())
df.to_csv('runs/_ab_metrics.csv')
# per-cell: does any ATR arm beat the m0 control on ulcer AND max_dd at >= comparable net (>=95%)?
print("\n=== arm vs control (per cell) ===")
for cell,g in df.groupby('cell'):
    if 'm0' not in set(g['arm']): continue
    ctl=g[g['arm']=='m0'].iloc[0]
    for _,a in g[g['arm']!='m0'].iterrows():
        beats = (a.ulcer < ctl.ulcer) and (a.max_dd < ctl.max_dd) and (a.net >= 0.95*ctl.net)
        print(f"{cell} {a['arm']:9s} ulcer {a.ulcer:6.2f} vs {ctl.ulcer:6.2f} | maxdd {a.max_dd:5.1f} vs {ctl.max_dd:5.1f} | net {a.net:8.0f} vs {ctl.net:8.0f} -> {'BEATS' if beats else 'no'}")
PY
```

- [ ] **Step 4: KEEP/DROP verdict + write audit folder**

Apply the kill gate from the spec: an ATR arm **KEEPS** only if the same `(mode, mult)` beats its control (ulcer↓ AND max_dd↓ at ≥95% net) on **multiple cells** AND the win holds in **both** an IS-2025 cell and an OOS-2026 cell. Single-cell or IS-only wins → **DROP**.
Write the audit folder (bash, from WT):
```bash
D="reports/md3.2-atr-spacing-$(python -c "import datetime as d;print(d.datetime.utcnow().strftime('%Y%m%d-%H%M%SZ'))")"
mkdir -p "$D"
cp runs/V32-OFF/trades.csv "$D/GateA_OFF_trades.csv"
cp reports/md3.1-autolot-20260608/OFF_trades.csv "$D/GateA_31_baseline_trades.csv"
cp runs/_ab_metrics.csv "$D/ab_metrics.csv"
for d in runs/AB-*; do [ -f "$d/trades.csv" ] && cp "$d/trades.csv" "$D/$(basename $d)_trades.csv"; done
cp test13a_3.0.set "$D/"
# result.md: paste the Step-2 sha PASS line, the Step-3 table, the per-cell BEATS/no lines, and the explicit KEEP or DROP verdict with the deciding numbers.
# manifest.md: sha256 + size per file.
( cd "$D" && for f in *; do echo "$(sha256sum "$f" | cut -c1-16)  $(stat -c%s "$f")  $f"; done > manifest.md )
git add "$D" && git commit -m "evidence(3.2): ATR-adaptive spacing — Gate A bit-identical + A/B verdict (KEEP|DROP)"
```
Expected output: a committed audit folder whose `result.md` states **KEEP** (with the winning mode/mult and the IS∧OOS deltas) or **DROP** (ATR spacing did not beat fixed; EA stays shipped, feature off by default). If DROP, also append a one-line note to memory `project_rangedayeveryday_portfolio.md` recording the Nth confirmation that no static spacing knob generalizes.

---

## Notes / gotchas (from v3.0/v3.1)
- **Model=0 mandatory** — Model=1 starves the tick/burst engine (151 vs 5096 deals). Never use it.
- **Kill terminal+metatester ONCE** at the start of a batch, never between runs (killing mid-batch breaks the metatester agent pool → "NO REPORT").
- **MaxSpreadPts=45** override is required on duka_robo (raw spread 25-28 blocks all entries at the set's native 15).
- **Mode-1 freeze is a single shared snapshot** across both directions — an accepted approximation for a one-sided gold grid; if a future variant runs both directions heavily, revisit.
- The A/B is exploratory and **may end in DROP** — that is a valid, expected outcome (the probe was weak); do not torture the grid to manufacture a KEEP.
