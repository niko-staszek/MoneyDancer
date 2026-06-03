# Detune Round 2 — MaxBasketLossPct x StepPoints (LotMult=1.5/MaxOrders=10 fixed)

Window: XAUUSD.duk_robo_2025 M5, 2025.03.01-03.14, 100k, Model=0. Source: optimization.xml.

WINNER: MaxBasketLossPct=6, StepPoints=40 -> Result +12.18
  Profit $23,845 (+23.8% = ~2.4%/day), Equity DD 6.90%, 2132 trades.

Findings:
- MaxBasketLossPct=6 optimal: beats 8 (R1 value; DD 6.9 vs 8.8 + more profit). 4 gate-fails (<1.5%/day). 2 loses money.
- StepPoints=40 best, monotonic decline to 120 (tighter grid = smoother here).
- Running best 1.5/10/6/40: DD 6.90%, +2.4%/day (vs STEP LotMult4.0/MaxOrders50 ~40% DD).

CAVEAT: 4 levers now tuned to ONE cell (mar25). Overfit risk. VALIDATE 1.5/10/6/40 across cells IS+OOS before Round 3.
