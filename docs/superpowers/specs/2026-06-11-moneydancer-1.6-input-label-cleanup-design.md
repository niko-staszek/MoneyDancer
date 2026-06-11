# MoneyDancer 1.6 — Input Label Cleanup — Design

**Branch:** `claude/reverent-panini-6271e7`. **Date:** 2026-06-11. **Base:** MoneyDancer 1.5.
**Governing skill:** trading-audit-trail (verification = bit-identical to 1.5).

## 1. Why

The MT5 inputs dialog shows each input's trailing `// comment` as its row label. Those labels are cluttered
with developer story-tags (`S1.0`, `S1.6`, `S3.2`, `A5.x`), "-> Test it!" notes, and MT4-porting asides
("(MT4 original)", "(1.1 parity)"). They make the panel hard to read for an operator. v1.6 rewrites the
labels to plain, clear English. **Comments only — no variable, value, enum, or logic change**, so the EA is
bit-identical to 1.5.

## 2. Versioning

Verbatim fork `mt5/1.5/MoneyDancer_1.5/` → `mt5/1.6/MoneyDancer_1.6/` (EA renamed `MoneyDancer_1.6.mq5`,
version strings bumped to `1.6`). The only content change is comment text in `Include/Inputs.mqh`.

## 3. Scope

- **Only `Include/Inputs.mqh`.** Only the text of trailing `// comments` and the leading `//` section/comment
  lines. Nothing else in the file or repo changes.
- **Do NOT change:** any `input` variable name, any default value, any enum or its members, the `input string
  __sec_*__` divider VARIABLE names, or any code in other files.
- **Section-divider VALUES** (e.g. `input string __sec_orders_sl_tp__ = "==== Orders & SL & TP ====";`): the
  visible `"==== ... ===="` text MAY be cleaned (it is a cosmetic label never read in logic), but this is the
  ONE place a default *value* changes. It is provably unused in logic (grep confirms no `__sec_*__` read), so
  it stays behavior-neutral. If in doubt, leave divider values untouched — labels are the priority.

## 4. Cleanup rules (apply to every input's comment)

1. Strip dev tags: `S1.0` / `S1.6` / `S3.2` / `S2.x` / `S5.x` / `A5.x` / `Phase A2` and similar.
2. Strip "-> Test it!", "TODO/FIXME/XXX", and MT4-porting asides ("(MT4 original)", "(was … in MT4)",
   "(default OFF for 1.1 parity)").
3. Rewrite each label as a short, plain-English description of what the input does.
4. KEEP: the unit (points/%/lots/USD/hour), and operator hints like `(0=OFF)` or recommended values
   (reworded, e.g. "recommend 40" → "try 40").
5. Keep labels concise (they render in a narrow dialog column).

Representative before/after:
```
MaxBasketDD_Pct  = 55.0; // Max DD per basket -> hedge. Test it!      ==>  // Max drawdown per basket before hedge (%)
MaxBasketLossPct = 0.0;  // S1.0 % of equity at series open (0=OFF)   ==>  // Per-basket equity stop-loss, % at series open (0=OFF)
MaxAllTimeDDPct  = 0.0;  // S1.6 ceiling % (0=OFF; recommend 40)       ==>  // All-time drawdown kill, % (0=OFF; try 40)
SL_Points        = 0;    // Stop Loss for Basic Order (MT4 original)   ==>  // Stop loss for the first order, points (0=OFF)
FoldManualOrders = false;// include hand-placed (magic==0) ...basket   ==>  // Manage hand-placed (magic 0) orders as part of the basket
```

## 5. Verification (trading-audit-trail)

1. **Bit-identical to 1.5:** comments do not affect the compiled `.ex5`. Run an author set on v1.6 vs 1.5
   (same symbol/window/deposit, no overrides) → **same sha256** on both `trades.csv`. Proves no code/value
   changed by accident.
2. **No code-line diff:** `diff` of `Inputs.mqh` 1.5→1.6 must show changes ONLY on comment text / `//` lines
   (and at most the `__sec_*__` divider value strings) — never an `input` declaration's type/name/value.
3. **Compile** 0 errors.

## 6. Deliverables (audit folder `reports/md1.6-labelcleanup-<UTCstamp>/`)

The modified `Inputs.mqh`, the bit-identical pair (`trades.csv` ×2 + sha match), the `Inputs.mqh` 1.5→1.6
diff (showing comment-only changes), and `manifest.md` (sha256 + verdict).

## 7. Out of scope

Renaming any input variable (breaks presets — a separate, larger pass if ever wanted); regrouping/reordering
inputs; new inputs; comment cleanup in other files (cosmetic, lower value). v1.6 is purely the operator-facing
label cleanup in `Inputs.mqh`.

## 8. Reused assets

1.5 source, `scripts/f0_runner.py` (Model=0) + `extract_trades_from_report.py`, RoboForex terminal `5FFA5681`
+ `metaeditor64.exe`, duka `XAUUSD.duk_robo`, author set `TEST 13a M30+.set`.
