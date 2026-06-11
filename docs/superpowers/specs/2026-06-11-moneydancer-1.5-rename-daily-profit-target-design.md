# MoneyDancer 1.5 — Rename Daily Profit-Target Inputs — Design

**Branch:** `claude/reverent-panini-6271e7`. **Date:** 2026-06-11. **Base:** MoneyDancer 1.4 (`mt5/1.4/MoneyDancer_1.4/`).
**Governing skill:** trading-audit-trail (verification = bit-identical to 1.4).

## 1. Why

The equity-gated daily close-all-and-stop control is exposed as `ProfitTargetMode` / `ProfitTargetPct` /
`ProfitTargetUsd` (enum `ENUM_PROFIT_TARGET_MODE`). The names don't say it's a **daily** target, so it reads
like a per-trade or lifetime target. v1.5 renames them to make the daily scope explicit. **Rename only — zero
behavior change.** (This is the control the owner wanted: when equity (realized+floating) − day-base ≥ target,
the EA closes the whole basket and pauses until next day. Because it is equity-gated, it never closes below
target. Logic in `Risk.mqh::ApplyDailyRiskControls()` is unchanged.)

## 2. Versioning

Verbatim fork of `mt5/1.4/MoneyDancer_1.4/` → `mt5/1.5/MoneyDancer_1.5/` (files copied, EA renamed
`MoneyDancer_1.5.mq5`, version strings bumped to `1.5`). The ONLY content change is the rename below.
1.4 is tagged on main; forking keeps that tag intact.

## 3. Rename map (whole-word, 2 files only: Inputs.mqh + Risk.mqh)

| old | new |
|---|---|
| `ENUM_PROFIT_TARGET_MODE` | `ENUM_DAILY_TARGET_MODE` |
| `PROFIT_TARGET_OFF` | `DAILY_TARGET_OFF` |
| `PROFIT_TARGET_PCT` | `DAILY_TARGET_PCT` |
| `PROFIT_TARGET_USD` | `DAILY_TARGET_USD` |
| `ProfitTargetMode` | `DailyProfitTargetMode` |
| `ProfitTargetPct` | `DailyProfitTargetPct` |
| `ProfitTargetUsd` | `DailyProfitTargetUsd` |

Defaults unchanged: `DailyProfitTargetMode = DAILY_TARGET_OFF` (first enumerator = 0, same as the old
`PROFIT_TARGET_OFF = 0`), `DailyProfitTargetPct = 5.0`, `DailyProfitTargetUsd = 100.0`. No author preset
references any of these tokens (verified), so no preset breaks.

## 4. Scope guard

- Only the 7 tokens above change, only in `Include/Inputs.mqh` and `Include/Risk.mqh`.
- Do NOT touch `MaxDailyProfitPct`, `AfterThisHour*`, `RiskFromCurrentProfit*` (separate controls), or the
  comment text describing the inputs (the comments may keep wording, but updating them to match the new name
  is allowed since it is non-functional).
- No logic, no defaults, no enum ordering changes.

## 5. Backward-compat / verification (trading-audit-trail)

1. **Bit-identical to 1.4:** the rename cannot change any trade — enum values and input defaults are
   identical, only identifiers differ. Run an author set on v1.5 vs 1.4 (same symbol/window/deposit, no
   overrides) → **same sha256** on both `trades.csv`. (`DailyProfitTargetMode` defaults OFF, so the renamed
   control is inert in the test — exactly as in 1.4.)
2. **Compile** 0 errors.

## 6. Deliverables (audit folder `reports/md1.5-rename-<UTCstamp>/`)

The 2 modified files (compile clean), the bit-identical pair (`trades.csv` ×2 + sha match), `manifest.md`
(sha256 + verdict). No metric unless it traces to evidence there.

## 7. Out of scope

Any behavior change to the daily target; renaming the OTHER daily controls (`MaxDailyProfitPct` etc.);
new inputs; defaulting the control ON. Pure identifier rename of the one equity-gated daily-target control.

## 8. Reused assets

1.4 source (`mt5/1.4/MoneyDancer_1.4/`), `scripts/f0_runner.py` (Model=0) + `extract_trades_from_report.py`,
RoboForex terminal `5FFA5681` + `metaeditor64.exe`, duka `XAUUSD.duk_robo`, author set
`mt5/1.5/MoneyDancer_1.5/presets/author-reference/TEST 13a M30+.set`.
