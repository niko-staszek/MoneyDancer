# MoneyDancer 1.5 — Rename Daily Profit-Target Inputs — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fork MoneyDancer 1.4 → 1.5 and rename the equity-gated daily-target inputs (`ProfitTarget*` → `DailyProfitTarget*`) for clarity — zero behavior change.

**Architecture:** Verbatim copy of 1.4 with version bump, then a whole-word rename of 7 identifiers in exactly 2 files (Inputs.mqh, Risk.mqh). Defaults and enum ordering are preserved, so the EA is bit-identical to 1.4. No unit-test harness; verification is compile-clean + bit-identical-by-sha256.

**Tech Stack:** MQL5 (RoboForex MT5 terminal `5FFA568149E88FCD5B44D926DCFEAA79`, `metaeditor64.exe`), Python harness (`scripts/f0_runner.py` Model=0, `extract_trades_from_report.py`), duka `XAUUSD.duk_robo`.

**Spec:** `docs/superpowers/specs/2026-06-11-moneydancer-1.5-rename-daily-profit-target-design.md`

---

### Task 1: Fork 1.4 → 1.5 (verbatim + version bump)

**Files:**
- Create: `mt5/1.5/MoneyDancer_1.5/` (copy of `mt5/1.4/MoneyDancer_1.4/`)
- Modify: `mt5/1.5/MoneyDancer_1.5/MoneyDancer_1.5.mq5` (version strings only)

- [ ] **Step 1: Copy the tree and rename the EA file**

Run (bash, from worktree root):
```bash
mkdir -p mt5/1.5
cp -r mt5/1.4/MoneyDancer_1.4 mt5/1.5/MoneyDancer_1.5
git mv mt5/1.5/MoneyDancer_1.5/MoneyDancer_1.4.mq5 mt5/1.5/MoneyDancer_1.5/MoneyDancer_1.5.mq5 2>/dev/null || mv mt5/1.5/MoneyDancer_1.5/MoneyDancer_1.4.mq5 mt5/1.5/MoneyDancer_1.5/MoneyDancer_1.5.mq5
ls mt5/1.5/MoneyDancer_1.5/
```
Expected: lists `MoneyDancer_1.5.mq5`, `Include/`, `presets/` (no `MoneyDancer_1.4.mq5`).

- [ ] **Step 2: Bump the three `1.4` version tokens** in `mt5/1.5/MoneyDancer_1.5/MoneyDancer_1.5.mq5` (grep to find exact lines):
- Line ~2 header comment: `MoneyDancer 1.4` → `MoneyDancer 1.5`.
- Line ~18: `#property version   "1.4"` → `#property version   "1.5"`.
- Line ~49: `Print("MoneyDancer 1.4 init — ...")` → `...1.5 init...` (only the version number changes).

- [ ] **Step 3: Deploy + compile**

```bash
TD="C:/Users/nikof/AppData/Roaming/MetaQuotes/Terminal/5FFA568149E88FCD5B44D926DCFEAA79"
mkdir -p "$TD/MQL5/Experts/MoneyDancer_1.5"
cp -r mt5/1.5/MoneyDancer_1.5/. "$TD/MQL5/Experts/MoneyDancer_1.5/"
"C:/Program Files/RoboForex MT5 Terminal/metaeditor64.exe" /compile:"$TD/MQL5/Experts/MoneyDancer_1.5/MoneyDancer_1.5.mq5" /log:"$TD/compile_md15.log"
python -c "print(open(r'$TD/compile_md15.log',encoding='utf-16').read())"
```
Expected: `0 errors, 0 warnings`. metaeditor64 returns exit code 1 even on success — TRUST THE LOG TEXT. Do not proceed past real errors.

- [ ] **Step 4: Commit**

```bash
git add mt5/1.5
git commit -m "chore(1.5): fork MoneyDancer 1.4 -> 1.5 (verbatim + version bump)"
```

---

### Task 2: Rename the daily-target identifiers

**Files:**
- Modify: `mt5/1.5/MoneyDancer_1.5/Include/Inputs.mqh`
- Modify: `mt5/1.5/MoneyDancer_1.5/Include/Risk.mqh`

- [ ] **Step 1: Confirm the rename footprint (before)**

```bash
grep -rnoE "ENUM_PROFIT_TARGET_MODE|PROFIT_TARGET_OFF|PROFIT_TARGET_PCT|PROFIT_TARGET_USD|ProfitTargetMode|ProfitTargetPct|ProfitTargetUsd" mt5/1.5/MoneyDancer_1.5/Include/ | sort | uniq -c
```
Expected: matches only in `Inputs.mqh` and `Risk.mqh` (≈19 occurrences total across the 7 tokens).

- [ ] **Step 2: Apply the whole-word rename (longest tokens first to avoid partial overlaps)**

Run (bash, from worktree root) — the order matters: rename the enum-type and `Mode/Pct/Usd` identifiers before the `PROFIT_TARGET_*` enum values, and use word boundaries so e.g. `ProfitTargetMode` is not also hit by the `ProfitTargetPct` pass:
```bash
for f in mt5/1.5/MoneyDancer_1.5/Include/Inputs.mqh mt5/1.5/MoneyDancer_1.5/Include/Risk.mqh; do
  sed -i -E \
    -e 's/\bENUM_PROFIT_TARGET_MODE\b/ENUM_DAILY_TARGET_MODE/g' \
    -e 's/\bProfitTargetMode\b/DailyProfitTargetMode/g' \
    -e 's/\bProfitTargetPct\b/DailyProfitTargetPct/g' \
    -e 's/\bProfitTargetUsd\b/DailyProfitTargetUsd/g' \
    -e 's/\bPROFIT_TARGET_OFF\b/DAILY_TARGET_OFF/g' \
    -e 's/\bPROFIT_TARGET_PCT\b/DAILY_TARGET_PCT/g' \
    -e 's/\bPROFIT_TARGET_USD\b/DAILY_TARGET_USD/g' \
    "$f"
done
```

- [ ] **Step 3: Verify the rename (after — old tokens gone, new tokens present, no other files touched)**

```bash
echo "old tokens remaining (want 0):"
grep -rnoE "ENUM_PROFIT_TARGET_MODE|PROFIT_TARGET_OFF|PROFIT_TARGET_PCT|PROFIT_TARGET_USD|ProfitTargetMode|ProfitTargetPct|ProfitTargetUsd" mt5/1.5/MoneyDancer_1.5/ | wc -l
echo "new tokens present:"
grep -rnoE "ENUM_DAILY_TARGET_MODE|DAILY_TARGET_(OFF|PCT|USD)|DailyProfitTarget(Mode|Pct|Usd)" mt5/1.5/MoneyDancer_1.5/Include/ | sort | uniq -c
echo "only Inputs.mqh + Risk.mqh changed vs 1.4:"
diff -rq mt5/1.4/MoneyDancer_1.4/Include mt5/1.5/MoneyDancer_1.5/Include | grep -v "MoneyDancer_1" || true
```
Expected: old tokens = `0`; new tokens listed; the diff lists ONLY `Inputs.mqh` and `Risk.mqh` as differing.

- [ ] **Step 4: Deploy + compile**

```bash
TD="C:/Users/nikof/AppData/Roaming/MetaQuotes/Terminal/5FFA568149E88FCD5B44D926DCFEAA79"
cp -r mt5/1.5/MoneyDancer_1.5/. "$TD/MQL5/Experts/MoneyDancer_1.5/"
"C:/Program Files/RoboForex MT5 Terminal/metaeditor64.exe" /compile:"$TD/MQL5/Experts/MoneyDancer_1.5/MoneyDancer_1.5.mq5" /log:"$TD/compile_md15.log"
python -c "print(open(r'$TD/compile_md15.log',encoding='utf-16').read())"
```
Expected: `0 errors, 0 warnings`. If a `DAILY_TARGET_*`/`DailyProfitTarget*` identifier is "undeclared", a token was missed — re-check Step 2. Do not proceed past real errors.

- [ ] **Step 5: Commit**

```bash
git add mt5/1.5/MoneyDancer_1.5/Include/Inputs.mqh mt5/1.5/MoneyDancer_1.5/Include/Risk.mqh
git commit -m "refactor(1.5): rename ProfitTarget* -> DailyProfitTarget* (clarity; behavior-identical)"
```

---

### Task 3 (run-task): verification — bit-identical to 1.4

**Files:**
- Create: `reports/md1.5-rename-<UTCstamp>/` (audit evidence, committed)

trading-audit-trail governs. Kill terminal+metatester ONCE before; never between runs.

- [ ] **Step 1: Compile the 1.4 baseline EA**

```bash
taskkill //IM terminal64.exe //F 2>/dev/null; taskkill //IM metatester64.exe //F 2>/dev/null; sleep 5
TD="C:/Users/nikof/AppData/Roaming/MetaQuotes/Terminal/5FFA568149E88FCD5B44D926DCFEAA79"
mkdir -p "$TD/MQL5/Experts/MoneyDancer_1.4"
cp -r mt5/1.4/MoneyDancer_1.4/. "$TD/MQL5/Experts/MoneyDancer_1.4/"
"C:/Program Files/RoboForex MT5 Terminal/metaeditor64.exe" /compile:"$TD/MQL5/Experts/MoneyDancer_1.4/MoneyDancer_1.4.mq5" /log:"$TD/compile_md14.log"
python -c "print(open(r'$TD/compile_md14.log',encoding='utf-16').read())"
```
Expected: `0 errors, 0 warnings`.

- [ ] **Step 2: Run the same author set on 1.4 and 1.5 (no overrides → renamed control inert/OFF)**

```bash
SET="$PWD/mt5/1.5/MoneyDancer_1.5/presets/author-reference/TEST 13a M30+.set"
python scripts/f0_runner.py --set-file "$SET" --run-id V15-BASE-14 --symbol XAUUSD.duk_robo --period M30 --model 0 --from-date 2026.04.06 --to-date 2026.04.13 --deposit 10000 --input-override "MaxSpreadPts=45" --expert "MoneyDancer_1.4\\MoneyDancer_1.4.ex5" --timeout 3000
python scripts/extract_trades_from_report.py --report runs/V15-BASE-14/V15-BASE-14-report.htm --out runs/V15-BASE-14/trades.csv
python scripts/f0_runner.py --set-file "$SET" --run-id V15-NEW-15 --symbol XAUUSD.duk_robo --period M30 --model 0 --from-date 2026.04.06 --to-date 2026.04.13 --deposit 10000 --input-override "MaxSpreadPts=45" --expert "MoneyDancer_1.5\\MoneyDancer_1.5.ex5" --timeout 3000
python scripts/extract_trades_from_report.py --report runs/V15-NEW-15/V15-NEW-15-report.htm --out runs/V15-NEW-15/trades.csv
```

- [ ] **Step 3: Assert bit-identical (1.5 == 1.4)**

```bash
python - <<'PY'
import hashlib
a=open("runs/V15-BASE-14/trades.csv","rb").read(); b=open("runs/V15-NEW-15/trades.csv","rb").read()
print("1.4 sha:",hashlib.sha256(a).hexdigest()[:16],"| 1.5 sha:",hashlib.sha256(b).hexdigest()[:16])
print("GATE (1.5==1.4):","PASS" if a==b else "FAIL")
assert a==b, "Rename changed behavior — impossible unless a default/enum-order/logic edit slipped in; inspect the Task-2 diff."
PY
```
Expected: `PASS` (same sha256). If FAIL, the rename was not pure — re-check Task 2 for an accidental default/order change.

- [ ] **Step 4: Write the audit folder**

```bash
D="reports/md1.5-rename-$(python -c "import datetime as d;print(d.datetime.now(d.UTC).strftime('%Y%m%d-%H%M%SZ'))")"
mkdir -p "$D"
cp runs/V15-BASE-14/trades.csv "$D/baseline_1.4_trades.csv"
cp runs/V15-NEW-15/trades.csv  "$D/renamed_1.5_trades.csv"
cat > "$D/result.md" <<'EOF'
# MoneyDancer 1.5 — rename ProfitTarget* -> DailyProfitTarget* — verification
Pure identifier rename (7 tokens, Inputs.mqh + Risk.mqh). Defaults/enum-order/logic unchanged.
13a author set, XAUUSD.duk_robo M30, 2026.04.06-04.13, 10k, MaxSpreadPts=45.
1.4 sha256 == 1.5 sha256  => BIT-IDENTICAL: PASS  (paste the Step-3 sha line here).
EOF
( cd "$D" && for f in *; do echo "$(sha256sum "$f"|cut -c1-16)  $(stat -c%s "$f")  $f"; done > manifest.md )
git add "$D" && git commit -m "evidence(1.5): rename bit-identical to 1.4 (same sha)"
```
Expected: committed audit folder; `result.md` shows BIT-IDENTICAL PASS.

---

## Notes / gotchas
- **Model=0 mandatory**; **kill terminal+metatester ONCE** at batch start, never between runs; **MaxSpreadPts=45** on duka_robo.
- The renamed control defaults OFF (`DailyProfitTargetMode = DAILY_TARGET_OFF`), so the bit-identical run never exercises it — that is correct; the rename's only acceptance is "no trade changed."
