# MoneyDancer 1.3 — fold manual orders — verification

Feature: opt-in `FoldManualOrders` folds hand-placed (magic==0) same-symbol orders into the basket
breakeven/TP/exposure/close; add-side stays EA-only (no manual-driven martingale). Commits: fork 0267d21,
feature 0f3747c.

## GATE OFF — bit-identical to 1.2 (backward-compat) — PASS
Set: TEST 13a M30+ (author, native 1.2). XAUUSD.duk_robo M30, 2026.04.06-04.13, deposit 10000,
MaxSpreadPts=45, FoldManualOrders=false (default).
- 1.2 baseline trades.csv sha256: 649b28256781da82
- 1.3-OFF    trades.csv sha256: 649b28256781da82
- **OFF == 1.2 BIT-IDENTICAL: PASS** (same sha; the feature is a strict no-op when off).

## ON forward-test checklist (owner, demo — strategy tester cannot inject hand-placed orders)
With FoldManualOrders=true on a demo chart, once the EA holds an active basket in direction D, hand-open a
magic==0 order in direction D, then confirm from journal/dashboard:
[ ] basket breakeven shifts to include the manual lot
[ ] common TP re-levels; a TP is set on the manual order at BE +/- bePoints
[ ] when the basket hits TP (or a kill-switch fires), the manual order closes WITH the basket
[ ] EA add cadence unchanged: no extra grid orders opened because of the manual order
[ ] lone manual order with NO active EA basket in its direction: counted in exposure/DD/close only, no TP set
Status: PENDING demo run.

## Code-quality review note (2026-06-09)
Quality reviewer raised 5 items; all by-design or cosmetic on controller analysis:
- add-side BE/gates exclude manual (spec decision #3 — adds stay EA-only): intended.
- lone manual order not TP-managed (spec section C): intended.
- MaxOrdersDir "double-count": NOT triggered — add path gates on CountSeriesOrdersDir (series-comment
  filtered, manual has no comment → excluded). Verified Signal.mqh:248/250/253/294.
- dir-level CountOrdersDir (manual-inclusive when on) used ONLY in Dashboard display — cosmetic, reverts
  to 1.2 when off. OFF bit-identical PASS empirically confirms no off-path leak.
