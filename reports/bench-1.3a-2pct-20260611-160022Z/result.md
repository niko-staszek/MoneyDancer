# 1.3a + 2% daily target (v1.6 deployable) x 10 worst fortnights @100k — vs benchmark 1.3a

Config: XAUUSD_1.3a_2pct.set on MoneyDancer_1.6 (1.3a scalp + AutoLot Add/Equity div2000 ~0.5 base @100k
+ DailyProfitTargetMode=Pct/2 equity-gated close-all+stop-for-day + MaxAllTimeDDPct=40). Model=0,
MaxSpreadPts=45, deposit 100k. Same 10 worst-fortnight windows as reports/bench-worst-months-20260610-125342Z.

## A/B: NEW (1.3a+2%, 0.5-base, DD40) vs OLD (benchmark 1.3a, 1.0-base, no target)
| month | OLD net% | NEW net% | NEW DD% | NEW maxlot |
|---|---|---|---|---|
| 2026-01 | +304 | -39  | 45.1 | 3.5 |
| 2026-03 | +343 | +10  | 29.1 | 3.5 |
| 2025-04 | +234 | +17  | 3.0  | 1.21 |
| 2026-02 | BLOWN | +17 | 2.2  | 1.28 |
| 2025-10 | -68  | +17  | 5.6  | 3.5 |
| 2025-11 | +141 | +17  | 3.1  | 1.89 |
| 2025-09 | BLOWN | -35 | 43.9 | 3.5 |
| 2025-03 | BLOWN | -36 | 43.4 | 3.5 |
| 2025-01 | +22  | +10  | 6.1  | 0.81 |
| 2025-08 | -1   | +1   | 16.7 | 2.63 |

| set | survived | blown | mean% | median% | best% | worst% |
|---|---|---|---|---|---|---|
| OLD 1.3a (1.0-base, no target) | 7/10 | 3 | +66 | +10 | +343 | BLOWN |
| NEW 1.3a+2% (0.5-base, DD40)   | 10/10 | 0 | -2 | +10 | +17 | -39 |

## Verdict — survivability bought with upside
- NO wipeouts: the 3 old blowups (2026-02, 2025-09, 2025-03) become survivable. 10/10 survive.
- Gains capped ~+17%/fortnight by the 2% daily close+stop — the +300% monster months are gone.
- Worst sustained-trend fortnights still -35..-39% (2026-01, 2025-09, 2025-03): price runs against the grid
  BEFORE any +2% day, so the daily target never fires; MaxAllTimeDDPct=40 is what caps the loss (BLOWN -> ~-36%).
- 2% daily-stop only helps on days that reach +2% intraday; it cannot rescue a basket that draws down monotonically.
- DD-40 is the real survival lever here; the 2% target smooths/caps winners.
