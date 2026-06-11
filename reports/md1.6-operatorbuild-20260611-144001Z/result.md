# MoneyDancer 1.6 — operator build — verification

Parts: A label cleanup (Inputs.mqh comments, ~50 labels, all S1.x/Test-it!/MT4 junk removed),
B AutoLotDivisor default 1000->2000 (gentler scaling), C bundled preset XAUUSD_1.3a_2pct.set.

## GATE bit-identical (features OFF) — PASS
13a author set (AutoLotScaling/FoldManualOrders/DailyProfitTarget all OFF), XAUUSD.duk_robo M30,
2026.04.06-04.13, 10k, MaxSpreadPts=45.  1.6 sha256 == 1.5 sha256 = 649b28256781da82. PASS
=> label cleanup + divisor-default change are behavior-neutral.

## Preset smoke — OK
XAUUSD_1.3a_2pct on 1.6 @100k: parsed + ran, first-order lot 0.51 (auto-lot Add/Equity div 2000 => ~0.5
base @100k), 818 deals. Preset keys honored. (Full 1.3a+2% behavior = separate 10-month worst-fortnight run.)
