# MoneyDancer 1.6 — Operator Build (label cleanup + gentle auto-lot default + deployable preset) — Design

**Branch:** `claude/reverent-panini-6271e7`. **Date:** 2026-06-11. **Base:** MoneyDancer 1.5.
**Governing skill:** trading-audit-trail (verification = bit-identical-when-features-off + preset validated by backtest).

## 1. Why

Make a drop-on-chart, operator-ready build: a clean inputs panel, a gentler default lot-scaling, and one
bundled "recommended" preset (1.3a scalp + 2% daily target + manage-manual-orders) — the surviving config
from the worst-month benchmark. Three parts, all low-risk; the EA stays bit-identical to 1.5 when the
opt-in features are off.

## 2. Versioning

Verbatim fork `mt5/1.5/MoneyDancer_1.5/` → `mt5/1.6/MoneyDancer_1.6/` (EA renamed `MoneyDancer_1.6.mq5`,
version strings → `1.6`). Content changes: comment text + one default value in `Include/Inputs.mqh`, plus a
new preset file. No logic, no other code.

## 3. Part A — input label cleanup (`Include/Inputs.mqh`, comments only)

Rewrite each input's trailing `// comment` (the MT5 dialog row label) to plain English. Rules:
1. Strip dev tags: `S1.0`/`S1.6`/`S3.2`/`S2.x`/`S5.x`/`A5.x`/`Phase A2`.
2. Strip "-> Test it!", TODO/FIXME, and MT4-porting asides ("(MT4 original)", "(was … in MT4)",
   "(default OFF for 1.1 parity)").
3. Strip redundant `(default …)` notes — `(default OFF)`, `(default 00)` — the MT5 value column shows the
   default already. **But KEEP semantic hints** `(0=OFF)` / `(-1=OFF)` (they explain what a value MEANS).
4. Keep the unit (points/%/lots/USD/hour) and recommended values (reworded, "recommend 40" → "try 40").
5. Concise (narrow dialog column).
Representative: `MaxBasketLossPct = 0.0; // S1.0 % of equity at series open (0=OFF)` →
`// Per-basket equity stop-loss, % at series open (0=OFF)`.
**Variable names, values, enums, and all code UNCHANGED.** (Section-divider VALUE strings `__sec_*__` may be
tidied — provably unused in logic — but labels are the priority; leave them if unsure.)

## 4. Part B — gentle auto-lot default (`Include/Inputs.mqh`, one value)

`input double AutoLotDivisor = 1000;` → `= 2000;`. With Add mode @100k equity this halves the base lot
(`0.01 + 0.01×(equity/2000)` → ~0.51 instead of ~1.01). Only read when `AutoLotScaling` is ON (default
OFF), so it does not change behavior in the bit-identical test.

## 5. Part C — bundled deployable preset `presets/XAUUSD_1.3a_2pct.set`

Built from the author `TEST 1.3a.set` (license/optimizer-slot lines stripped, native 1.x key names) plus
these settings:
- Lot scaling: `AutoLotScaling=1`, `AutoLotType=0` (Equity), `AutoLotMode=0` (Add), `AutoLotDivisor=2000`,
  `AutoLotIncrement=0.01`  → base ~0.5 lot @100k, scales with equity.
- Daily target: `DailyProfitTargetMode=1` (Percentage), `DailyProfitTargetPct=2` → equity hits +2% →
  close all + stop for the day (equity-gated, never closes below target).
- Manual orders: `FoldManualOrders=true` → hand-placed (magic 0) orders managed as part of the basket.
- Safety: `MaxAllTimeDDPct=40` → all-time drawdown kill at 40% (the benchmark showed unbounded blowups).
- Keep all other 1.3a scalp params as authored (PriceStep 0.20, tight SL, etc.); keep its native
  `MaxSpreadPts` (operator tunes to their live broker spread).
This is the "recommended config" — load it on a gold chart. The EA's own code defaults stay generic (only
Part B's divisor changes).

## 6. Verification (trading-audit-trail)

1. **Bit-identical to 1.5 (features-off):** run an author set (13a) on 1.6 vs 1.5, no overrides
   (`AutoLotScaling=false`, `FoldManualOrders=false`, `DailyProfitTargetMode=OFF`) → **same sha256**. Proves
   Parts A+B changed no behavior when the opt-in features are off (label/divisor edits are inert).
2. **Inputs.mqh diff is comment-only** (+ the one `AutoLotDivisor` value): the 1.5→1.6 `Inputs.mqh` diff must
   touch only `//` comment text and the single `AutoLotDivisor = 2000` line — no input name/type changes.
3. **Preset loads + behaves:** a short run with `--set-file XAUUSD_1.3a_2pct.set` parses cleanly, auto-lot
   produces ~0.5 base @100k, and (in a window that reaches +2%) the daily target closes+pauses. (Full
   validation = the separate 10-month 2%-target run, queue item.)
4. **Compile** 0 errors.

## 7. Deliverables (audit folder `reports/md1.6-operatorbuild-<UTCstamp>/`)

Modified `Inputs.mqh`, the new preset, the bit-identical pair (`trades.csv` ×2 + sha match), the comment-only
`Inputs.mqh` diff, a preset-smoke trades.csv, `manifest.md` (sha256 + verdict).

## 8. Out of scope

Renaming input VARIABLES (breaks presets); baking 1.3a into EA code defaults (delivered as the preset
instead); the 10-month 2%-target validation backtest (separate queue item, run after the owner's demo check).

## 9. Reused assets

1.5 source, author `TEST 1.3a.set`, `scripts/f0_runner.py` (Model=0) + `extract_trades_from_report.py`,
RoboForex terminal `5FFA5681` + `metaeditor64.exe`, duka `XAUUSD.duk_robo`.
