# Detune Round 1 — LotMultiplier x MaxOrdersDir (full grid, 20 combos)

Window: XAUUSD.duk_robo_2025 M5, 2025.03.01-03.14 (single 2wk cell), 100k, Model=0 every-tick.
Criterion: OnTester smoothness = retPct/Ulcer, gated (DD<=40% & dailyAvg>=1.5% -> else negative).
Source: optimization.xml (this folder). EA: MoneyDancer_2.0 + OnTester (commit df00172).

WINNER: LotMultiplier=1.5, MaxOrdersDir=10 -> Result +6.55 (ONLY gate-passing combo)
  Profit $18,972 (+18.97% = ~1.9%/day), Equity DD 8.77%, 2051 trades.

Findings:
- LotMultiplier=1.5 is the sweet spot. 1.0 too weak (<1.5%/day floor). 2.0/2.5 LOSE money (-$2k..-$10.8k), DD 19-23%.
- MaxOrdersDir binds only at 10 (20/30/40/50 identical -> baskets rarely exceed 10 orders in 2wk). Cap at 10 = lower DD (8.77 vs 14) AND higher profit.
- vs STEP baseline (LotMult 4.0 / MaxOrders 50, ~40% DD): far smoother.

CAVEAT: single cell (mar25), borderline 1.5%/day. Validate winner IS+OOS across cells before trusting.
NEXT: carry LotMult=1.5/MaxOrders=10 -> Round 2 sweep MaxBasketLossPct x StepPoints.
