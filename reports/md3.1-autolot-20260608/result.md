# MoneyDancer 3.1 — equity-scaled auto-lot — VERIFICATION

Added: input LotsBasePerThousand (default 0=OFF) + ComputeBaseLot() (equity/1000*it, clamped).
5 trade-path LotsBase uses -> ComputeBaseLot(). Compiles 0 errors (commit a32f6d3).
All runs: 13a set (ported to 3.0), XAUUSD.duk_robo M30, 2026.04.06-04.13, MaxSpreadPts=45, Model=0.

## GATE A — OFF bit-identical to v3.0 (backward compat)
V31-OFF (10k, no LotsBasePerThousand -> default 0) sha256 == v3.0 baseline sha256 (649b28256781da82). PASS.
=> Adding auto-lot changes NOTHING when off. Existing sets unaffected.

## GATE B — ON equity-scaling proportional
LotsBasePerThousand=0.002 at deposit 50k vs 500k:
- 50k:  first-order lot 0.1, net +10,912
- 500k: first-order lot 1.0, net +71,909
- first-order lot ratio = EXACTLY 10.0x (= the 10x deposit ratio). PASS.
(maxlot both 3.5 = the set's MaxLot cap; net ratio 6.6x muddied by the cap hitting both - first-lot is the clean proof.)
The 5k run errored (margin: small deposit + 13a hyper-martingale) - not a code issue; 50k/500k are the clean comparison.

## VERDICT: v3.1 ACCEPTED — OFF behavior-neutral, ON scales base lot proportionally with equity.
