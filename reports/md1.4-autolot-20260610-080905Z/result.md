# MoneyDancer 1.4 — account-scaled position size — verification

Feature: opt-in `AutoLotScaling`; base lot scales with equity/balance (add/multiply). Helper
`ComputeBaseLot()`; 5 call-site swaps. Commits: fork 9e5f6de, feature 5dc5df7.
All runs: 13a author set, XAUUSD.duk_robo M30, 2026.04.06-04.13, MaxSpreadPts=45, Model=0.

## GATE OFF — bit-identical to 1.3 (backward-compat) — PASS
AutoLotScaling=false, deposit 10000.
- 1.3 baseline sha256: 649b28256781da82
- 1.4-OFF    sha256: 649b28256781da82
- **OFF == 1.3 BIT-IDENTICAL: PASS** (strict no-op when off; 1.3 itself == 1.2).

## GATE ON — formula-correct — PASS
AutoLotScaling=1, MaxLot=100 (so the set cap can't mask the formula). First basket-order lot
vs expected = ClampLot(formula). units = deposit/1000 (equity≈deposit at t0):
| run | mode/metric | deposit | expected | first-lot | result |
|---|---|---|---|---|---|
| V14-ON-ADD-5k  | Add/Equity      | 5000  | 0.01+0.01x5  = 0.06 | 0.06 | OK |
| V14-ON-ADD-50k | Add/Equity      | 50000 | 0.01+0.01x50 = 0.51 | 0.51 | OK |
| V14-ON-MUL-50k | Multiply/Equity | 50000 | 0.01x50      = 0.50 | 0.50 | OK |
| V14-ON-BAL-50k | Add/Balance     | 50000 | 0.01+0.01x50 = 0.51 | 0.51 | OK |
- **ON formula-correct: PASS** (all four match; Add vs Multiply distinguished 0.51 vs 0.50;
  Balance branch executes = same 0.51 as Equity at t0, as expected).

## VERDICT: v1.4 ACCEPTED — OFF behavior-neutral, ON scales base lot per the add/multiply formula.
