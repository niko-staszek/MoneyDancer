# MoneyDancer — Session Handoff (2026-06-11)

Start-here for the next conversation. Everything below is shipped + committed unless marked OPEN.

## 1. Where we are

- **Base reset:** the v2.0 line and the (separate, earlier) v3.0/3.1/3.2 rebuild were **deleted** (commit `08b9125`).
  The live lineage is **mt5/1.2 → 1.3 → 1.4 → 1.5 → 1.6**, each a verbatim fork of the prior + one feature,
  each verified **bit-identical when its feature is off**, each merged to `main` (fast-forward) and git-tagged.
- **`main` = `451df98`**, pushed to `origin/main` (https://github.com/niko-staszek/MoneyDancer).
  Tags: `1.0 1.1 1.3 1.4 1.5 1.6` (bare, no `v` prefix; no `1.2` tag though the 1.2 EA exists).
  `main:mt5/` = `1.0 1.1 1.2 1.3 1.4 1.5 1.6`. (2.0/3.0 never existed on main.)
- **Worktree/branch:** all work is on branch `claude/reverent-panini-6271e7` in worktree
  `C:\Users\nikof\Documents\GitHub\MoneyDancer\.claude\worktrees\reverent-panini-6271e7`. The main checkout
  (`C:\Users\nikof\Documents\GitHub\MoneyDancer`) sits on `ns/RangeDayEveryDay` — that is why files committed
  here don't appear in the main checkout until merged.

## 2. Version lineage (all on main + tagged)

| Ver | Adds | Default | Verification |
|---|---|---|---|
| 1.2 | base (131 inputs, underscore naming) | — | — |
| 1.3 | **FoldManualOrders** — manage hand-placed (magic 0) orders as part of the basket (BE/TP/exposure/close; single-attach to lowest active series; add-side untouched) | OFF | OFF bit-identical to 1.2 (sha `649b28256781da82`) |
| 1.4 | **AutoLotScaling** — base lot scales with equity/balance. Enums `AutoLotType`(Equity/Balance), `AutoLotMode`(Add/Multiply); `AutoLotDivisor`, `AutoLotIncrement`. ADD: `lot=LotsBase+inc*(metric/div)`, MUL: `lot=LotsBase*(metric/div)`, ClampLot'd | OFF | OFF bit-identical; ON formula exact (0.06/0.51/0.50/0.51) |
| 1.5 | **rename** ProfitTarget* -> DailyProfitTarget* (+ enum DAILY_TARGET_*). The equity-gated daily close-all+stop control | — | bit-identical to 1.4 |
| 1.6 | **operator build**: (A) input-label cleanup (Inputs.mqh comments — all S1.x/"Test it!"/MT4-parity junk stripped, `(0=OFF)` hints kept), (B) `AutoLotDivisor` default 1000->2000 (~0.5 base @100k), (C) bundled preset `XAUUSD_1.3a_2pct.set` | features OFF | OFF bit-identical to 1.5; preset smoke 0.51 lot @100k |

### Daily profit target (in 1.5/1.6, the control the owner wanted)
`Risk.mqh::ApplyDailyRiskControls()`. **`DailyProfitTargetMode`** = Off/Percentage(1)/FixedUSD(2) +
`DailyProfitTargetPct`/`DailyProfitTargetUsd`. EQUITY-gated (realized+floating): when `equity-day_base >= target`
-> CloseAllPositions + pause until next day. Because equity-gated, it NEVER closes below target. (The
balance-gated `MaxDailyProfitPct` does NOT have that guarantee — avoid it for "lock the day".)

### Deployable preset `mt5/1.6/MoneyDancer_1.6/presets/XAUUSD_1.3a_2pct.set`
1.3a scalp (PriceStep 0.20, SL 7500 hard, lotMult 1.5, StepPoints 55, TP 98) + AutoLotScaling=1 Add/Equity
div2000 (~0.5 base @100k) + DailyProfitTargetMode=1 Pct=2 + FoldManualOrders=true + MaxAllTimeDDPct=40.
NOTE preset MaxSpreadPts=15 (1.3a native) — operator tunes to live broker; backtests override 45 on duka_robo.

## 3. Key research findings

### Worst-month benchmark (5 author sets x 10 worst fortnights @100k, auto-lot ON 1.0-base)
`reports/bench-worst-months-20260610-125342Z/`. Robustness **13a > 1.3a > 3k > 35k > 5k**.
Only hard-SL tight-scalp (13a/1.3a) survive worst months; **5k blew all 10**; 35k mostly blew.
Confirms prior "hard SL = survivable; 5k = slug-lottery".

### 1.3a + 2% daily target (the deployable config) x 10 worst fortnights @100k, 0.5-base
`reports/bench-1.3a-2pct-20260611-160022Z/` + AUDIT `reports/audit-1.3a-2pct-20260611-171859Z/`.
**Survived 10/10 (0 blowups)** vs old 1.3a 7/10. mean -2% / median +10% / best +17% / worst -39%.
Profile = **+2% banked almost every day, capped; rare single days lose -17..-43% (DD-40 kill).** The 2% daily-stop
caps+smooths winners; **MaxAllTimeDDPct=40 is the survival lever** (turns blowups into ~-36%). Range% does NOT
predict outcome — path/directionality does (path-dependence, Nth confirmation).
**AUDIT: LEGIT** — 100%-quality every-tick data (8/10; 91%/83% on 2), extract reconciles (net 7/10 exact, DD 10/10),
kill-day forensic = real martingale escalation (x1.5 lots) + DD-40 force-close. **Caveat: backtest has 0 commission**
(duka_robo) ~= -1%pt/fortnight live; force-close slippage could be worse live; these are the WORST months (not typical).

## 4. OPEN ITEMS (resume here)

1. **[USER, the only blocker] Demo-validate manual-orders-into-basket.** On a 1.6 chart, RoboForex terminal
   `5FFA5681`. Load `XAUUSD_1.3a_2pct.set` (FoldManualOrders=true) OR set the toggle "Manage hand-placed
   (magic 0) orders as part of the basket" = true. Open an EA basket, then hand-open a magic-0 order in that
   direction; confirm it shows in the dashboard float + gets a TP at the basket BE + closes with the basket.
   EARLIER: user's positions file was empty = EA tracking nothing = FoldManualOrders was OFF (NOT a bug; code
   includes manual in dashboard float via `BasketFloatingPL`->`IsMinePosition` when fold ON).
   **Claude can read live state:** `C:\Users\nikof\AppData\Roaming\MetaQuotes\Terminal\5FFA568149E88FCD5B44D926DCFEAA79\MQL5\Files\MoneyDancer_positions_21010_XAUUSD.csv`
   (ticket,tp,sl; magic 21010) + `..._telemetry_..._<date>.csv` + `..._railstate_...csv`. Fold ON -> the manual
   ticket appears with the basket TP; fold OFF -> absent.
2. **Forward test (standing gate):** the only real edge-truth. 1.3a or the 1.6 preset on demo, 30+ days. Not started.
3. **Possible next:** other instruments (the original RangeDayEveryDay portfolio goal — see memory); further DD-ceiling
   hardening (40->10 over time, per feedback_dd_ceiling_40_then_harden); revisit auto-lot mode (Multiply variant).

## 5. Gotchas / how to run backtests (CRITICAL)

- **Terminal:** RoboForex `5FFA568149E88FCD5B44D926DCFEAA79`. Compile via
  `C:/Program Files/RoboForex MT5 Terminal/metaeditor64.exe /compile:... /log:...` (rc=1 on success = normal;
  trust the log text "0 errors"). Reports are POLISH-language.
- **Model=0 mandatory** (every real tick); Model=1 starves the tick/burst engine (151 vs 5096 deals).
- **`scripts/f0_runner.py`** (parse .set -> UTF-16 ini -> terminal64 /config, ShutdownTerminal=1) +
  `extract_trades_from_report.py`. Symbols: `XAUUSD.duk_robo` (2026 Jan-May) + `XAUUSD.duk_robo_2025` (2025 full yr).
  **No 2024 tick data** (can be duka-fetched via scripts/duka_*; data/duka/*.csv has raw ticks).
- **MaxSpreadPts=45** override needed on duka_robo (raw spread 25-28 blocks entries at the sets' native 15).
- **f0_runner batch collision (SOLVED):** only ~2 sequential headless tests run per python process before the
  metatester agent jams on heavy-report flush. FIX in `scripts/bench_worst_months.py` `reset_mt5()`: WAIT for
  metatester64 to vanish naturally (up to 300s) before each run, kill only if stuck (killing a busy metatester
  jams the pool); idempotency keyed on report.htm-exists; extract retry. Backstop = self-relaunch wrapper
  `scripts/bench_*_loop.sh`. Reuse these for any multi-run batch. DO NOT open the RoboForex GUI while backtests run.
- **Windows /tmp gotcha:** Python's `/tmp` = `C:\tmp`, bash's `/tmp` is different — don't `cp` between them.
- **Console encoding (cp1250):** strip non-ASCII before `print()` of Polish report text or it throws.

## 6. Memory / docs

- Auto-memory: `project_rangedayeveryday_portfolio.md` (has the full chronological ledger + the ACTIVE QUEUE).
  This handoff condenses it; the memory file is the long form.
- Reuse scripts: `scripts/bench_worst_months.py`, `scripts/bench_1p3a_2pct.py` (+ `_loop.sh`), `scripts/f0_runner.py`,
  `scripts/extract_trades_from_report.py`, `scripts/duka_*`.
- Worst-fortnight windows: `reports/bench-worst-months-20260610-125342Z/worst_windows.json`.
