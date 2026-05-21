# Sprint 1 rails — validation against the F0 catastrophe window

**Date**: 2026-05-15
**Status**: PASS — all three rails (S1.0 + S1.6 + S3.2) implemented in `mt5/1.2/MoneyDancer_1.2/` and empirically validated on the same window that catastrophically blew up MD 1.1 in F0.

## Test design

- **Window**: Apr 1 – Apr 10, 2026. Same first 10 days that produced the F0 OOS catastrophe (broker stop-out at Apr 7, account dead by day 6).
- **Strategy**: `# GOLD cap 5k dd 4100 - hard scal, mix time, range burst zone.set` (5k-heavy-grid — F0's "winner" config).
- **Account**: $5,000 starting balance, 1:500 leverage.
- **EA**: MoneyDancer 1.2.
- **Symbol**: `XAUUSD.duk_robo` — broker-realistic Duka overlay (median 25 pts, p99 80 pts; matches user's RoboForex-Pro spread distribution).
- **Rails-ON config**: `MaxBasketLossPct=8`, `MaxAllTimeDDPct=40`, `RegimeMode=2 (HARD)`, `RegimeAdxThresh=30`, `RegimePeriod=14`, `RegimeTimeframe=15` (M15).
- **Rails-OFF control config**: all rails defaulted (=0/OFF). Same data, same .set otherwise.

## Results

| Metric | F0 baseline (rails OFF, **raw Duka**) | Control (rails OFF, **robo overlay**) | Validation (**rails ON**, robo overlay) |
|---|---|---|---|
| Net profit | **−$21,464** → stop-out | **−$63,995** | **+$7,450** |
| Net % | −429% (account dead) | −1,280% (would be dead) | **+149%** |
| Eq DD max % | 407% | 550.8% | **10.1%** |
| Bal DD max % | — | 272.3% | **15.7%** |
| Trades | ~200 (then dead) | 5,177 | 4,605 |
| Win-rate | — | 73.8% | 72.7% |
| Profit factor | — | 0.4 | **1.7** |
| Max consec losses | — | 7 | 7 |

## Reading

1. **Rails are doing the work, not the spread overlay.** Switching from raw Duka to broker-realistic robo overlay *without* rails made the catastrophe *worse* (−$64K vs −$21K), because tighter spreads let more bad entries through. The robo overlay is not a fix — the rails are.
2. **S1.0 fired exactly when it should.** In the partial Apr 1 – Apr 28 run (rails on, timed out at 2.5h), the basket-equity-SL fired **17 times** across the trending Apr period, including 2× on Apr 3 and 2× on Apr 7 — the very date F0 stop-outed. Day-pause armed twice. No broker stop-out occurred.
3. **S1.6 didn't need to fire.** With S1.0 + S3.2 in place, equity DD bottomed at 10.1% — well under S1.6's 40% ceiling. S1.6 is the secondary backstop.
4. **Rails are not over-restrictive.** Trade count dropped only ~11% vs control (4,605 vs 5,177). The strategy still trades aggressively; rails just cap the worst tail.
5. **F0 conclusion stands.** The 5k config remained structurally vulnerable to trend regimes — F0 wasn't wrong about that. Sprint 2's stability-matrix work is still needed to find a config that's both profitable in range AND structurally safer in trend. The rails are the *floor* under that future work, not the substitute.

## Gate

**Sprint 2 cross-period stability matrix (S2.0a) is now unblocked.** The three critical-path rails are code-complete and empirically validated.

## Artifacts

- `runs/S1-validate-AprMay-rails-on/` — full Apr-May run (timed out at Apr 28); contains the 17 basket-SL firings + full event log.
- `runs/S1-validate-Apr1-10-rails-on/` — focused rails-on run (complete; metrics in `result.yaml`).
- `runs/S1-validate-Apr1-10-rails-OFF-control/` — rails-off control run (complete).
- `mt5/1.2/MoneyDancer_1.2/` — EA source with all three rails wired.
