# MoneyDancer 3.0 — Clean Rename of 1.2 (behavior-identical) — Design

**Branch:** `claude/reverent-panini-6271e7` (= ns/v2.0 line). **Date:** 2026-06-04.
**Governing skill:** trading-audit-trail (the verification is a bit-identical backtest discriminator).

## 1. Why

The session proved 2.0 is overkill: **1.2 beat 2.0** on the author's #GOLD sets, and the 1.2 source is
lean (131 inputs, one clean engine) where 2.0 piled 52 more inputs (MMD, extra regime, adaptive,
telemetry) that the winning sets never use. Decision: **rebuild forward from 1.2**, not 2.0. v3.0 is the
first step — a pure, behavior-identical cleanup that gives a maintainable base. Features come as
verified increments (v3.1 auto-lot, v3.2 ATR-adaptive, v3.3 manual-orders, later a strip-unused pass).

**This version adds NO behavior.** It renames inputs to one frozen scheme and removes story-tag
comments. The success criterion is a **bit-identical backtest** vs 1.2.

## 2. What v3.0 is

Fork `mt5/1.2/MoneyDancer_1.2/` → `mt5/3.0/MoneyDancer_3.0/` (main `.mq5` + all 16 `Include/*.mqh`).
- **Rename all 131 inputs** to the §3 scheme, updating the declaration in `Inputs.mqh` AND every
  reference across the other Include files + the main `.mq5`.
- **Remove cruft:** `S1.0`/`S2.C`/sprint-story tags in comments, commented-out dead code, stale notes.
  (Comments + dead code only — no functional line changes.)
- **Keep ALL functional logic byte-for-byte** (same control flow, same constants, same defaults).
- No inputs added or removed; no features stripped (later minors).

## 3. Frozen naming scheme (`NAMING.md`)

**PascalCase. Acronyms title-cased. Semantic suffixes kept.** Rules:
- Acronym → Title-case the token: `TP`→`Tp`, `SL`→`Sl`, `BE`→`Be`, `MA`→`Ma`, `DD`→`Dd`, `EMA`→`Ema`,
  `ADX`→`Adx`, `AI`→`Ai`.
- Drop all underscores: `MonStart1_Hour`→`MonStart1Hour`, `MaxBasketDD_Pct`→`MaxBasketDdPct`.
- First letter uppercase (PascalCase) for every input: `lotMultiplier`→`LotMultiplier`,
  `maPeriod`→`MaPeriod`, `bePoints`→`BePoints`, `startBe`→`StartBe`, `slopeThresholdPts`→`SlopeThresholdPts`.
- Already-conforming names unchanged: `StepPoints`, `MaxOrdersDir`, `LotsBase`, `PriceStep`, `BurstTicks`,
  `MinMovePoints`, `CooldownSec`, `MaxSpreadPts`, `ScenarioD`, `ScenarioE`, `PyramRange`, `Magic`, etc.
- Section-marker pseudo-inputs (`__sec_working_hours__`) → keep as section separators but rename to a
  clean form (e.g. `_SectionWorkingHours`) or drop if they are pure display; they carry no behavior.

Representative map (full map generated mechanically from `Inputs.mqh`):
| 1.2 | 3.0 |
|---|---|
| `lotMultiplier` | `LotMultiplier` |
| `TP_Points` / `SL_Points` | `TpPoints` / `SlPoints` |
| `bePoints` / `startBe` | `BePoints` / `StartBe` |
| `maPeriod` / `slopeLookbackBars` / `slopeThresholdPts` / `strongTrendPts` | `MaPeriod` / `SlopeLookbackBars` / `SlopeThresholdPts` / `StrongTrendPts` |
| `MonStart1_Hour` … `FriEnd2_Minute` | `MonStart1Hour` … `FriEnd2Minute` |
| `MaxBasketDD_Pct` / `MaxEquityDD_Pct` / `MaxAllTimeDDPct` | `MaxBasketDdPct` / `MaxEquityDdPct` / `MaxAllTimeDdPct` |
| `RunnerBE_StartPts` | `RunnerBeStartPts` |

`NAMING.md` documents the rules + the complete map and is **FROZEN** — no further renames; all future
sets/ports go through the translator. (Naming drift caused two silent-default landmines this session.)

## 4. How (mechanical, single source of truth)

One name-map `{old: new}` is the single source of truth, derived from `Inputs.mqh` input declarations by
applying the §3 rules. It drives:
- **(a) Source rename:** a word-boundary-safe, longest-name-first replace across the forked
  `mt5/3.0/MoneyDancer_3.0/**` (so `MaxOrdersDir` is not partially hit by a shorter name). Applied to
  declarations + all references. Then compile via RoboForex MetaEditor → **0 errors**.
- **(b) Set porter:** `translate_set.py` gains the `1.2 → 3.0` map so any author/old set ports to 3.0
  names (it already handles underscore→camelCase families; this is the canonical extension).

## 5. Verification — bit-identical discriminator (the whole point)

trading-audit-trail governs. Take two author sets (**13a** + **35k**):
1. Run each on **1.2** → baseline trades (the native-1.2 batch produces these: `runs/N12-13a-m30`,
   `runs/N12-35k-m15`).
2. Port each set to 3.0 names (porter) → run on **3.0**, same symbol/window/deposit/period.
3. Compare per-deal P&L (`trades.csv`) **byte-for-byte**: same deal count, same prices, same profit,
   same balance curve. **MUST be identical.** Any difference = a rename missed a reference (or changed a
   default) → fix before v3.0 is accepted.

Plus: compile 0 errors; `[PL.3]`/init clean on a chart.

## 6. Deliverables (audit folder `reports/md3.0-rename-<UTCstamp>/`)

`mt5/3.0/MoneyDancer_3.0/` (compiles clean), `NAMING.md` (frozen scheme + full map), `translate_set.py`
(1.2→3.0 porter), and the bit-identical verification report (1.2-vs-3.0 per-deal diff = zero) with
`manifest.md` + sha256. No metric reported unless it traces to a trades.csv there.

## 7. Out of scope (later minors)

v3.1 equity-scaled auto-lot; v3.2 ATR-adaptive distance params (build + A/B verify, don't assume);
v3.3 manual-orders-into-basket; a later strip-unused-features pass (Regime/ScenarioE if confirmed
unwanted). Each its own brainstorm → spec → plan → verify cycle. v3.0 touches behavior **not at all**.

## 8. Reused assets

1.2 source (`mt5/1.2/MoneyDancer_1.2/`), `scripts/translate_set.py`, `scripts/f0_runner.py` +
`extract_trades_from_report.py`, the native-1.2 batch baselines, RoboForex terminal `5FFA5681` +
`metaeditor64.exe`, duka `XAUUSD.duk_robo`.
