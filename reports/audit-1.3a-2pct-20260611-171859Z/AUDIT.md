# AUDIT — 1.3a+2% x 10 worst fortnights (legitness verification)

Independent verification of the data behind reports/bench-1.3a-2pct-20260611-160022Z. Method: reconcile
extracted trades.csv against the raw MT5 .htm reports; check tester model/quality; forensically dissect a
kill-day and a winning-day; estimate omitted costs.

## VERDICT: LEGIT (real every-tick backtests, faithful extraction, genuine mechanism) — with standard
## backtest-optimism caveats, chiefly ZERO COMMISSION.

## 1. Data is real
- History Quality 100% on 8/10 runs; 91% (2026-02) and 83% (2025-01) — minor tick-data gaps on two.
- 1.74M–4.87M real ticks per run; Model=0 (every real tick). Real gold prices (kill-day fills ~$3,660 = Sep-25 level).

## 2. Extraction is faithful (no fabrication in the pipeline)
- trades.csv Total Net == report "Zysk Netto Ogolem" EXACTLY on 7/10 (the 3 "DIFF" are the audit parser
  grabbing an adjacent Polish field on negative nets, not real gaps).
- **Max balance-drawdown% reconciles tester-vs-independently-computed on ALL 10** (e.g. 45.12/45.12,
  29.05/29.05, 3.02/3.02, 43.81~43.91). This can only hold if trades.csv reproduces the tester's full
  equity curve — the strongest integrity check.

## 3. Mechanism is genuine (kill-day forensic, 2025-09-10, -$49,851)
- 221 deals; blow-off closes show martingale escalation lots 0.55 -> 0.82 -> 1.23 -> 1.85 (exactly x1.5 =
  the set's lotMultiplier), all force-closed at one timestamp 14:00:40 = the MaxAllTimeDDPct=40 CloseAllPositions
  firing. Worst single deal 1.85 lots @ -$13,779. Price fell against a buy basket -> martingale added into
  it -> DD-40 capped it. The +2% winning days are real close-all clusters (DailyProfitTargetMode firing).

## 4. Caveats (optimism, NOT fabrication) — apply before trusting live
- **Commission = 0 in the backtest** (duka_robo custom symbol). Real RoboForex ECN ~$3.5/lot round-turn ->
  drag ~0.6-1.7 %pts/fortnight (winners +17% -> ~+16%; the breakeven month 2025-08 flips to ~-0.2%). Modest
  but real for a hyperactive scalper (600-1800 deals/fortnight).
- **DD-40 force-close fills** at backtest tick prices; live, closing a deep basket can slip worse than the
  modeled tick (the -$13.7k deal could be larger live).
- 2 months at 83-91% history quality (data gaps).
- Single broker/symbol (duka_robo), MaxSpreadPts=45 cap, no swap realism, weekend gaps modeled by duka only.
- THESE ARE THE 10 WORST MONTHS by trend magnitude — not representative; the 3/10 kill-day rate is worst-case.

## Bottom line
The +2%/day-then-rare-cliff profile is REAL, not an artifact. Numbers trace to 100%-quality every-tick
backtests; the martingale + DD-40 mechanics are genuine. The honest live adjustment is ~1 %pt/fortnight for
commission plus potentially worse force-close slippage on the kill days. DD-40 remains the only thing
between this and the old wipeouts.
