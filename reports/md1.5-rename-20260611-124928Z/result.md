# MoneyDancer 1.5 — rename ProfitTarget* -> DailyProfitTarget* — verification

Pure identifier rename: 7 tokens (ENUM_DAILY_TARGET_MODE, DAILY_TARGET_OFF/PCT/USD, DailyProfitTargetMode/
Pct/Usd) in Inputs.mqh + Risk.mqh + the XAUUSD_1.2.set preset keys. Defaults/enum-order/logic UNCHANGED.
13a author set, XAUUSD.duk_robo M30, 2026.04.06-04.13, 10k, MaxSpreadPts=45, Model=0.
- 1.4 baseline sha256: 649b28256781da82
- 1.5 renamed  sha256: 649b28256781da82
- **BIT-IDENTICAL: PASS** (rename changed no trade).
