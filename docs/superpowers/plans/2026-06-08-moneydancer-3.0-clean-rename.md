# MoneyDancer 3.0 — Clean Rename of 1.2 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fork MoneyDancer 1.2 into a new `mt5/3.0/MoneyDancer_3.0` with all 131 inputs renamed to one frozen camelCase/PascalCase scheme and story-tag comments stripped, with **zero behavior change** proven by a bit-identical backtest.

**Architecture:** A deterministic `to_v3(name)` rule generates the canonical `1.2 → 3.0` name-map from `Inputs.mqh`. That single map drives (a) a word-boundary source rename across the forked tree and (b) the `translate_set.py` porter. Verification = compile 0 errors + per-deal-identical backtest (13a + 35k on 1.2 vs 3.0).

**Tech Stack:** Python 3.13 + pytest (map + rename tooling), MQL5 (the EA), RoboForex MT5 tester + MetaEditor.

**Spec:** `docs/superpowers/specs/2026-06-04-moneydancer-3.0-clean-rename-design.md`

**Working tree (`WT`):** `C:\Users\nikof\Documents\GitHub\MoneyDancer\.claude\worktrees\reverent-panini-6271e7` (branch `claude/reverent-panini-6271e7`). All work + commits here. Run python from `WT`.

**Terminal:** `C:\Program Files\RoboForex MT5 Terminal\terminal64.exe`; data folder `…\Terminal\5FFA568149E88FCD5B44D926DCFEAA79`; `metaeditor64.exe` alongside. 3.0 deploy target: `<dataFolder>\MQL5\Experts\MoneyDancer_3.0\`.

**Evidence discipline (trading-audit-trail):** the bit-identical verification writes both runs' `trades.csv`, the diff result (zero), the name-map, and a manifest into `reports/md3.0-rename-<UTCstamp>/`. v3.0 is accepted ONLY if the per-deal diff is empty.

---

## File Structure
- Create: `WT/scripts/v3_namemap.py` — `to_v3(name)` rule + `build_map(inputs_mqh)` → `{old:new}` dict.
- Create: `WT/scripts/tests/test_v3_namemap.py` — pytest for the rule + collision check.
- Create: `WT/scripts/v3_rename.py` — apply a name-map to a source tree (word-boundary, longest-first).
- Create: `WT/scripts/tests/test_v3_rename.py` — pytest for the rename function.
- Create: `WT/mt5/3.0/MoneyDancer_3.0/` — forked + renamed EA (generated, committed).
- Create: `WT/mt5/3.0/MoneyDancer_3.0/NAMING.md` — frozen scheme + full map.
- Modify: `WT/scripts/translate_set.py` — add the `1.2 → 3.0` porter map.

---

### Task 1: `to_v3` naming rule + map generator

**Files:**
- Create: `WT/scripts/v3_namemap.py`
- Create: `WT/scripts/tests/test_v3_namemap.py`

The deterministic rule (spec §3): PascalCase first letter; drop underscores (capitalizing the next
letter); any run of 2+ uppercase letters (an acronym) → Title-case (`TP`→`Tp`, `DD`→`Dd`, `ADX`→`Adx`).

- [ ] **Step 1: Write the failing test**

```python
# WT/scripts/tests/test_v3_namemap.py
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from v3_namemap import to_v3, build_map

def test_to_v3_cases():
    cases = {
        "lotMultiplier": "LotMultiplier", "maPeriod": "MaPeriod", "startBe": "StartBe",
        "TP_Points": "TpPoints", "SL_Points": "SlPoints", "bePoints": "BePoints",
        "slopeThresholdPts": "SlopeThresholdPts", "MonStart1_Hour": "MonStart1Hour",
        "MaxBasketDD_Pct": "MaxBasketDdPct", "MaxEquityDD_Pct": "MaxEquityDdPct",
        "MaxAllTimeDDPct": "MaxAllTimeDdPct", "RunnerBE_StartPts": "RunnerBeStartPts",
        "PyramBEBufPts": "PyramBeBufPts", "RegimeAdxThresh": "RegimeAdxThresh",
        "StepPoints": "StepPoints", "MaxOrdersDir": "MaxOrdersDir", "Magic": "Magic",
        "ShowProDashboard": "ShowProDashboard",
    }
    for old, new in cases.items():
        assert to_v3(old) == new, f"{old} -> {to_v3(old)} (want {new})"

def test_build_map_no_collisions(tmp_path):
    mqh = tmp_path / "Inputs.mqh"
    mqh.write_text(
        "input double lotMultiplier = 1.5;\n"
        "input int TP_Points = 60;\n"
        "input int MonStart1_Hour = 3;\n"
        "input int StepPoints = 35;\n")
    m = build_map(mqh)
    assert m == {"lotMultiplier": "LotMultiplier", "TP_Points": "TpPoints",
                 "MonStart1_Hour": "MonStart1Hour", "StepPoints": "StepPoints"}
    # no two old names map to the same new name
    assert len(set(m.values())) == len(m)
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd WT && python -m pytest scripts/tests/test_v3_namemap.py -v`
Expected: FAIL (`No module named 'v3_namemap'`).

- [ ] **Step 3: Write minimal implementation**

```python
# WT/scripts/v3_namemap.py
"""Deterministic 1.2 -> 3.0 input-name rule + map generator (spec 3.0 naming scheme)."""
import re
from pathlib import Path

def to_v3(name):
    s = name[0].upper() + name[1:]
    while "_" in s:                       # drop underscores, capitalize next letter
        i = s.index("_")
        s = s[:i] + (s[i+1].upper() + s[i+2:] if i + 1 < len(s) else "")
    # acronym run (2+ uppercase) -> Title-case: TP->Tp, DD->Dd, ADX->Adx, EMA->Ema
    s = re.sub(r"[A-Z]{2,}", lambda m: m.group(0)[0] + m.group(0)[1:].lower(), s)
    return s

def build_map(inputs_mqh):
    names = re.findall(r"^\s*input\s+\S+\s+(\w+)", Path(inputs_mqh).read_text(errors="ignore"), re.M)
    m = {n: to_v3(n) for n in names}
    dupes = [v for v in m.values() if list(m.values()).count(v) > 1]
    if dupes:
        raise ValueError(f"name collisions: {sorted(set(dupes))}")
    return m
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd WT && python -m pytest scripts/tests/test_v3_namemap.py -v`
Expected: PASS (2 tests).

- [ ] **Step 5: Generate + eyeball the real 131-name map**

Run:
```bash
cd WT && python - <<'PY'
from scripts.v3_namemap import build_map
m = build_map("mt5/1.2/MoneyDancer_1.2/Include/Inputs.mqh")
print(f"{len(m)} inputs, {len(set(m.values()))} unique new names")
for o, n in m.items():
    if o != n: print(f"  {o:32} -> {n}")
PY
```
Expected: ~131 inputs, unique == count (no collision), and the renamed pairs look correct (acronyms
title-cased, no underscores). If any look wrong, the rule is wrong — fix `to_v3` + its test, do not
hand-edit the map (the map must stay a pure function of the rule).

- [ ] **Step 6: Commit**

```bash
git add scripts/v3_namemap.py scripts/tests/test_v3_namemap.py
git commit -m "feat(3.0): deterministic 1.2->3.0 input-name rule + map generator"
```

---

### Task 2: source rename tool + apply to the forked 3.0 tree

**Files:**
- Create: `WT/scripts/v3_rename.py`
- Create: `WT/scripts/tests/test_v3_rename.py`
- Create: `WT/mt5/3.0/MoneyDancer_3.0/` (forked + renamed)

- [ ] **Step 1: Write the failing test (rename function)**

```python
# WT/scripts/tests/test_v3_rename.py
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from v3_rename import apply_map

def test_word_boundary_and_longest_first():
    m = {"MaxOrders": "MaxOrdersX", "MaxOrdersDir": "MaxOrdersDirX", "lotMultiplier": "LotMultiplier"}
    src = "input int MaxOrdersDir=50;\nx = MaxOrdersDir + lotMultiplier;\n// MaxOrders note\n"
    out = apply_map(src, m)
    # longest-first: MaxOrdersDir not corrupted by the shorter MaxOrders
    assert "MaxOrdersDirX=50" in out and "MaxOrdersDirX + LotMultiplier" in out
    # whole-word only: 'MaxOrders' in a comment renamed, but NOT the substring inside MaxOrdersDir
    assert "// MaxOrdersX note" in out
    # no double-application
    assert "MaxOrdersDirXX" not in out
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd WT && python -m pytest scripts/tests/test_v3_rename.py -v`
Expected: FAIL (import error).

- [ ] **Step 3: Write minimal implementation**

```python
# WT/scripts/v3_rename.py
"""Apply a {old:new} name-map to source text: whole-word, longest-old-first (so a short
name never corrupts a longer one), single pass via one alternation regex."""
import re

def apply_map(text, name_map):
    olds = sorted(name_map, key=len, reverse=True)
    pattern = re.compile(r"\b(" + "|".join(re.escape(o) for o in olds) + r")\b")
    return pattern.sub(lambda m: name_map[m.group(1)], text)

def apply_to_tree(root, name_map, suffixes=(".mq5", ".mqh")):
    from pathlib import Path
    for p in Path(root).rglob("*"):
        if p.suffix in suffixes:
            p.write_text(apply_map(p.read_text(errors="ignore"), name_map), encoding="utf-8")
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd WT && python -m pytest scripts/tests/test_v3_rename.py -v`
Expected: PASS.

- [ ] **Step 5: Fork 1.2 → 3.0 + rename the EA identity**

Run (bash, from WT):
```bash
mkdir -p mt5/3.0
cp -r mt5/1.2/MoneyDancer_1.2 mt5/3.0/MoneyDancer_3.0
mv mt5/3.0/MoneyDancer_3.0/MoneyDancer_1.2.mq5 mt5/3.0/MoneyDancer_3.0/MoneyDancer_3.0.mq5
# EA identity strings (version label, init Print) — cosmetic, keep behavior identical
sed -i 's/MoneyDancer 1\.2/MoneyDancer 3.0/g; s/MoneyDancer_1\.2/MoneyDancer_3.0/g' \
    mt5/3.0/MoneyDancer_3.0/MoneyDancer_3.0.mq5
```

- [ ] **Step 6: Apply the input rename across the 3.0 tree**

Run (bash, from WT):
```bash
python - <<'PY'
from scripts.v3_namemap import build_map
from scripts.v3_rename import apply_to_tree
m = build_map("mt5/1.2/MoneyDancer_1.2/Include/Inputs.mqh")
apply_to_tree("mt5/3.0/MoneyDancer_3.0", m)
print(f"applied {len(m)} renames to mt5/3.0/MoneyDancer_3.0")
PY
# strip story-tag comments (S1.0 / S2.C / sprint refs) — comments only
grep -rlE "S[0-9]\.[0-9]" mt5/3.0/MoneyDancer_3.0 2>/dev/null | xargs -r sed -i -E 's/\bS[0-9]+\.[0-9A-Za-z.]*\b ?//g'
# confirm input count unchanged (131) and new names present
grep -cE "^\s*input" mt5/3.0/MoneyDancer_3.0/Include/Inputs.mqh
grep -E "^\s*input.*(LotMultiplier|TpPoints|MonStart1Hour|MaxBasketDdPct)" mt5/3.0/MoneyDancer_3.0/Include/Inputs.mqh
```
Expected: input count `131`; the four sample new names present. (The story-tag sed is comment-cosmetic;
it must not touch code — verify the next compile step is clean.)

- [ ] **Step 7: Deploy + compile the 3.0 EA**

Run (bash):
```bash
TD="C:/Users/nikof/AppData/Roaming/MetaQuotes/Terminal/5FFA568149E88FCD5B44D926DCFEAA79"
mkdir -p "$TD/MQL5/Experts/MoneyDancer_3.0"
cp -r mt5/3.0/MoneyDancer_3.0/. "$TD/MQL5/Experts/MoneyDancer_3.0/"
"C:/Program Files/RoboForex MT5 Terminal/metaeditor64.exe" \
  /compile:"$TD/MQL5/Experts/MoneyDancer_3.0/MoneyDancer_3.0.mq5" /log:"$TD/compile_md3.log"
python -c "print(open(r'$TD/compile_md3.log',encoding='utf-16').read())"
```
Expected: `0 errors, 0 warnings`. If errors (a rename hit a non-input identifier, or the tag-sed broke
code), fix `to_v3`/the map and re-apply from a fresh fork (Step 5) — do not hand-patch the 3.0 tree.

- [ ] **Step 8: Commit**

```bash
git add mt5/3.0/ scripts/v3_rename.py scripts/tests/test_v3_rename.py
git commit -m "feat(3.0): fork 1.2 -> MoneyDancer_3.0 with renamed inputs + de-tagged comments (compiles clean)"
```

---

### Task 3: `NAMING.md` (frozen) + `translate_set.py` 1.2→3.0 porter

**Files:**
- Create: `WT/mt5/3.0/MoneyDancer_3.0/NAMING.md`
- Modify: `WT/scripts/translate_set.py`

- [ ] **Step 1: Generate NAMING.md (rules + full frozen map)**

Run (bash, from WT):
```bash
python - <<'PY'
from scripts.v3_namemap import build_map
m = build_map("mt5/1.2/MoneyDancer_1.2/Include/Inputs.mqh")
lines = ["# MoneyDancer 3.0 — FROZEN input naming\n",
         "Rule: PascalCase first letter; drop underscores (capitalize next); acronym runs (2+ caps)",
         "Title-cased (TP->Tp, DD->Dd, ADX->Adx). Generated by scripts/v3_namemap.to_v3.\n",
         "**FROZEN** — no renames after this. Old/other sets port via scripts/translate_set.py.\n",
         "| 1.2 | 3.0 |", "|---|---|"]
for o, n in m.items():
    lines.append(f"| `{o}` | `{n}` |")
open("mt5/3.0/MoneyDancer_3.0/NAMING.md", "w").write("\n".join(lines) + "\n")
print("wrote NAMING.md with", len(m), "rows")
PY
```

- [ ] **Step 2: Add the 1.2→3.0 porter to translate_set.py**

In `WT/scripts/translate_set.py`, add a function that ports a 1.2-scheme set to 3.0 names using the same
rule (so the porter and the source rename share ONE source of truth — `to_v3`):

```python
# append to scripts/translate_set.py
def to_3_0(src, out):
    """Port a 1.2-scheme .set to 3.0 input names (rule-identical to the EA rename)."""
    import sys, pathlib
    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
    from v3_namemap import to_v3
    from f0_runner import parse_set_file
    raw = parse_set_file(pathlib.Path(src))
    ported = {to_v3(k): v for k, v in raw.items()}
    pathlib.Path(out).write_text("\n".join(f"{k}={v}" for k, v in ported.items()) + "\n", encoding="utf-8")
    return ported
```

- [ ] **Step 3: Commit**

```bash
git add mt5/3.0/MoneyDancer_3.0/NAMING.md scripts/translate_set.py
git commit -m "feat(3.0): frozen NAMING.md + translate_set 1.2->3.0 porter (shared to_v3 rule)"
```

---

### Task 4 (run-task): bit-identical verification

**Files:**
- Create: `reports/md3.0-rename-<UTCstamp>/` (audit evidence, committed)

trading-audit-trail governs. v3.0 is accepted ONLY if the per-deal P&L is identical to 1.2.

- [ ] **Step 1: Run 13a + 35k on BOTH 1.2 and 3.0, same window**

Run (bash, from WT) — use a fast 1-week window; both EAs, same set, same everything:
```bash
W="--symbol XAUUSD.duk_robo --period M30 --model 0 --from-date 2026.04.06 --to-date 2026.04.13 --deposit 10000 --input-override MaxSpreadPts=45"
# port 13a to 3.0 names
python -c "import sys; sys.path.insert(0,'scripts'); from translate_set import to_3_0; to_3_0(r'C:/Users/nikof/Downloads/TEST 13a M30+.set','test13a_3.0.set')"
# 1.2 native (13a)
python scripts/f0_runner.py --set-file "C:/Users/nikof/Downloads/TEST 13a M30+.set" --run-id VERIFY-13a-12 $W --expert "MoneyDancer_1.2\\MoneyDancer_1.2.ex5" --timeout 3000
python scripts/extract_trades_from_report.py --report runs/VERIFY-13a-12/VERIFY-13a-12-report.htm --out runs/VERIFY-13a-12/trades.csv
# 3.0 ported (13a)
python scripts/f0_runner.py --set-file "$PWD/test13a_3.0.set" --run-id VERIFY-13a-30 $W --expert "MoneyDancer_3.0\\MoneyDancer_3.0.ex5" --timeout 3000
python scripts/extract_trades_from_report.py --report runs/VERIFY-13a-30/VERIFY-13a-30-report.htm --out runs/VERIFY-13a-30/trades.csv
```

- [ ] **Step 2: Diff per-deal — must be identical**

Run (bash, from WT):
```bash
python - <<'PY'
import pandas as pd
a = pd.read_csv("runs/VERIFY-13a-12/trades.csv"); b = pd.read_csv("runs/VERIFY-13a-30/trades.csv")
cols = ["time","direction","volume","price","profit","balance"]
same = len(a) == len(b) and a[cols].round(2).equals(b[cols].round(2))
print(f"13a: 1.2 deals={len(a)} 3.0 deals={len(b)} | net 1.2={a[a.direction=='out'].profit.sum():.2f} "
      f"3.0={b[b.direction=='out'].profit.sum():.2f}")
print("BIT-IDENTICAL:", "PASS" if same else "FAIL")
assert same, "v3.0 diverges from 1.2 — a rename changed behavior. STOP, fix the map/rename."
PY
```
Expected: `BIT-IDENTICAL: PASS`. If FAIL, a rename touched a non-input identifier or changed a default →
fix and re-fork (Task 2 Step 5), re-verify. (Repeat the same with the 35k set on its M15 window for a
second witness.)

- [ ] **Step 3: Write the audit folder + commit**

Use `tools/audit.py` (copy into WT/scripts if absent) to create `reports/md3.0-rename-<UTC>/` with:
both `trades.csv` pairs, the diff result (PASS), `NAMING.md` (the map), and `manifest.md` (sha256 + the
verdict "v3.0 == 1.2, per-deal identical, N deals"). Commit:
```bash
git add reports/md3.0-rename-* test13a_3.0.set
git commit -m "evidence(3.0): bit-identical verification — v3.0 renamed EA == 1.2 per-deal"
```

---

## Self-Review

**1. Spec coverage:**
- §2 fork + rename all 131 + strip tags + keep behavior → Task 2. ✓
- §3 frozen scheme (rule + map) → Task 1 (`to_v3`/`build_map`) + Task 3 (`NAMING.md`). ✓
- §4 one map drives source rename (a) + porter (b) → Task 2 Step 6 + Task 3 Step 2 (both use `to_v3`). ✓
- §5 bit-identical discriminator (13a+35k, 1.2 vs 3.0, per-deal) → Task 4. ✓
- §6 deliverables (3.0 EA compiles, NAMING.md, porter, audit folder + manifest) → Tasks 2/3/4. ✓
- §7 out of scope (features) → none added; plan only renames. ✓

**2. Placeholder scan:** Task 4's audit-folder authoring uses `tools/audit.py` (existing helper) — the
`<UTCstamp>` is a runtime substitution, not a TODO. All code steps carry full code. No "TBD".

**3. Type consistency:** `to_v3(name)`/`build_map(path)` (Task 1) are reused by `apply_to_tree` driver
(Task 2 Step 6), `NAMING.md` gen (Task 3 Step 1), and `to_3_0` porter (Task 3 Step 2) — one rule, one
map, everywhere. `apply_map(text, name_map)`/`apply_to_tree(root, name_map)` (Task 2) signatures match
their callers. The verify diff (Task 4) consumes `trades.csv` columns produced by
`extract_trades_from_report.py` (existing). ✓
