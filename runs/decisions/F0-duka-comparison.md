---
date: 2026-05-15
story_id: F0
action: broker-comparison
window: 2026-01-01 to 2026-01-31
symbol_rb: XAUUSD (RoboForex-Pro)
symbol_duka: XAUUSD.duk (Dukascopy, imported via ImportDuka script, 36.18M ticks)
override_duka: MaxSpreadPts=100 (Duka median spread ~70 pts; original .set values of 15 blocked >90% of entries)
---

# F0 — RoboForex vs Dukascopy comparison (XAUUSD, January 2026)

Same 5 user .set files, same January window, same deposits — two tick feeds:
- **RoboForex-Pro** (MM/STP, broker's native ticks; what the user trades on)
- **Dukascopy** (ECN historical, imported as custom symbol `XAUUSD.duk`)

The comparison answers whether the F0 RoboForex result is **broker-specific** or
**strategy-real**.

## Side-by-side metrics

| .set | Feed | Net P/L | Net % | PF | Bal DD% | Eq DD% | Trades | Win% |
|---|---|---|---|---|---|---|---|---|
| test1.3a-scalper | RoboForex | +$13.49 | +0.01% | 1.02 | 0.70 | 0.77 | 477 | 92.0% |
| test1.3a-scalper | Dukascopy | **+$2,958.23** | **+2.96%** | **1.64** | 1.13 | 1.53 | **4,186** | 81.1% |
| test13a-fastscalper | RoboForex | +$425.73 | +0.43% | 1.27 | 0.22 | 0.34 | 1,368 | 77.8% |
| test13a-fastscalper | Dukascopy | — | — | — | — | — | — | — |
| 35k-pyramid | RoboForex | +$1,884.92 | +5.39% | 1.09 | 28.63 | 48.66 ⚠ | 294 | 74.8% |
| 35k-pyramid | Dukascopy | **+$5,288.05** | **+15.11%** | **1.25** | 19.76 | 47.03 ⚠ | 413 | 71.7% |
| 3k-heavy-pyramid | RoboForex | +$421.36 | +14.05% | 1.05 | 30.46 ⚠ | 31.27 ⚠ | 734 | 47.4% |
| 3k-heavy-pyramid | Dukascopy | +$432.53 | +14.42% | 1.07 | **36.45 ⚠** | **46.17 ⚠** | 806 | 43.8% |
| **5k-heavy-grid** | **RoboForex** | **+$4,393.24** | **+87.86%** 🥇 | **1.97** | **8.68** ✓ | **11.66** ✓ | **2,619** | **67.4%** |
| **5k-heavy-grid** | **Dukascopy** | **+$3,990.69** | **+79.81%** 🥇 | **2.34** | **3.68** ✓ | **15.15** ✓ | **1,520** | **65.5%** |

`⚠` = exceeds locked 30% DD ceiling. `✓` = under ceiling.

## Notes per config

### test1.3a-scalper
- **RoboForex**: barely profitable (+0.01%) — the tight `MaxSpreadPts=15` matched RoboForex median spread, allowing only the cleanest moments to trade. 92% win-rate but tiny edge per trade.
- **Dukascopy (cap raised to 100)**: jumped to **+2.96%** with 4,186 trades (8.8× more). Strategy is profitable on Duka *because* the wider cap lets it actually deploy. Net is small per trade but volume compounds.
- **Sensitivity to spread cap**: enormous. The same .set on Duka with the original `cap=15` returned **-$1,073** (preserved at `F0-test1.3a-scalper-duka-tightSpread/`). Three configs in one (test1.3a@cap15-RB, test1.3a@cap15-Duka, test1.3a@cap100-Duka) span -$1k to +$3k — demonstrating spread-cap is a discovery-target parameter for Sprint 2's recipe engine, not a hand-pick.

### test13a-fastscalper *(SKIPPED on Duka)*
- **RoboForex**: ran in 16 min, returned +0.43%.
- **Dukascopy**: aborted after 5+ hours, sim only reached Jan 23. Config has `CooldownSec=1` (almost no cooldown between bursts) — on Duka's denser tick stream + wider spread cap, this **opened 23,000+ positions** before being killed. Each tick recalculates basket TPs for every open position → tester crawled.
- **Decision**: this config is **incompatible with Duka tick density**. Either drop the config or add cooldown auto-scaling against tick rate (`CooldownSec = k / TickRate`) — already in the plan's S2.1 candidate-observable list.

### 35k-pyramid
- **Big uplift on Duka**: +5.39% → +15.11%. PF improved 1.09 → 1.25. Bal DD even improved (28.63 → 19.76).
- **Equity DD still blown**: 48.66% (RB) and 47.03% (Duka) — same configuration, same DD ceiling violation on both feeds. S1.0 basket-equity-SL is needed regardless of broker.
- **Pyramid worked better on Duka's wider price moves** (Duka ticks tend to skip more, which feeds pyramid breakouts harder).

### 3k-heavy-pyramid
- **Net essentially identical**: +14.05% vs +14.42%. Strategy edge is broker-agnostic.
- **DD got WORSE on Duka**: 31.27% → 46.17% equity DD. Same DD-blown config, but Duka exposes worse tail behavior. The 47% loss-rate config produces fewer outsized winners on Duka — net survives by edge of luck.
- **Most fragile of the surviving configs.** Lowest robustness across brokers.

### 5k-heavy-grid 🥇
- **Headline finding**: holds up across brokers. RoboForex +87.86% vs Duka +79.81%. Both within striking distance of the 2.5%/day compounding target.
- **Profit factor *better* on Duka**: 2.34 vs 1.97. Wider Duka spreads → fewer trades (1,520 vs 2,619) but each is higher quality.
- **Drawdown profile**: balance DD actually better on Duka (3.68% vs 8.68%); equity DD slightly worse (15.15% vs 11.66%). Both well under the 30% ceiling on both feeds.
- **The strategy edge is real, not broker-specific.** This is the single most important finding from F0.

## Sensitivity ranking (Net % delta, |Duka − RoboForex|)

| .set | RoboForex % | Duka % | |Δ%| |
|---|---|---|---|
| 35k-pyramid | 5.39 | 15.11 | **9.72** (largest swing) |
| 5k-heavy-grid | 87.86 | 79.81 | 8.05 |
| test1.3a-scalper | 0.01 | 2.96 | 2.95 (huge factor change, small abs) |
| 3k-heavy-pyramid | 14.05 | 14.42 | 0.37 (most stable) |

**3k is most broker-stable; 35k is most broker-sensitive.** Both 35k and 5k benefit from Duka's wider spread regime — possibly because Duka ticks capture clean reversion moves that RoboForex's smoothing erodes.

## Synthesis — implications for the plan

1. **5k-heavy-grid is the surviving config.** Validated across two feed sources. Sprint 2 should seed from this .set, not from 35k or pyramid configs.

2. **Spread cap is a high-impact discovery parameter.** test1.3a flipped from +$13 to +$2,958 just by widening the cap. Sprint 2's recipe engine must include `MaxSpreadPts` as a primary tunable, scaling against rolling spread distribution (S1.4's spread-spike circuit breaker + S2.A's `SPREAD_QUANTILE` mode).

3. **test13a-style scalper configs are fragile.** `CooldownSec=1` is a knife-edge parameter; whether it works depends on broker tick density. Sprint 2 should bound `CooldownSec` against `TickRate` to prevent runaway position counts on dense-feed brokers.

4. **Pyramid configs (35k, 3k) have systemic DD problem.** Both hit 30%+ equity DD on BOTH feeds. The DD isn't broker-related — it's inherent to pyramid + grid stack when basket-equity-SL is absent. Confirms F1's choice of basket-equity-SL as a non-negotiable Sprint 1 rail.

5. **5k's no-pyramid heavy grid is the surprising winner across both feeds.** Sprint 5's pyramid stories (S5.2, S5.3) lose more justification — the empirical evidence now spans two brokers and pyramid still doesn't help.

6. **Validity threshold met: the strategy edge is real.** F0's primary question — "is RoboForex +87% a broker fluke?" — has a definite answer: **no, it holds within ±10% on Dukascopy too**. We can proceed to Sprint 1 (survival rails) confident that the strategy is not curve-fit to RoboForex's specific tick stream.

## Decision rule outputs

- **Sprint 2 seed config**: `# GOLD cap 5k dd 4100 - hard scal, mix time, range burst zone.set` (the 5k-heavy-grid config).
- **Cross-broker validation passed**: 79.81% (Duka) ≥ ~80% of 87.86% (RoboForex). Strategy edge is broker-robust within January 2026.
- **Open**: extend to Feb-May 2026 (we have the Duka data) to test multi-month repeatability before committing to live demo.
- **Drop from plan**: nothing yet, but pyramid stories should be reweighted lower; test13a-style scalper variants are deprioritized.

## Open follow-ups (Feb-May validation)

- [ ] Re-run 5k-heavy-grid on Duka for Feb / Mar / Apr / May 2026 (we have ticks already; just batch with different date ranges). **Most critical next step.**
- [ ] Add `MaxSpreadPts` scaling against rolling spread quantile to Sprint 2's parameter shortlist.
- [ ] Add `CooldownSec` scaling against tick rate to Sprint 2's parameter shortlist (closes the test13a-on-Duka explosion).
- [ ] Quantify per-trade slippage delta (RoboForex 40ms vs Duka 40ms with very different tick density) — may explain part of the trade-count divergence.

## Test13a-on-Duka rerun option

Could be retried with `CooldownSec` overridden to a sane value (e.g. 30) so the configuration doesn't explode. Not blocking F0 — note for Sprint 2's recipe-discovery phase.

## Artifacts

- RoboForex runs: `runs/F0-test1.3a-scalper/`, `F0-test13a-fastscalper/`, `F0-35k-pyramid/`, `F0-3k-heavy-pyramid/`, `F0-5k-heavy-grid/`
- Dukascopy v2 runs: `runs/F0-test1.3a-scalper-duka/`, `F0-35k-pyramid-duka/`, `F0-3k-heavy-pyramid-duka/`, `F0-5k-heavy-grid-duka/`
- Dukascopy v1 (tight-cap baseline preserved): `runs/F0-test1.3a-scalper-duka-tightSpread/`
- Original F0 memo (RoboForex-only): `runs/decisions/F0-empirical-2026-Q1.md`
