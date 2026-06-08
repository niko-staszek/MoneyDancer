# MoneyDancer 3.1 — Equity-Scaled Auto-Lot — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an opt-in `LotsBasePerThousand` input to MoneyDancer 3.0 so the base lot scales with equity (`equity/1000 × it`), defaulting OFF so existing sets stay bit-identical.

**Architecture:** A new input + a `ComputeBaseLot()` helper in `Utils.mqh`; replace the 5 trade-path `LotsBase` uses with `ComputeBaseLot()`. The martingale auto-scales because it derives from the first order's actual volume. OFF (`=0`) returns `LotsBase` → behavior unchanged.

**Tech Stack:** MQL5 (the EA), RoboForex MT5 tester + MetaEditor, Python (verification).

**Spec:** `docs/superpowers/specs/2026-06-08-moneydancer-3.1-auto-lot-design.md`

**Working tree (`WT`):** `C:\Users\nikof\Documents\GitHub\MoneyDancer\.claude\worktrees\reverent-panini-6271e7` (branch `claude/reverent-panini-6271e7`). EA at `mt5/3.0/MoneyDancer_3.0/`. Run from WT.

**Terminal:** `C:\Program Files\RoboForex MT5 Terminal\terminal64.exe`; data folder `…\Terminal\5FFA568149E88FCD5B44D926DCFEAA79`; `metaeditor64.exe`. 3.0 deploy: `<dataFolder>\MQL5\Experts\MoneyDancer_3.0\`.

**Evidence discipline (trading-audit-trail):** v3.1 is accepted only if (a) OFF is per-deal identical to the v3.0 baseline AND (b) ON scales proportionally (5k vs 50k → ~10× lots/net, same deal count). Both runs + diffs go into `reports/md3.1-autolot-<UTCstamp>/` with a sha256 manifest.

---

### Task 1: EA change — add `LotsBasePerThousand` + `ComputeBaseLot()`, wire 5 call sites, compile

**Files:**
- Modify: `mt5/3.0/MoneyDancer_3.0/Include/Inputs.mqh:96`
- Modify: `mt5/3.0/MoneyDancer_3.0/Include/Utils.mqh` (after `ClampLot`, ~line 37)
- Modify: `mt5/3.0/MoneyDancer_3.0/Include/Signal.mqh:202,203,256,303`
- Modify: `mt5/3.0/MoneyDancer_3.0/Include/ScenarioE.mqh:220`

- [ ] **Step 1: Add the input** (`Inputs.mqh`, after line 96)

Find:
```cpp
input double LotsBase              = 0.01;  // Basic Order Size
```
Replace with:
```cpp
input double LotsBase              = 0.01;  // Basic Order Size
input double LotsBasePerThousand   = 0.0;   // >0: base lot = equity/1000 * this (0 = fixed LotsBase)
```

- [ ] **Step 2: Add `ComputeBaseLot()`** (`Utils.mqh`, immediately after the `ClampLot` function's closing `}`)

Find (the end of ClampLot):
```cpp
   if(step > 0.0) lot = MathFloor(lot / step) * step;
   lot = NormalizeDouble(lot, 2);
   if(lot < minLot) lot = minLot;
   return lot;
}
```
Replace with:
```cpp
   if(step > 0.0) lot = MathFloor(lot / step) * step;
   lot = NormalizeDouble(lot, 2);
   if(lot < minLot) lot = minLot;
   return lot;
}

// Base order lot. When LotsBasePerThousand>0, scale by current equity
// (equity/1000 * that), clamped to broker limits; else the fixed LotsBase.
double ComputeBaseLot()
{
   if(LotsBasePerThousand <= 0.0) return LotsBase;
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   return ClampLot((eq / 1000.0) * LotsBasePerThousand);
}
```

- [ ] **Step 3: Wire the 5 trade-path call sites** (`Signal.mqh` ×4, `ScenarioE.mqh` ×1)

In `Signal.mqh`, find:
```cpp
   if(wantPyr)   lots = LotsBase;     // pyramid always uses basic lot
   if(lots <= 0) lots = LotsBase;
```
replace with:
```cpp
   if(wantPyr)   lots = ComputeBaseLot();   // pyramid always uses basic lot
   if(lots <= 0) lots = ComputeBaseLot();
```

In `Signal.mqh`, find:
```cpp
      SendOrder(signalDir, LotsBase, true, TpPoints, false, seriesCmt);
```
replace with:
```cpp
      SendOrder(signalDir, ComputeBaseLot(), true, TpPoints, false, seriesCmt);
```

In `Signal.mqh`, find (the recovering-toward-BE base add):
```cpp
      lot  = ClampLot(LotsBase);
      cmtD = seriesCmt + "|DB";
```
replace with:
```cpp
      lot  = ClampLot(ComputeBaseLot());
      cmtD = seriesCmt + "|DB";
```

In `ScenarioE.mqh`, find:
```cpp
   double lot = MathMin(LotsBase, remaining);
```
replace with:
```cpp
   double lot = MathMin(ComputeBaseLot(), remaining);
```

(Do NOT change `Inputs.mqh`'s `LotsBase` declaration, `ClampLot`, or `Signal.mqh:296`'s
`firstLot * LotMultiplier^N` — `firstLot` reads the first order's actual volume, so the martingale
auto-scales once the first order uses `ComputeBaseLot()`.)

- [ ] **Step 4: Deploy + compile**

Run (bash, from WT):
```bash
TD="C:/Users/nikof/AppData/Roaming/MetaQuotes/Terminal/5FFA568149E88FCD5B44D926DCFEAA79"
cp -r mt5/3.0/MoneyDancer_3.0/. "$TD/MQL5/Experts/MoneyDancer_3.0/"
"C:/Program Files/RoboForex MT5 Terminal/metaeditor64.exe" /compile:"$TD/MQL5/Experts/MoneyDancer_3.0/MoneyDancer_3.0.mq5" /log:"$TD/compile_md31.log"
python -c "print(open(r'$TD/compile_md31.log',encoding='utf-16').read())"
```
Expected: `0 errors, 0 warnings`. If `ComputeBaseLot` is "undeclared" at a call site, the include order
is wrong — but `Utils.mqh` (mq5:29) precedes `ScenarioE.mqh` (39) and `Signal.mqh` (42), so it should
resolve; if not, move the `Utils.mqh` include above them. Do not proceed past errors.

- [ ] **Step 5: Commit**

```bash
git add mt5/3.0/MoneyDancer_3.0/Include/Inputs.mqh mt5/3.0/MoneyDancer_3.0/Include/Utils.mqh \
        mt5/3.0/MoneyDancer_3.0/Include/Signal.mqh mt5/3.0/MoneyDancer_3.0/Include/ScenarioE.mqh
git commit -m "feat(3.1): equity-scaled auto-lot (LotsBasePerThousand, opt-in; ComputeBaseLot)"
```

---

### Task 2 (run-task): verification — OFF bit-identical + ON proportional

**Files:**
- Create: `reports/md3.1-autolot-<UTCstamp>/` (audit evidence, committed)

trading-audit-trail governs. Run serially (kill terminal+metatester ONCE before, never between).

- [ ] **Step 1: Gate (a) — OFF must be bit-identical to v3.0**

Run (bash, from WT) — 13a (which has no `LotsBasePerThousand` → defaults 0), same window as the v3.0
baseline:
```bash
taskkill //IM terminal64.exe //F 2>/dev/null; taskkill //IM metatester64.exe //F 2>/dev/null; sleep 5
python -c "import sys; sys.path.insert(0,'scripts'); from translate_set import to_3_0; to_3_0(r'C:/Users/nikof/Downloads/TEST 13a M30+.set','test13a_3.0.set')"
python scripts/f0_runner.py --set-file "$PWD/test13a_3.0.set" --run-id V31-OFF --symbol XAUUSD.duk_robo --period M30 --model 0 --from-date 2026.04.06 --to-date 2026.04.13 --deposit 10000 --input-override "MaxSpreadPts=45" --expert "MoneyDancer_3.0\\MoneyDancer_3.0.ex5" --timeout 3000
python scripts/extract_trades_from_report.py --report runs/V31-OFF/V31-OFF-report.htm --out runs/V31-OFF/trades.csv
python - <<'PY'
import pandas as pd, hashlib
new = open("runs/V31-OFF/trades.csv","rb").read()
base = open("reports/md3.0-rename-20260608/trades_3.0.csv","rb").read()
print("OFF sha:", hashlib.sha256(new).hexdigest()[:16], "| v3.0 sha:", hashlib.sha256(base).hexdigest()[:16])
print("OFF==v3.0 BIT-IDENTICAL:", "PASS" if new == base else "FAIL")
assert new == base, "OFF changed behavior — STOP, a call-site edit altered the off path."
PY
```
Expected: `PASS` (same sha256 as the v3.0 baseline). If FAIL, a replacement changed the off path (e.g.
`ComputeBaseLot()` not returning exactly `LotsBase` when off) — fix and re-verify.

- [ ] **Step 2: Gate (b) — ON scales proportionally (5k vs 50k)**

Run (bash, from WT) — 13a with `LotsBasePerThousand=0.002` at two deposits, same window:
```bash
for DEP in 5000 50000; do
  python scripts/f0_runner.py --set-file "$PWD/test13a_3.0.set" --run-id V31-ON-$DEP --symbol XAUUSD.duk_robo --period M30 --model 0 --from-date 2026.04.06 --to-date 2026.04.13 --deposit $DEP --input-override "MaxSpreadPts=45" --input-override "LotsBasePerThousand=0.002" --expert "MoneyDancer_3.0\\MoneyDancer_3.0.ex5" --timeout 3000
  python scripts/extract_trades_from_report.py --report runs/V31-ON-$DEP/V31-ON-$DEP-report.htm --out runs/V31-ON-$DEP/trades.csv
done
python - <<'PY'
import pandas as pd
a=pd.read_csv("runs/V31-ON-5000/trades.csv"); b=pd.read_csv("runs/V31-ON-50000/trades.csv")
ao,bo=a[a.direction=='out'],b[b.direction=='out']
print(f"5k:  deals={len(a)} net={ao.profit.sum():.0f} maxlot={a.volume.max()}")
print(f"50k: deals={len(b)} net={bo.profit.sum():.0f} maxlot={b.volume.max()}")
print(f"deal-count equal: {len(a)==len(b)} | lot ratio ~10x: {round(b.volume.max()/a.volume.max(),1)} | net ratio ~10x: {round(bo.profit.sum()/ao.profit.sum(),1)}")
PY
```
Expected: equal (or near-equal) deal count; max-lot ratio ≈ 10; net ratio ≈ 10 (so % return ≈ equal).
A clean 10× confirms equity-scaling is applied and proportional. (Minor deal-count drift is acceptable if
broker min-lot clamping floors the 5k base — note it if so.)

- [ ] **Step 3: Audit folder + commit**

Create `reports/md3.1-autolot-<UTC>/` with: `V31-OFF/trades.csv` + the v3.0 baseline it matched, both
`V31-ON-*/trades.csv`, a `result.md` (gate-a PASS sha + gate-b ratios), the `.set`, and `manifest.md`
(sha256 + verdict). Commit:
```bash
git add reports/md3.1-autolot-* 
git commit -m "evidence(3.1): auto-lot verified — OFF bit-identical + ON ~10x proportional"
```

---

## Self-Review

**1. Spec coverage:**
- §2 new input `LotsBasePerThousand` default 0 → Task 1 Step 1. ✓
- §3 `ComputeBaseLot` + 5 call-site replacements + martingale untouched → Task 1 Steps 2-3. ✓
- §4 verification (off bit-identical, on proportional, compile) → Task 1 Step 4 + Task 2. ✓
- §5 audit folder + manifest → Task 2 Step 3. ✓
- §6 out of scope (only the one input + helper) → plan touches nothing else. ✓

**2. Placeholder scan:** No TBD. `<UTCstamp>` is runtime. Every edit shows exact find/replace; every run
shows exact commands + expected output.

**3. Type consistency:** `ComputeBaseLot()` (defined Task 1 Step 2, in `Utils.mqh`) is the exact symbol
called at all 5 sites (Step 3) and relies on `ClampLot`/`LotsBase`/`LotsBasePerThousand` all present in
the same 3.0 tree. The verify consumes `trades.csv` from `extract_trades_from_report.py` (existing) and
the committed v3.0 baseline `reports/md3.0-rename-20260608/trades_3.0.csv`. ✓
