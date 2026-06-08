# MoneyDancer 3.1 — Equity-Scaled Auto-Lot — Design

**Branch:** `claude/reverent-panini-6271e7`. **Date:** 2026-06-08. **Base:** MoneyDancer 3.0 (clean 1.2 rename).
**Governing skill:** trading-audit-trail (verification = bit-identical-when-off + proportional-scaling discriminator).

## 1. Why

3.0 (= 1.2) sizes every basket from a **fixed** `LotsBase=0.01` — risk-per-dollar changes with account
size, and the EA can't compound or derisk with equity. v3.1 adds opt-in **equity-scaled** base lot (the
feature 2.0 already proved), as the first verified increment on the clean 3.0 base. Off by default →
existing sets unchanged.

## 2. What it adds

One new input **`LotsBasePerThousand`** (default **0.0 = OFF**). When > 0, the base lot becomes
`equity/1000 × LotsBasePerThousand` (clamped to broker min/step/max); when 0, the fixed `LotsBase` is
used (exactly today's behavior). So `LotsBasePerThousand=0.002` → 0.01 lot @ 5k, 0.20 @ 100k, and the
base auto-shrinks during drawdown (equity falls) and grows on profit (compound). The name already
conforms to the frozen scheme (no rename).

## 3. Implementation (4 files, surgical)

- **`Include/Inputs.mqh`** — add beside `LotsBase` (line 96):
  `input double LotsBasePerThousand = 0.0;  // >0: base lot = equity/1000 * this (0 = fixed LotsBase)`
- **`Include/Utils.mqh`** — add (near `ClampLot`, line 23):
  ```cpp
  double ComputeBaseLot()
  {
     if(LotsBasePerThousand <= 0.0) return LotsBase;
     double eq = AccountInfoDouble(ACCOUNT_EQUITY);
     return ClampLot((eq / 1000.0) * LotsBasePerThousand);
  }
  ```
  (`Utils.mqh` is included before `Signal.mqh`/`ScenarioE.mqh`, so the function is visible at all call
  sites; if not, move the include or forward-declare — the compile step catches it.)
- **Replace the 5 trade-path base-lot uses** `LotsBase` → `ComputeBaseLot()`:
  `Signal.mqh:256` (first basket order), `Signal.mqh:202` and `:203` (pyramid / fallback lot),
  `Signal.mqh:303` (base-lot "DB" add), `ScenarioE.mqh:220` (runner lot).
- **No change to the martingale escalation** (`Signal.mqh:296`, `firstLot * LotMultiplier^N`): `firstLot`
  = `FirstBasketLotSeries` reads the first order's *actual* volume, so it auto-scales once that first
  order uses `ComputeBaseLot()`. The whole strategy scales by **equity at series-open**.
- Do NOT touch `Inputs.mqh`'s `LotsBase` (kept as the OFF fallback) or `ClampLot`.

## 4. Verification (trading-audit-trail; v3.1 accepted only if all pass)

1. **OFF = bit-identical** (backward-compat): run the 13a author set (no `LotsBasePerThousand` → defaults
   0) on v3.1 vs the v3.0 baseline (`reports/md3.0-rename-20260608/trades_3.0.csv`), same
   symbol/window/deposit. Per-deal **identical** (ideally same sha256). Proves OFF changes nothing.
2. **Scaling proportional** (feature works): run a set with `--input-override LotsBasePerThousand=0.002`
   at deposit **5000** and **50000**, same window. Expect: **same deal count**, base/maxlot ~**10×**,
   net ~**10×** (so % return ≈ equal). Confirms equity-scaling is applied and proportional.
3. **Compile** 0 errors.

## 5. Deliverables (audit folder `reports/md3.1-autolot-<UTCstamp>/`)

The 4 modified files (compiles clean), the two verification runs' `trades.csv` (off-identical pair +
the 5k/50k scaling pair), the diff/ratio results, the `.set` configs used, and `manifest.md` (sha256 +
verdict). No metric reported unless it traces to a trades.csv there.

## 6. Out of scope

v3.2 ATR-adaptive distance params; v3.3 manual-orders-into-basket; strip-unused pass. v3.1 adds only the
one opt-in input + `ComputeBaseLot`; it changes no behavior when off.

## 7. Reused assets

3.0 source (`mt5/3.0/MoneyDancer_3.0/`), `ClampLot` (Utils.mqh), `scripts/f0_runner.py` (+`--input-override`)
+ `extract_trades_from_report.py`, the v3.0 bit-identical baseline, RoboForex terminal `5FFA5681` +
`metaeditor64.exe`, duka `XAUUSD.duk_robo`.
