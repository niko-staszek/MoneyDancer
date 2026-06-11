# MoneyDancer 1.6 — Operator Build — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fork 1.5 → 1.6: clean the inputs-panel labels, make the auto-lot default gentler (divisor 2000), and ship one bundled deployable preset (1.3a scalp + 2% daily target + manage-manual-orders).

**Architecture:** Verbatim fork + three low-risk content changes — comment text + one default value in `Include/Inputs.mqh`, and a new preset file. EA stays bit-identical to 1.5 when the opt-in features are off, so the label/divisor edits are verifiable by sha256; the preset is validated separately by backtest.

**Tech Stack:** MQL5 (RoboForex MT5 terminal `5FFA568149E88FCD5B44D926DCFEAA79`, `metaeditor64.exe`), Python harness (`scripts/f0_runner.py` Model=0, `extract_trades_from_report.py`), duka `XAUUSD.duk_robo`.

**Spec:** `docs/superpowers/specs/2026-06-11-moneydancer-1.6-input-label-cleanup-design.md`

---

### Task 1: Fork 1.5 → 1.6 (verbatim + version bump)

**Files:** Create `mt5/1.6/MoneyDancer_1.6/`; Modify `mt5/1.6/MoneyDancer_1.6/MoneyDancer_1.6.mq5`.

- [ ] **Step 1: Copy + rename EA**
```bash
mkdir -p mt5/1.6
cp -r mt5/1.5/MoneyDancer_1.5 mt5/1.6/MoneyDancer_1.6
git mv mt5/1.6/MoneyDancer_1.6/MoneyDancer_1.5.mq5 mt5/1.6/MoneyDancer_1.6/MoneyDancer_1.6.mq5 2>/dev/null || mv mt5/1.6/MoneyDancer_1.6/MoneyDancer_1.5.mq5 mt5/1.6/MoneyDancer_1.6/MoneyDancer_1.6.mq5
ls mt5/1.6/MoneyDancer_1.6/
```
Expected: lists `MoneyDancer_1.6.mq5`, `Include/`, `presets/`.

- [ ] **Step 2: Bump 3 version tokens** in `MoneyDancer_1.6.mq5` (grep them): header comment `MoneyDancer 1.5`→`1.6`, `#property version "1.5"`→`"1.6"`, init `Print("MoneyDancer 1.5 init …")`→`1.6`.

- [ ] **Step 3: Deploy + compile**
```bash
TD="C:/Users/nikof/AppData/Roaming/MetaQuotes/Terminal/5FFA568149E88FCD5B44D926DCFEAA79"
mkdir -p "$TD/MQL5/Experts/MoneyDancer_1.6"
cp -r mt5/1.6/MoneyDancer_1.6/. "$TD/MQL5/Experts/MoneyDancer_1.6/"
"C:/Program Files/RoboForex MT5 Terminal/metaeditor64.exe" /compile:"$TD/MQL5/Experts/MoneyDancer_1.6/MoneyDancer_1.6.mq5" /log:"$TD/compile_md16.log"
python -c "print(open(r'$TD/compile_md16.log',encoding='utf-16').read())"
```
Expected: `0 errors, 0 warnings` (trust log text; metaeditor rc=1 on success is normal).

- [ ] **Step 4: Commit**
```bash
git add mt5/1.6
git commit -m "chore(1.6): fork MoneyDancer 1.5 -> 1.6 (verbatim + version bump)"
```

---

### Task 2: Label cleanup + gentle auto-lot default (`Include/Inputs.mqh`)

**Files:** Modify `mt5/1.6/MoneyDancer_1.6/Include/Inputs.mqh`.

- [ ] **Step 1: Rewrite every input's `// comment` to plain English** per these rules (this is a careful pass over all ~137 input lines + the `//` section header lines):
  - Strip dev tags: `S1.0`/`S1.6`/`S3.2`/`S2.x`/`S5.x`/`A5.x`/`Phase A2`.
  - Strip "-> Test it!", TODO/FIXME, MT4-porting asides ("(MT4 original)", "(was … in MT4)", "(… for 1.1 parity)").
  - Strip redundant `(default OFF)`/`(default 00)` notes (the value column shows the default). KEEP semantic hints `(0=OFF)`/`(-1=OFF)` and reworded recommendations ("recommend 40" → "try 40").
  - Keep the unit (points/%/lots/USD/hour). Keep it concise.
  - Examples (apply the same spirit to ALL):
    - `MaxBasketDD_Pct = 55.0; // Max DD per basket -> hedge. Test it!` → `// Max drawdown per basket before hedge (%)`
    - `MaxBasketLossPct = 0.0; // S1.0 % of equity at series open (0=OFF)` → `// Per-basket equity stop-loss, % at series open (0=OFF)`
    - `MaxAllTimeDDPct = 0.0; // S1.6 ceiling % (0=OFF; recommend 40)` → `// All-time drawdown kill, % (0=OFF; try 40)`
    - `SL_Points = 0; // Stop Loss for Basic Order (MT4 original)` → `// Stop loss for the first order, points (0=OFF)`
    - `FoldManualOrders = false; // include hand-placed (magic==0) same-symbol orders in the basket` → `// Manage hand-placed (magic 0) orders as part of the basket`
  - **CRITICAL: change ONLY text after `//` (and the leading `//` comment lines). Do NOT touch any `input` keyword, type, variable name, `=`, default value, or enum.** (Section-divider VALUE strings `"==== … ===="` may be tidied; if unsure, leave them.)

- [ ] **Step 2: Change the one default value** — find `input double AutoLotDivisor = 1000;` and change `1000` → `2000` (update its comment to note ~0.5 base @100k if helpful). This is the ONLY value change in the file.

- [ ] **Step 3: Verify the diff is comment-only (+ the one value)**
```bash
git -C . diff --no-color mt5/1.6/MoneyDancer_1.6/Include/Inputs.mqh | grep '^[-+]' | grep -vE '^[-+]\s*//' | grep -vE '^[-+]{3}' | grep -E 'input|=' 
```
Expected: the ONLY non-comment changed lines shown are the `AutoLotDivisor` old/new pair. If any other `input … = value` line appears, a value/name was changed by mistake — revert it.

- [ ] **Step 4: Deploy + compile** (same as Task 1 Step 3). Expected `0 errors, 0 warnings`.

- [ ] **Step 5: Commit**
```bash
git add mt5/1.6/MoneyDancer_1.6/Include/Inputs.mqh
git commit -m "refactor(1.6): clean input labels + gentler auto-lot default (AutoLotDivisor 2000)"
```

---

### Task 3: Bundled deployable preset `XAUUSD_1.3a_2pct.set`

**Files:** Create `mt5/1.6/MoneyDancer_1.6/presets/XAUUSD_1.3a_2pct.set`.

- [ ] **Step 1: Build the preset from 1.3a + new settings** (bash, from worktree root):
```bash
python - <<'PY'
import sys, pathlib
sys.path.insert(0, "scripts")
from f0_runner import parse_set_file
src = pathlib.Path("mt5/1.6/MoneyDancer_1.6/presets/author-reference/TEST 1.3a.set")
cfg = parse_set_file(src)   # strips license + ,F/,1/,2/,3 optimizer slots, keeps native 1.x keys
# add the operator-build settings
cfg.update({
    "AutoLotScaling": "1", "AutoLotType": "0", "AutoLotMode": "0",
    "AutoLotDivisor": "2000", "AutoLotIncrement": "0.01",
    "DailyProfitTargetMode": "1", "DailyProfitTargetPct": "2",
    "FoldManualOrders": "true", "MaxAllTimeDDPct": "40",
})
out = pathlib.Path("mt5/1.6/MoneyDancer_1.6/presets/XAUUSD_1.3a_2pct.set")
out.write_text("\n".join(f"{k}={v}" for k, v in cfg.items()) + "\n", encoding="utf-8")
print("wrote", out, "with", len(cfg), "keys")
for k in ("PriceStep","SL_Points","lotMultiplier","StepPoints","AutoLotScaling","AutoLotDivisor","DailyProfitTargetMode","DailyProfitTargetPct","FoldManualOrders","MaxAllTimeDDPct"):
    print(" ", k, "=", cfg.get(k, "MISSING"))
PY
```
Expected: file written; the printed checks show 1.3a params present (PriceStep 0.20, SL_Points 7500, lotMultiplier 1.5, StepPoints 55) AND the new keys (AutoLotScaling 1, AutoLotDivisor 2000, DailyProfitTargetMode 1, DailyProfitTargetPct 2, FoldManualOrders true, MaxAllTimeDDPct 40).

- [ ] **Step 2: Commit**
```bash
git add "mt5/1.6/MoneyDancer_1.6/presets/XAUUSD_1.3a_2pct.set"
git commit -m "feat(1.6): bundled deployable preset XAUUSD_1.3a_2pct (1.3a scalp + auto-lot gentle + 2% daily target + fold-on)"
```

---

### Task 4 (run-task): verification — bit-identical (features off) + preset smoke

**Files:** Create `reports/md1.6-operatorbuild-<UTCstamp>/`.

trading-audit-trail governs. Kill terminal+metatester ONCE before; never between runs.

- [ ] **Step 1: Compile 1.5 baseline**
```bash
taskkill //IM terminal64.exe //F 2>/dev/null; taskkill //IM metatester64.exe //F 2>/dev/null; sleep 5
TD="C:/Users/nikof/AppData/Roaming/MetaQuotes/Terminal/5FFA568149E88FCD5B44D926DCFEAA79"
mkdir -p "$TD/MQL5/Experts/MoneyDancer_1.5"; cp -r mt5/1.5/MoneyDancer_1.5/. "$TD/MQL5/Experts/MoneyDancer_1.5/"
"C:/Program Files/RoboForex MT5 Terminal/metaeditor64.exe" /compile:"$TD/MQL5/Experts/MoneyDancer_1.5/MoneyDancer_1.5.mq5" /log:"$TD/compile_md15.log"
python -c "print(open(r'$TD/compile_md15.log',encoding='utf-16').read())"
```

- [ ] **Step 2: Bit-identical run — 13a (features OFF) on 1.5 vs 1.6**
```bash
SET="$PWD/mt5/1.6/MoneyDancer_1.6/presets/author-reference/TEST 13a M30+.set"
python scripts/f0_runner.py --set-file "$SET" --run-id V16-BASE-15 --symbol XAUUSD.duk_robo --period M30 --model 0 --from-date 2026.04.06 --to-date 2026.04.13 --deposit 10000 --input-override "MaxSpreadPts=45" --expert "MoneyDancer_1.5\\MoneyDancer_1.5.ex5" --timeout 3000
python scripts/extract_trades_from_report.py --report runs/V16-BASE-15/V16-BASE-15-report.htm --out runs/V16-BASE-15/trades.csv
python scripts/f0_runner.py --set-file "$SET" --run-id V16-NEW-16 --symbol XAUUSD.duk_robo --period M30 --model 0 --from-date 2026.04.06 --to-date 2026.04.13 --deposit 10000 --input-override "MaxSpreadPts=45" --expert "MoneyDancer_1.6\\MoneyDancer_1.6.ex5" --timeout 3000
python scripts/extract_trades_from_report.py --report runs/V16-NEW-16/V16-NEW-16-report.htm --out runs/V16-NEW-16/trades.csv
python - <<'PY'
import hashlib
a=open("runs/V16-BASE-15/trades.csv","rb").read(); b=open("runs/V16-NEW-16/trades.csv","rb").read()
print("1.5 sha:",hashlib.sha256(a).hexdigest()[:16],"| 1.6 sha:",hashlib.sha256(b).hexdigest()[:16])
print("GATE bit-identical (features off):","PASS" if a==b else "FAIL")
assert a==b, "1.6 not bit-identical with features off — a label edit hit code, or a default other than AutoLotDivisor changed."
PY
```
Expected: `PASS`, same sha256 (the 13a set leaves AutoLotScaling/FoldManualOrders/DailyProfitTarget OFF, so Part A+B are inert).

- [ ] **Step 3: Preset smoke — XAUUSD_1.3a_2pct loads + auto-lot ~0.5 @100k**
```bash
python scripts/f0_runner.py --set-file "$PWD/mt5/1.6/MoneyDancer_1.6/presets/XAUUSD_1.3a_2pct.set" --run-id V16-PRESET --symbol XAUUSD.duk_robo --period M30 --model 0 --from-date 2026.04.06 --to-date 2026.04.13 --deposit 100000 --input-override "MaxSpreadPts=45" --expert "MoneyDancer_1.6\\MoneyDancer_1.6.ex5" --timeout 3000
python scripts/extract_trades_from_report.py --report runs/V16-PRESET/V16-PRESET-report.htm --out runs/V16-PRESET/trades.csv
python - <<'PY'
import pandas as pd
d=pd.read_csv("runs/V16-PRESET/trades.csv"); ins=d[d.direction=='in']
fl=float(ins.volume.iloc[0]) if len(ins) else 0
print(f"preset ran: deals={len(d)} first-lot={fl}")
print("auto-lot ~0.5 base @100k:", "OK" if 0.40 <= fl <= 0.60 else f"CHECK ({fl})")
PY
```
Expected: preset parses + runs; first-order lot ≈ 0.5 (auto-lot ON, divisor 2000, equity 100k → `0.01+0.01×50=0.51`). Confirms the preset's auto-lot + that the new keys are honored. (The 2%-target / fold behavior is validated by the separate 10-month run + the owner's demo check.)

- [ ] **Step 4: Audit folder**
```bash
D="reports/md1.6-operatorbuild-$(python -c "import datetime as d;print(d.datetime.now(d.UTC).strftime('%Y%m%d-%H%M%SZ'))")"
mkdir -p "$D"
cp runs/V16-BASE-15/trades.csv "$D/OFF_1.5_baseline_trades.csv"
cp runs/V16-NEW-16/trades.csv  "$D/OFF_1.6_trades.csv"
cp runs/V16-PRESET/trades.csv  "$D/preset_1.3a_2pct_trades.csv"
cp "mt5/1.6/MoneyDancer_1.6/presets/XAUUSD_1.3a_2pct.set" "$D/"
git -C . diff 1.5 -- mt5/1.5/MoneyDancer_1.5/Include/Inputs.mqh > /dev/null 2>&1 || true
cat > "$D/result.md" <<'EOF'
# MoneyDancer 1.6 — operator build — verification
Parts: A label cleanup (Inputs.mqh comments), B AutoLotDivisor default 1000->2000, C preset XAUUSD_1.3a_2pct.set.
- GATE bit-identical (13a, features OFF) 1.6 == 1.5: PASS (paste sha line).
- Preset smoke @100k: first-order lot ~0.5 (auto-lot Add/Equity div 2000), preset keys honored: OK (paste line).
NOTE: full 1.3a+2% behavior validated by the separate 10-month worst-fortnight run + owner demo check.
EOF
( cd "$D" && for f in *; do echo "$(sha256sum "$f"|cut -c1-16)  $(stat -c%s "$f")  $f"; done > manifest.md )
git add "$D" && git commit -m "evidence(1.6): bit-identical (features off) + preset smoke (~0.5 lot @100k)"
```
Expected: committed audit folder; result.md shows bit-identical PASS + preset smoke OK.

---

## Notes / gotchas
- **Model=0 mandatory**; **kill terminal+metatester ONCE** at batch start; **MaxSpreadPts=45** on duka_robo.
- The bit-identical gate uses the **13a** set (leaves the opt-in features OFF) — that's why Parts A+B are inert and the sha must match 1.5.
- Do not bake 1.3a into EA code defaults — it ships as the preset (Part C).
