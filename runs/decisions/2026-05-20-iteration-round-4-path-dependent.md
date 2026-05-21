# 2026-05-20 — Iteration round 4: path-dependent basket-handling options

## Motivation

After round 3 concluded that no aggregate market feature discriminates good from bad cells (variance is path-dependent), the user asked: "what about dealing with basket drowned underwater in different regimes? we want to test all 3 options."

The 3 options proposed:
1. **Regime-direction-aware basket SL** — separate thresholds for Range / TrendWith / TrendAgainst
2. **MMD-aware ScenarioD block** — pause martingale adds when MMD opposes basket direction
3. **MMD-gated ScenarioE** — only fire hedge runner when MMD truly opposes basket

## Implementation

All 3 coded in `mt5/2.0/MoneyDancer_2.0/Include/`:

- **Option 1**: `EffectiveBasketLossPct(dir)` in `Basket.mqh` + 3 new inputs (`MaxBasketLossPctRange/TrendWith/TrendAgainst`)
- **Option 2**: gate in `Signal.mqh` ScenarioD path + `BlockDOnAdverseMMD` input. **Bug discovered in first test**: TrendBlocksD only called from ScenarioE (off in ship). Fixed by adding direct gate in ScenarioD path.
- **Option 3**: gate in `ScenarioE.mqh::CheckShouldActivateE` + `UseMMDAdverseGateForE` input

All compiled 0/0. Defaults preserve WT behavior.

## Tests

### Round 4A — initial sample (5 cells × 3 options = 15 runs)

**Option 1 @ 8/12/4 (aggressive):**

| Cell | WT | Opt1 | Delta |
|---|---|---|---|
| mar25 | +3.3 / 25.1 | -6.1 / 33.1 | -9.4pp |
| jan26 | +0.6 / 33.4 | +2.0 / 33.4 | +1.4 |
| sep25 | +65.7 / 27.0 | +19.7 / 35.9 | **-46pp** |
| dec25 | +191 / 12.2 | +207 / 19.4 | +16 (DD worse) |
| apr25 | +177 / 13.8 | +125 / 25.3 | **-52pp** |

Sum: WT +438% → Opt1 +348%. **-90pp.** TrendAgainst=4% too tight.

**Option 2 @ initial wiring:** IDENTICAL to WT (bug — gate never reached).

**Option 3:** IDENTICAL to WT (ScenarioE activation conditions almost never met).

### Round 4B — gentler Option 1 + fixed Option 2

**Option 1B @ 8/10/6 (gentler):**

| Cell | WT | Opt1B | Delta |
|---|---|---|---|
| mar25 | +3.3 / 25.1 | -1.2 / 31.1 | -4.5pp |
| jan26 | +0.6 / 33.4 | +6.3 / 33.4 | +5.7 |
| sep25 | +65.7 / 27.0 | +42.7 / 32.8 | -23pp |
| dec25 | +191 / 12.2 | +229.8 / 15.9 | +38.8 |
| apr25 | +177 / 13.8 | +105.3 / 18.3 | **-72pp** |

Sum: WT +438% → Opt1B +383%. **-55pp.** Better than 8/12/4 but still net negative.

**Option 2B (now-wired):** ALSO IDENTICAL to WT. The MMD-adverse condition (basket open when MMD opposes basket direction) **never fires** in these 5 test cells.

Why: WT mode already filters basket OPENS to be trend-aligned. For Option 2 to fire, MMD must transition mid-basket from range/aligned → opposite. In trend-heavy cells (sep25/dec25/apr25) MMD stays directional. In range-heavy cells (mar25/jan26) MMD doesn't reach ±1 trigger often enough.

## Synthesis

**All three options tested. None beat WT in the sample.**

| Option | Verdict | Reason |
|---|---|---|
| **1: Regime-aware basket SL** | NET -55pp on 5 cells | TrendWith lets baskets get bigger → bigger losses on trend reversals; TrendAgainst tighter clips winning monsters (apr25 lost 72pp) |
| **2: BlockDOnAdverseMMD** | Zero effect | Adverse-MMD condition rarely occurs under WT mode |
| **3: MMD-gated ScenarioE** | Zero effect | ScenarioE activation thresholds (basket DD>55%) almost never met under WT |

The deeper insight: **WT is good enough at the path-level** that the failure modes these options target don't occur often enough to matter. Specifically:

- Option 1 targets "basket too big in adverse regime" → doesn't happen often under WT
- Option 2 targets "ScenarioD adds in adverse regime" → doesn't happen often because WT pre-filters basket directions
- Option 3 targets "ScenarioE-worthy DDs" → don't happen often because basket-SL (8%) cuts losses earlier

## Round 4 conclusion

**WT remains the ship config.** All 4 rounds of investigation have confirmed it:

- Round 1 (WTP/WT5/WTDP): variant attempts, all worse
- Round 2 (static + adaptive MinMove): broke marginal cells
- Round 3 (ATR floor + lot scaling + discriminator search): no aggregate market feature predicts cell performance
- **Round 4 (3 path-dependent basket options): targets fail to fire / clip winners more than save losers**

The strategy's behavior on the 17-month sweep is converged. Backtest-only iteration has run out of useful signals. The next genuine improvement requires **live data** (cent forward test) to reveal which failure modes actually recur in production.

## Code shipped (all OFF by default)

The S2.A framework + this round's options have produced an extensive opt-in toolkit:

| Input | Default | What it does |
|---|---|---|
| `MinMoveAdaptiveMode` | FIXED | S2.A.1 ATR-scaled MinMove |
| `MinATRPointsForEntry` | 0 | S2.A.2 ATR-floor entry gate |
| `LotMultRange` / `LotMultTrend` | 1.0 / 1.0 | S2.A.3 regime-aware lot |
| `PyramidFixedTPPts` | 0 | S3.2c fixed-TP pyramid mode |
| `MaxBasketLossPctRange/TrendWith/TrendAgainst` | 0 / 0 / 0 | S2.A.7-Opt1 regime-aware basket SL |
| `BlockDOnAdverseMMD` | false | S2.A.7-Opt2 ScenarioD MMD gate |
| `UseMMDAdverseGateForE` | false | S2.A.7-Opt3 ScenarioE MMD gate |

These remain in code for future cycles — once cent-live data reveals specific failure modes, the right adaptive levers may be re-tunable from this foundation.

## Recommended next concrete step

**Open RoboForex Pro-Cent demo, deploy WT 2.0 .set, run 30-60 days.** S5.5e in the plan. The only way to learn more from here.
