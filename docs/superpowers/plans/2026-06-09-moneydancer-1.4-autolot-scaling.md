# MoneyDancer 1.4 — Account-Scaled Position Size — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fork MoneyDancer 1.3 → 1.4 and add an opt-in auto-lot that scales the base lot with account equity or balance (add or multiply mode), without touching the martingale.

**Architecture:** New `mt5/1.4/MoneyDancer_1.4/` is a verbatim copy of 1.3 with version bumped. The feature is one `ComputeBaseLot()` helper (in Utils.mqh) gated on `AutoLotScaling`, plus two enums + five inputs in Inputs.mqh, plus five call-site swaps of `LotsBase` → `ComputeBaseLot()`. When the flag is off, `ComputeBaseLot()` early-returns the literal `LotsBase`, so behavior is byte-identical to 1.3. The martingale (`firstLot * LotMultiplier^N`) reads the first order's actual volume, so the whole grid auto-scales once the first order scales — nothing else changes. This EA has no unit-test harness; verification is compile-clean + bit-identical-when-off + a tester formula-check when on.

**Tech Stack:** MQL5 (RoboForex MT5 terminal `5FFA568149E88FCD5B44D926DCFEAA79`, `metaeditor64.exe`), Python harness (`scripts/f0_runner.py` Model=0 `--deposit` `--input-override`, `extract_trades_from_report.py`), duka `XAUUSD.duk_robo`.

**Spec:** `docs/superpowers/specs/2026-06-09-moneydancer-1.4-autolot-scaling-design.md`

---

### Task 1: Fork 1.3 → 1.4 (verbatim + version bump)

**Files:**
- Create: `mt5/1.4/MoneyDancer_1.4/` (copy of `mt5/1.3/MoneyDancer_1.3/`)
- Modify: `mt5/1.4/MoneyDancer_1.4/MoneyDancer_1.4.mq5` (version strings only)

- [ ] **Step 1: Copy the tree and rename the EA file**

Run (bash, from worktree root):
```bash
mkdir -p mt5/1.4
cp -r mt5/1.3/MoneyDancer_1.3 mt5/1.4/MoneyDancer_1.4
git mv mt5/1.4/MoneyDancer_1.4/MoneyDancer_1.3.mq5 mt5/1.4/MoneyDancer_1.4/MoneyDancer_1.4.mq5 2>/dev/null || mv mt5/1.4/MoneyDancer_1.4/MoneyDancer_1.3.mq5 mt5/1.4/MoneyDancer_1.4/MoneyDancer_1.4.mq5
ls mt5/1.4/MoneyDancer_1.4/
```
Expected: folder lists `MoneyDancer_1.4.mq5`, `Include/`, `presets/` (no `MoneyDancer_1.3.mq5`).

- [ ] **Step 2: Bump version strings (trade-neutral — comments/version/Print only)**

In `mt5/1.4/MoneyDancer_1.4/MoneyDancer_1.4.mq5`, grep for the three `1.3` tokens and change each to `1.4`:
- Line ~2 header comment: `MoneyDancer 1.3` → `MoneyDancer 1.4`.
- Line ~18: `#property version   "1.3"` → `#property version   "1.4"`.
- Line ~49: `Print("MoneyDancer 1.3 init — S1.0 + S1.6 + S3.2 rails (default OFF)");` → `...1.4 init...`.

(Order comments/series keys carry NO version string, so these are trade-neutral. Do NOT touch any Include/.)

- [ ] **Step 3: Deploy + compile**

Run (bash, from worktree root):
```bash
TD="C:/Users/nikof/AppData/Roaming/MetaQuotes/Terminal/5FFA568149E88FCD5B44D926DCFEAA79"
mkdir -p "$TD/MQL5/Experts/MoneyDancer_1.4"
cp -r mt5/1.4/MoneyDancer_1.4/. "$TD/MQL5/Experts/MoneyDancer_1.4/"
"C:/Program Files/RoboForex MT5 Terminal/metaeditor64.exe" /compile:"$TD/MQL5/Experts/MoneyDancer_1.4/MoneyDancer_1.4.mq5" /log:"$TD/compile_md14.log"
python -c "print(open(r'$TD/compile_md14.log',encoding='utf-16').read())"
```
Expected: log says `0 errors, 0 warnings`. metaeditor64 returns exit code 1 even on success — TRUST THE LOG TEXT. Do not proceed past real errors.

- [ ] **Step 4: Commit**

```bash
git add mt5/1.4
git commit -m "chore(1.4): fork MoneyDancer 1.3 -> 1.4 (verbatim + version bump)"
```

---

### Task 2: Auto-lot feature (opt-in)

**Files:**
- Modify: `mt5/1.4/MoneyDancer_1.4/Include/Inputs.mqh` (2 enums + 5 inputs after `LotsBase` line 96)
- Modify: `mt5/1.4/MoneyDancer_1.4/Include/Utils.mqh` (`ComputeBaseLot()` after `ClampLot` line 23)
- Modify: `mt5/1.4/MoneyDancer_1.4/Include/Signal.mqh` (4 call-site swaps)
- Modify: `mt5/1.4/MoneyDancer_1.4/Include/ScenarioE.mqh` (1 call-site swap)

All edits are in the `mt5/1.4/` tree.

- [ ] **Step 1: Add the enums + 5 inputs**

In `Include/Inputs.mqh`, find (line 96):
```cpp
input double LotsBase              = 0.01;  // Basic Order Size
```
Insert immediately after it:
```cpp
// --- v1.4 account-scaled position size (opt-in; AutoLotScaling=false => fixed LotsBase, 1.3-identical) ---
enum AutoLotMetric { Metric_Equity, Metric_Balance };   // dropdown: Equity / Balance
enum AutoLotCalc   { Calc_Add,      Calc_Multiply  };   // dropdown: Add / Multiply
input bool          AutoLotScaling   = false;           // master on/off
input AutoLotMetric AutoLotType      = Metric_Equity;   // scale by Equity (default) or Balance
input AutoLotCalc   AutoLotMode      = Calc_Add;         // Add (default) or Multiply
input double        AutoLotDivisor   = 1000;            // account units per step ("by how much")
input double        AutoLotIncrement = 0.01;            // lot added per unit (Add mode only)
```

- [ ] **Step 2: Add ComputeBaseLot() (Utils.mqh, after ClampLot)**

In `Include/Utils.mqh`, find the end of the `ClampLot` function (starts line 23) — its closing `}`. Insert immediately after it:
```cpp
// v1.4: base lot scaled to account size when AutoLotScaling is on; else the fixed LotsBase.
double ComputeBaseLot()
{
   if(!AutoLotScaling) return LotsBase;                                  // OFF: exact 1.3 path
   double metric = (AutoLotType == Metric_Balance) ? AccountInfoDouble(ACCOUNT_BALANCE)
                                                    : AccountInfoDouble(ACCOUNT_EQUITY);
   double units  = (AutoLotDivisor > 0.0) ? (metric / AutoLotDivisor) : 0.0;   // continuous; guard div0
   double lot    = (AutoLotMode == Calc_Multiply) ? (LotsBase * units)
                                                  : (LotsBase + AutoLotIncrement * units);
   return ClampLot(lot);
}
```
(`Inputs.mqh` (mq5 line 27) precedes `Utils.mqh` (line 29), so the new inputs/enums are visible; `ClampLot` is defined just above, so it resolves.)

- [ ] **Step 3: Swap the four Signal.mqh call sites**

In `Include/Signal.mqh`:
- Line 202 `if(wantPyr)   lots = LotsBase;` → `if(wantPyr)   lots = ComputeBaseLot();`
- Line 203 `if(lots <= 0) lots = LotsBase;` → `if(lots <= 0) lots = ComputeBaseLot();`
- Line 256 `      SendOrder(signalDir, LotsBase, true, TP_Points, false, seriesCmt);` → `      SendOrder(signalDir, ComputeBaseLot(), true, TP_Points, false, seriesCmt);`
- Line 303 `      lot  = ClampLot(LotsBase);` → `      lot  = ClampLot(ComputeBaseLot());`

(After editing, grep `Signal.mqh` for `LotsBase` — there must be NO remaining trade-path reads; the only acceptable remaining matches are none. If any other line reads `LotsBase`, leave it ONLY if it is not one of these four — but these four are the complete trade-path set.)

- [ ] **Step 4: Swap the ScenarioE.mqh call site**

In `Include/ScenarioE.mqh`, line 220:
```cpp
   double lot = MathMin(LotsBase, remaining);
```
→
```cpp
   double lot = MathMin(ComputeBaseLot(), remaining);
```

- [ ] **Step 5: Deploy + compile**

Run (bash, from worktree root):
```bash
TD="C:/Users/nikof/AppData/Roaming/MetaQuotes/Terminal/5FFA568149E88FCD5B44D926DCFEAA79"
cp -r mt5/1.4/MoneyDancer_1.4/. "$TD/MQL5/Experts/MoneyDancer_1.4/"
"C:/Program Files/RoboForex MT5 Terminal/metaeditor64.exe" /compile:"$TD/MQL5/Experts/MoneyDancer_1.4/MoneyDancer_1.4.mq5" /log:"$TD/compile_md14.log"
python -c "print(open(r'$TD/compile_md14.log',encoding='utf-16').read())"
```
Expected: log says `0 errors, 0 warnings`. If `ComputeBaseLot` is "undeclared" at a call site, the include order is wrong — but `Utils.mqh` (mq5:29) precedes `Signal.mqh` (42) and `ScenarioE.mqh` (39), so it resolves. Do not proceed past real errors.

- [ ] **Step 6: Commit**

```bash
git add mt5/1.4/MoneyDancer_1.4/Include/Inputs.mqh \
        mt5/1.4/MoneyDancer_1.4/Include/Utils.mqh \
        mt5/1.4/MoneyDancer_1.4/Include/Signal.mqh \
        mt5/1.4/MoneyDancer_1.4/Include/ScenarioE.mqh
git commit -m "feat(1.4): account-scaled base lot (AutoLotScaling, opt-in; ComputeBaseLot)"
```

---

### Task 3 (run-task): verification — OFF bit-identical + ON formula-correct

**Files:**
- Create: `reports/md1.4-autolot-<UTCstamp>/` (audit evidence, committed)

trading-audit-trail governs. Kill terminal+metatester ONCE before; never between runs.

- [ ] **Step 1: Compile the 1.3 baseline EA (for the OFF comparison)**

Run (bash, from worktree root):
```bash
taskkill //IM terminal64.exe //F 2>/dev/null; taskkill //IM metatester64.exe //F 2>/dev/null; sleep 5
TD="C:/Users/nikof/AppData/Roaming/MetaQuotes/Terminal/5FFA568149E88FCD5B44D926DCFEAA79"
mkdir -p "$TD/MQL5/Experts/MoneyDancer_1.3"
cp -r mt5/1.3/MoneyDancer_1.3/. "$TD/MQL5/Experts/MoneyDancer_1.3/"
"C:/Program Files/RoboForex MT5 Terminal/metaeditor64.exe" /compile:"$TD/MQL5/Experts/MoneyDancer_1.3/MoneyDancer_1.3.mq5" /log:"$TD/compile_md13.log"
python -c "print(open(r'$TD/compile_md13.log',encoding='utf-16').read())"
```
Expected: `0 errors, 0 warnings`.

- [ ] **Step 2: OFF — run 13a on 1.3 and on 1.4 (AutoLotScaling off), same window/deposit**

The author set `TEST 13a M30+.set` is native-1.x and lives at `mt5/1.4/MoneyDancer_1.4/presets/author-reference/TEST 13a M30+.set`. Run (bash, from worktree root):
```bash
SET="$PWD/mt5/1.4/MoneyDancer_1.4/presets/author-reference/TEST 13a M30+.set"
python scripts/f0_runner.py --set-file "$SET" --run-id V14-BASE-13 --symbol XAUUSD.duk_robo --period M30 --model 0 --from-date 2026.04.06 --to-date 2026.04.13 --deposit 10000 --input-override "MaxSpreadPts=45" --expert "MoneyDancer_1.3\\MoneyDancer_1.3.ex5" --timeout 3000
python scripts/extract_trades_from_report.py --report runs/V14-BASE-13/V14-BASE-13-report.htm --out runs/V14-BASE-13/trades.csv
python scripts/f0_runner.py --set-file "$SET" --run-id V14-OFF-14 --symbol XAUUSD.duk_robo --period M30 --model 0 --from-date 2026.04.06 --to-date 2026.04.13 --deposit 10000 --input-override "MaxSpreadPts=45" --expert "MoneyDancer_1.4\\MoneyDancer_1.4.ex5" --timeout 3000
python scripts/extract_trades_from_report.py --report runs/V14-OFF-14/V14-OFF-14-report.htm --out runs/V14-OFF-14/trades.csv
```

- [ ] **Step 3: Assert OFF bit-identical (1.4-OFF == 1.3)**

```bash
python - <<'PY'
import hashlib
a=open("runs/V14-BASE-13/trades.csv","rb").read(); b=open("runs/V14-OFF-14/trades.csv","rb").read()
print("1.3 sha:",hashlib.sha256(a).hexdigest()[:16],"| 1.4-OFF sha:",hashlib.sha256(b).hexdigest()[:16])
print("GATE OFF (1.4-OFF==1.3):","PASS" if a==b else "FAIL")
assert a==b, "OFF changed behavior — ComputeBaseLot is not returning literal LotsBase when AutoLotScaling=false."
PY
```
Expected: `PASS` (same sha256). If FAIL, the off path is not identical — fix Task 2 Step 2.

- [ ] **Step 4: ON — formula-correct runs (ADD @ 5k/50k, MULTIPLY spot, balance spot)**

Enum overrides are integers: `AutoLotScaling=1` (on), `AutoLotType` 0=Equity / 1=Balance, `AutoLotMode` 0=Add / 1=Multiply. Override `MaxLot=100` so the set's own cap can't mask the formula. Run (bash, from worktree root):
```bash
run_on() { # args: runid deposit extra_overrides...
  local rid="$1" dep="$2"; shift 2
  local ov=(--input-override "MaxSpreadPts=45" --input-override "MaxLot=100" --input-override "AutoLotScaling=1")
  for o in "$@"; do ov+=(--input-override "$o"); done
  python scripts/f0_runner.py --set-file "$PWD/mt5/1.4/MoneyDancer_1.4/presets/author-reference/TEST 13a M30+.set" \
    --run-id "$rid" --symbol XAUUSD.duk_robo --period M30 --model 0 --from-date 2026.04.06 --to-date 2026.04.13 \
    --deposit "$dep" "${ov[@]}" --expert "MoneyDancer_1.4\\MoneyDancer_1.4.ex5" --timeout 3000
  python scripts/extract_trades_from_report.py --report "runs/$rid/$rid-report.htm" --out "runs/$rid/trades.csv"
}
run_on V14-ON-ADD-5k   5000   "AutoLotType=0" "AutoLotMode=0"   # ADD/equity   -> 0.01+0.01*5  = 0.06
run_on V14-ON-ADD-50k  50000  "AutoLotType=0" "AutoLotMode=0"   # ADD/equity   -> 0.01+0.01*50 = 0.51
run_on V14-ON-MUL-50k  50000  "AutoLotType=0" "AutoLotMode=1"   # MULTIPLY/eq  -> 0.01*50      = 0.50
run_on V14-ON-BAL-50k  50000  "AutoLotType=1" "AutoLotMode=0"   # ADD/balance  -> 0.01+0.01*50 = 0.51
```

- [ ] **Step 5: Assert first-order lot matches the formula**

```bash
python - <<'PY'
import pandas as pd
def first_in_lot(rid):
    d=pd.read_csv(f"runs/{rid}/trades.csv"); ins=d[d.direction=='in']
    return float(ins.volume.iloc[0])
cases=[("V14-ON-ADD-5k",0.06),("V14-ON-ADD-50k",0.51),("V14-ON-MUL-50k",0.50),("V14-ON-BAL-50k",0.51)]
ok=True
for rid,exp in cases:
    got=first_in_lot(rid); good=abs(got-exp)<1e-9
    ok=ok and good
    print(f"{rid}: first-lot {got}  expected {exp}  {'OK' if good else 'MISMATCH'}")
print("GATE ON (formula-correct):", "PASS" if ok else "FAIL")
PY
```
Expected: all four `OK`, `GATE ON: PASS`. (Lots are exact multiples of the 0.01 broker step, so ClampLot does not alter them.) If a value is off, recheck the `ComputeBaseLot` arithmetic / enum mapping in Task 2.

- [ ] **Step 6: Write the audit folder**

```bash
D="reports/md1.4-autolot-$(python -c "import datetime as d;print(d.datetime.now(d.UTC).strftime('%Y%m%d-%H%M%SZ'))")"
mkdir -p "$D"
cp runs/V14-BASE-13/trades.csv "$D/OFF_1.3_baseline_trades.csv"
cp runs/V14-OFF-14/trades.csv  "$D/OFF_1.4_trades.csv"
for r in V14-ON-ADD-5k V14-ON-ADD-50k V14-ON-MUL-50k V14-ON-BAL-50k; do cp "runs/$r/trades.csv" "$D/${r}_trades.csv"; done
cp "mt5/1.4/MoneyDancer_1.4/presets/author-reference/TEST 13a M30+.set" "$D/"
# result.md: paste the Step-3 OFF sha PASS line + the Step-5 ON formula table + verdict (OFF PASS, ON PASS).
( cd "$D" && for f in *; do echo "$(sha256sum "$f" | cut -c1-16)  $(stat -c%s "$f")  $f"; done > manifest.md )
git add "$D" && git commit -m "evidence(1.4): OFF bit-identical to 1.3 + ON formula-correct (add/multiply/balance)"
```
Expected: committed audit folder; `result.md` shows OFF=PASS (same sha) and ON=PASS (four first-lot values match the formula).

---

## Notes / gotchas
- **Model=0 mandatory** — Model=1 starves the tick/burst engine. Never use it.
- **Kill terminal+metatester ONCE** at batch start, never between runs (breaks the metatester agent pool → "NO REPORT").
- **MaxSpreadPts=45** override needed on duka_robo (13a's native cap of 15 blocks all entries; raw spread 25-28).
- **OFF run must NOT override MaxLot** (keep it bit-identical to 1.3); the ON runs DO override `MaxLot=100` so the formula isn't masked by the set's cap.
- **Enum overrides are integers**: `AutoLotType` 0=Equity/1=Balance, `AutoLotMode` 0=Add/1=Multiply, `AutoLotScaling` 0/1.
