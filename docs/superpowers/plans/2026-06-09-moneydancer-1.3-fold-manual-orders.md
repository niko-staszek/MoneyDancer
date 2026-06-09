# MoneyDancer 1.3 — Fold Manual Orders Into Basket — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fork MoneyDancer 1.2 → 1.3 and add an opt-in feature that folds hand-placed (`magic==0`) orders into the basket's breakeven/TP/exposure/close, without driving martingale.

**Architecture:** New `mt5/1.3/MoneyDancer_1.3/` is a verbatim copy of 1.2 with version bumped. The feature is gated on one input `FoldManualOrders`. Exposure/risk/close folds via a one-line change to `IsMinePosition()`; the combined-breakeven rescue folds via an `includeManual` flag threaded through `CollectBasketPositionsSeries` → `CalcBasketBEWithCostsSeries` and the `ApplyBasketTPSeries` TP loop, using a deterministic single-series adoption helper (`PositionInManagedSeries` + `LowestActiveSeriesId`). The add-side gates are left on the original series filter, so manual orders never trigger grid adds. This EA has no unit-test harness — verification is compile-clean + bit-identical-when-off + a demo forward-test for the on path.

**Tech Stack:** MQL5 (RoboForex MT5 terminal `5FFA568149E88FCD5B44D926DCFEAA79`, `metaeditor64.exe`), Python harness (`scripts/f0_runner.py` Model=0, `extract_trades_from_report.py`), duka `XAUUSD.duk_robo`.

**Spec:** `docs/superpowers/specs/2026-06-09-moneydancer-1.3-fold-manual-orders-design.md`

---

### Task 1: Fork 1.2 → 1.3 (verbatim + version bump)

**Files:**
- Create: `mt5/1.3/MoneyDancer_1.3/` (copy of `mt5/1.2/MoneyDancer_1.2/`)
- Modify: `mt5/1.3/MoneyDancer_1.3/MoneyDancer_1.3.mq5` (version strings only)

- [ ] **Step 1: Copy the tree and rename the EA file**

Run (bash, from worktree root):
```bash
mkdir -p mt5/1.3
cp -r mt5/1.2/MoneyDancer_1.2 mt5/1.3/MoneyDancer_1.3
git mv mt5/1.3/MoneyDancer_1.3/MoneyDancer_1.2.mq5 mt5/1.3/MoneyDancer_1.3/MoneyDancer_1.3.mq5 2>/dev/null || mv mt5/1.3/MoneyDancer_1.3/MoneyDancer_1.2.mq5 mt5/1.3/MoneyDancer_1.3/MoneyDancer_1.3.mq5
ls mt5/1.3/MoneyDancer_1.3/
```
Expected: the folder lists `MoneyDancer_1.3.mq5`, `Include/`, `presets/` (no `MoneyDancer_1.2.mq5`).

- [ ] **Step 2: Bump the version strings (trade-neutral — comments/version/Print only)**

In `mt5/1.3/MoneyDancer_1.3/MoneyDancer_1.3.mq5`:
- Line 2 header comment: change `MoneyDancer 1.2` → `MoneyDancer 1.3`.
- Line 18: change `#property version   "1.2"` → `#property version   "1.3"`.
- Line 49: change `Print("MoneyDancer 1.2 init — S1.0 + S1.6 + S3.2 rails (default OFF)");`
  → `Print("MoneyDancer 1.3 init — S1.0 + S1.6 + S3.2 rails (default OFF)");`

(Order comments/series keys carry NO version string — `SeriesPrefix` is `"TBb"`/`"TBs"` — so these edits do not change any trade. Verified in Task 3.)

- [ ] **Step 3: Deploy + compile**

Run (bash, from worktree root):
```bash
TD="C:/Users/nikof/AppData/Roaming/MetaQuotes/Terminal/5FFA568149E88FCD5B44D926DCFEAA79"
mkdir -p "$TD/MQL5/Experts/MoneyDancer_1.3"
cp -r mt5/1.3/MoneyDancer_1.3/. "$TD/MQL5/Experts/MoneyDancer_1.3/"
"C:/Program Files/RoboForex MT5 Terminal/metaeditor64.exe" /compile:"$TD/MQL5/Experts/MoneyDancer_1.3/MoneyDancer_1.3.mq5" /log:"$TD/compile_md13.log"
python -c "print(open(r'$TD/compile_md13.log',encoding='utf-16').read())"
```
Expected: log says `0 errors, 0 warnings`. metaeditor64 returns exit code 1 even on success — TRUST THE LOG TEXT. Do not proceed past real errors.

- [ ] **Step 4: Commit**

```bash
git add mt5/1.3
git commit -m "chore(1.3): fork MoneyDancer 1.2 -> 1.3 (verbatim + version bump)"
```

---

### Task 2: Fold-manual feature (opt-in)

**Files:**
- Modify: `mt5/1.3/MoneyDancer_1.3/Include/Inputs.mqh` (add input)
- Modify: `mt5/1.3/MoneyDancer_1.3/Include/Utils.mqh` (IsManualPosition + IsMinePosition fold)
- Modify: `mt5/1.3/MoneyDancer_1.3/Include/Series.mqh` (LowestActiveSeriesId + PositionInManagedSeries)
- Modify: `mt5/1.3/MoneyDancer_1.3/Include/Basket.mqh` (includeManual on CollectBasketPositionsSeries + CalcBasketBEWithCostsSeries)
- Modify: `mt5/1.3/MoneyDancer_1.3/Include/ScenarioD.mqh` (ApplyBasketTPSeries uses manual-aware path)

All edits below are in the `mt5/1.3/` tree (NOT 1.2).

- [ ] **Step 1: Add the opt-in input**

In `Include/Inputs.mqh`, find the `MinOrderDistancePts` input line (the grid-distance group) and add immediately after it:
```cpp
input bool   FoldManualOrders      = false;  // include hand-placed (magic==0) same-symbol orders in the basket
```
(Grep `Include/Inputs.mqh` for the line that declares `input ... MinOrderDistancePts` and insert the new line immediately after it — do not assume its default value or line number.)

- [ ] **Step 2: Add IsManualPosition + fold IsMinePosition (Utils.mqh)**

In `Include/Utils.mqh`, find (lines 43-48):
```cpp
bool IsMinePosition()
{
   if(PositionGetString(POSITION_SYMBOL) != _Symbol) return false;
   if(PositionGetInteger(POSITION_MAGIC) != (long)Magic) return false;
   return true;
}
```
Replace with:
```cpp
// True if the currently-selected position is a hand-placed (magic==0) order on this symbol.
bool IsManualPosition()
{
   return (PositionGetString(POSITION_SYMBOL) == _Symbol
           && PositionGetInteger(POSITION_MAGIC) == 0);
}

bool IsMinePosition()
{
   if(PositionGetString(POSITION_SYMBOL) != _Symbol) return false;
   if(PositionGetInteger(POSITION_MAGIC) == (long)Magic) return true;
   if(FoldManualOrders && PositionGetInteger(POSITION_MAGIC) == 0) return true;  // v1.3 fold
   return false;
}
```

- [ ] **Step 3: Add LowestActiveSeriesId + PositionInManagedSeries (Series.mqh)**

In `Include/Series.mqh`, find `int ExtractSeriesIdFromComment(string cmt, int dir)` (line 32) and insert this function immediately ABOVE it (it has no dependencies that follow):
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
      if(PositionGetInteger(POSITION_MAGIC) != (long)Magic) continue;   // EA-owned only (never manual)
      long typ = PositionGetInteger(POSITION_TYPE);
      if(dir > 0 && typ != POSITION_TYPE_BUY)  continue;
      if(dir < 0 && typ != POSITION_TYPE_SELL) continue;
      int id = ExtractSeriesIdFromComment(PositionGetString(POSITION_COMMENT), dir);
      if(id >= 0 && (lowest < 0 || id < lowest)) lowest = id;
   }
   return lowest;
}
```
Then find `bool IsSelectedPositionInSeries(string seriesKey)` (lines 123-127) and insert this function immediately AFTER its closing brace (line 127):
```cpp
// Membership for series-scoped basket math, manual-aware. A magic==0 order (when FoldManualOrders)
// is adopted into exactly ONE series: the lowest active series id of its direction.
bool PositionInManagedSeries(string seriesKey, int dir)
{
   if(IsSelectedPositionInSeries(seriesKey)) return true;            // EA's own series member
   if(FoldManualOrders && IsManualPosition())
   {
      long typ = PositionGetInteger(POSITION_TYPE);
      if((dir > 0 && typ == POSITION_TYPE_BUY) || (dir < 0 && typ == POSITION_TYPE_SELL))
      {
         int low = LowestActiveSeriesId(dir);
         if(low >= 0 && seriesKey == SeriesKey(dir, low)) return true;
      }
   }
   return false;
}
```
(`IsManualPosition` is in Utils.mqh, included at mq5 line 29 — before Series.mqh at line 35 — so it resolves. `SeriesKey` and `IsSelectedPositionInSeries` are above in this same file.)

- [ ] **Step 4: Thread includeManual through CollectBasketPositionsSeries + CalcBasketBEWithCostsSeries (Basket.mqh)**

In `Include/Basket.mqh`, change the signature of `CollectBasketPositionsSeries` (line 175):
```cpp
int CollectBasketPositionsSeries(int dir, string seriesKey, BasketPosition &outArr[])
```
to:
```cpp
int CollectBasketPositionsSeries(int dir, string seriesKey, BasketPosition &outArr[], bool includeManual=false)
```
Inside that function, find (line 188):
```cpp
      if(!IsSelectedPositionInSeries(seriesKey)) continue;
```
replace with:
```cpp
      if(!(includeManual ? PositionInManagedSeries(seriesKey, dir) : IsSelectedPositionInSeries(seriesKey))) continue;
```
Then change the signature of `CalcBasketBEWithCostsSeries` (line 246):
```cpp
bool CalcBasketBEWithCostsSeries(int dir, string seriesKey, double &beOut)
```
to:
```cpp
bool CalcBasketBEWithCostsSeries(int dir, string seriesKey, double &beOut, bool includeManual=false)
```
Inside it, find (line 249):
```cpp
   int n = CollectBasketPositionsSeries(dir, seriesKey, arr);
```
replace with:
```cpp
   int n = CollectBasketPositionsSeries(dir, seriesKey, arr, includeManual);
```
(The three add-side callers at Basket.mqh:338, :354, :433 keep calling `CalcBasketBEWithCostsSeries(dir, seriesKey, be)` — the new `includeManual` defaults to false, so adds stay EA-only. Do NOT edit those three lines.)

- [ ] **Step 5: Make the live TP path manual-aware (ScenarioD.mqh)**

In `Include/ScenarioD.mqh`, inside `ApplyBasketTPSeries`, find (line 21):
```cpp
   if(!CalcBasketBEWithCostsSeries(dir, seriesKey, be)) return;
```
replace with:
```cpp
   if(!CalcBasketBEWithCostsSeries(dir, seriesKey, be, true)) return;   // v1.3: combined BE incl manual
```
Then find the TP-setting loop's membership line (line 34):
```cpp
      if(!IsSelectedPositionInSeries(seriesKey)) continue;
```
replace with:
```cpp
      if(!PositionInManagedSeries(seriesKey, dir)) continue;            // v1.3: set TP on manual order too
```

- [ ] **Step 6: Deploy + compile**

Run (bash, from worktree root):
```bash
TD="C:/Users/nikof/AppData/Roaming/MetaQuotes/Terminal/5FFA568149E88FCD5B44D926DCFEAA79"
cp -r mt5/1.3/MoneyDancer_1.3/. "$TD/MQL5/Experts/MoneyDancer_1.3/"
"C:/Program Files/RoboForex MT5 Terminal/metaeditor64.exe" /compile:"$TD/MQL5/Experts/MoneyDancer_1.3/MoneyDancer_1.3.mq5" /log:"$TD/compile_md13.log"
python -c "print(open(r'$TD/compile_md13.log',encoding='utf-16').read())"
```
Expected: log says `0 errors, 0 warnings`. If `PositionInManagedSeries`/`IsManualPosition`/`LowestActiveSeriesId` are "undeclared", an insertion landed in the wrong file or below its use — confirm Step 2 is in Utils.mqh and Step 3 in Series.mqh. Do not proceed past real errors.

- [ ] **Step 7: Commit**

```bash
git add mt5/1.3/MoneyDancer_1.3/Include/Inputs.mqh \
        mt5/1.3/MoneyDancer_1.3/Include/Utils.mqh \
        mt5/1.3/MoneyDancer_1.3/Include/Series.mqh \
        mt5/1.3/MoneyDancer_1.3/Include/Basket.mqh \
        mt5/1.3/MoneyDancer_1.3/Include/ScenarioD.mqh
git commit -m "feat(1.3): fold manual (magic==0) orders into basket BE/TP/exposure (opt-in)"
```

---

### Task 3 (run-task): verification — OFF bit-identical + ON checklist

**Files:**
- Create: `reports/md1.3-foldmanual-<UTCstamp>/` (audit evidence, committed)

trading-audit-trail governs. Kill terminal+metatester ONCE before; never between runs.

- [ ] **Step 1: Compile the 1.2 baseline EA (for the comparison)**

Run (bash, from worktree root):
```bash
taskkill //IM terminal64.exe //F 2>/dev/null; taskkill //IM metatester64.exe //F 2>/dev/null; sleep 5
TD="C:/Users/nikof/AppData/Roaming/MetaQuotes/Terminal/5FFA568149E88FCD5B44D926DCFEAA79"
mkdir -p "$TD/MQL5/Experts/MoneyDancer_1.2"
cp -r mt5/1.2/MoneyDancer_1.2/. "$TD/MQL5/Experts/MoneyDancer_1.2/"
"C:/Program Files/RoboForex MT5 Terminal/metaeditor64.exe" /compile:"$TD/MQL5/Experts/MoneyDancer_1.2/MoneyDancer_1.2.mq5" /log:"$TD/compile_md12.log"
python -c "print(open(r'$TD/compile_md12.log',encoding='utf-16').read())"
```
Expected: `0 errors, 0 warnings`.

- [ ] **Step 2: Run the same author set on 1.2 and on 1.3 (FoldManualOrders off)**

The author set `TEST 13a M30+.set` is native-1.2 (underscore scheme) and lives at
`mt5/1.3/MoneyDancer_1.3/presets/author-reference/TEST 13a M30+.set`. Run both EAs, same window/deposit,
`FoldManualOrders` left default (off). Run (bash, from worktree root):
```bash
SET="$PWD/mt5/1.3/MoneyDancer_1.3/presets/author-reference/TEST 13a M30+.set"
python scripts/f0_runner.py --set-file "$SET" --run-id V13-BASE-12 --symbol XAUUSD.duk_robo --period M30 --model 0 --from-date 2026.04.06 --to-date 2026.04.13 --deposit 10000 --input-override "MaxSpreadPts=45" --expert "MoneyDancer_1.2\\MoneyDancer_1.2.ex5" --timeout 3000
python scripts/extract_trades_from_report.py --report runs/V13-BASE-12/V13-BASE-12-report.htm --out runs/V13-BASE-12/trades.csv
python scripts/f0_runner.py --set-file "$SET" --run-id V13-OFF-13 --symbol XAUUSD.duk_robo --period M30 --model 0 --from-date 2026.04.06 --to-date 2026.04.13 --deposit 10000 --input-override "MaxSpreadPts=45" --expert "MoneyDancer_1.3\\MoneyDancer_1.3.ex5" --timeout 3000
python scripts/extract_trades_from_report.py --report runs/V13-OFF-13/V13-OFF-13-report.htm --out runs/V13-OFF-13/trades.csv
```

- [ ] **Step 3: Assert bit-identical (OFF == 1.2)**

Run (bash, from worktree root):
```bash
python - <<'PY'
import hashlib
a = open("runs/V13-BASE-12/trades.csv","rb").read()
b = open("runs/V13-OFF-13/trades.csv","rb").read()
print("1.2 sha:", hashlib.sha256(a).hexdigest()[:16], "| 1.3-OFF sha:", hashlib.sha256(b).hexdigest()[:16])
print("GATE (1.3-OFF == 1.2):", "PASS" if a==b else "FAIL")
assert a==b, "OFF changed behavior — a feature branch is not fully gated on FoldManualOrders; inspect IsMinePosition / PositionInManagedSeries (must reduce to the 1.2 path when the flag is false)."
PY
```
Expected: `PASS` (identical sha256). If FAIL, a flag gate is missing — fix in Task 2 and re-run.

- [ ] **Step 4: Write the ON forward-test checklist + audit folder**

The strategy tester cannot inject hand-placed orders, so the ON path is verified on a demo account by the
owner. Write the audit folder (bash, from worktree root):
```bash
D="reports/md1.3-foldmanual-$(python -c "import datetime as d;print(d.datetime.utcnow().strftime('%Y%m%d-%H%M%SZ'))")"
mkdir -p "$D"
cp runs/V13-BASE-12/trades.csv "$D/OFF_1.2_baseline_trades.csv"
cp runs/V13-OFF-13/trades.csv  "$D/OFF_1.3_trades.csv"
cat > "$D/result.md" <<'EOF'
# MoneyDancer 1.3 — fold manual orders — verification

## Gate OFF (bit-identical to 1.2)
13a author set, XAUUSD.duk_robo M30, 2026.04.06-04.13, 10k, MaxSpreadPts=45, FoldManualOrders=false.
1.3-OFF trades.csv sha256 == 1.2 baseline sha256.  => PASS  (paste the Step-3 sha line here)

## ON forward-test checklist (owner, demo — tester cannot place manual orders)
With FoldManualOrders=true on a demo chart, once the EA holds an active basket in direction D, hand-open a
magic==0 order in direction D, then confirm from journal/dashboard:
[ ] basket breakeven shifts to include the manual lot
[ ] common TP re-levels; a TP is set on the manual order at BE +/- bePoints
[ ] when the basket hits TP (or a kill-switch fires), the manual order closes WITH the basket
[ ] EA add cadence unchanged: no extra grid orders are opened because of the manual order
[ ] lone manual order with NO active EA basket in its direction: counted in exposure/DD only, no TP set
Status: PENDING demo run.
EOF
( cd "$D" && for f in *; do echo "$(sha256sum "$f" | cut -c1-16)  $(stat -c%s "$f")  $f"; done > manifest.md )
git add "$D" && git commit -m "evidence(1.3): OFF bit-identical to 1.2 + ON forward-test checklist"
```
Expected: committed audit folder; `result.md` shows OFF=PASS and the ON checklist marked PENDING demo.

---

## Notes / gotchas
- **Model=0 mandatory** — Model=1 starves the tick/burst engine. Never use it.
- **Kill terminal+metatester ONCE** at batch start, never between runs (breaks the metatester agent pool → "NO REPORT").
- **MaxSpreadPts=45** override needed on duka_robo (13a's native cap of 15 blocks all entries; raw spread 25-28).
- **OFF must be byte-identical** — that is the core acceptance for the EA edits. The ON path is owner-verified on demo because the tester has no concept of a manual order.
