# Benchmark result — 5 author sets x 10 worst fortnights @ 100k, v1.4 auto-lot ON (Add/Equity)

49/50 cells completed. 13a-2026-02 = DNF (run times out: 13a hyperactive grid at 100k auto-lot spews a
260MB+ runaway log — itself a stress signal). Auto-lot base ~1.0 lot @100k (Add/Equity, div 1000, inc 0.01),
Model=0, MaxSpreadPts=45, sets' native MaxLot. Each cell = the worst 14-day excursion window of that month.

## net% matrix (worst-range month first ; BLOWN = account dead, DD>=99% or equity<=0)
| month | wnd rng% | 35k (wide) | 13a (scalp) | 1.3a (scalp) | 5k (aggr) | 3k (aggr) |
|---|---|---|---|---|---|---|
| 2026-01 | 23.0 | BLOWN | +484% | +304% | BLOWN | BLOWN |
| 2026-03 | 21.8 | BLOWN | BLOWN | +343% | BLOWN | BLOWN |
| 2025-04 | 17.0 | BLOWN | +424% | +234% | BLOWN | +83% |
| 2026-02 | 14.9 | BLOWN | DNF | BLOWN | BLOWN | +3445% |
| 2025-10 | 13.9 | BLOWN | +265% | -68% | BLOWN | BLOWN |
| 2025-11 | 7.9 | +22% | +138% | +141% | BLOWN | BLOWN |
| 2025-09 | 6.8 | +30% | +129% | BLOWN | BLOWN | +148% |
| 2025-03 | 6.1 | -49% | BLOWN | BLOWN | BLOWN | +90% |
| 2025-01 | 4.8 | -22% | +2% | +22% | BLOWN | +22% |
| 2025-08 | 4.3 | -56% | +51% | -1% | BLOWN | -31% |

## per-set robustness (across the worst months)
| set | archetype | ran | survived | blown | net% mean | median | worst | best |
|---|---|---|---|---|---|---|---|---|
| 35k  | wide-grind   | 10 | 5 | 5  | -59  | -79  | -104 | +30   |
| 13a  | tight-scalp  | 9  | 7 | 2  | +143 | +129 | -101 | +484  |
| 1.3a | tight-scalp  | 10 | 7 | 3  | +66  | +10  | -112 | +343  |
| 5k   | aggressive   | 10 | 0 | 10 | -181 | -130 | -484 | -85   |
| 3k   | aggressive   | 10 | 6 | 4  | +335 | -5   | -103 | +3445 |

## Verdict
- **5k (mult 4): blows ALL 10 worst months.** Pure slug-lottery; unusable at 100k auto-lot. Confirms prior.
- **35k (wide-grind): blows 5/10, mean -59%.** Big-TP basket can't recover sustained moves; weak on bad months.
- **13a (tight-scalp, hard SL): most robust on return** — 7/9 survived, +143% mean / +129% median. Hard SL caps the bleed; survives the parabola huge. Still blew the 2026-03 crash (-101%).
- **1.3a (tight-scalp, hardest SL): steadiest** — 7/10 survived, +66% mean / +10% median (lowest variance). The "smooth" candidate; survives where 13a's higher activity sometimes doesn't.
- **3k (mult 3): coin-flip with lottery upside** — 6/10 survived, median -5%, but one +3445% monster (2026-02) skews the mean. High variance.
- **Robustness rank: 13a > 1.3a > 3k > 35k > 5k.** Only the hard-SL tight-scalp sets (13a, 1.3a) are defensible on worst months. Matches the prior "hard SL = survivable; 13a/1.3a = forward-test candidates; 5k = slug-lottery."
- **Auto-lot caveat:** base ~1.0 lot @100k (Add/Equity default) is HOT — it turns survivable-at-0.01 sets into blowups on worst fortnights for the wide/aggressive archetypes. The scaling default is aggressive; a smaller increment or Multiply with a higher divisor would derisk.
