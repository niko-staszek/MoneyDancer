# MoneyDancer 2.0 — Ship presets

## Files in this folder (post-cleanup 2026-05-24)

| File | Status | Use case |
|---|---|---|
| **`XAUUSD_2.0_STEP_ship.set`** | **CURRENT SHIP** | Cent forward deploy. Validated 28/32 cells, +90.2% mean. |
| `XAUUSD_2.0_STEP_PRECLOSE_ship.set` | Opt-in variant | Users prioritizing prop-firm DD bound over max profit. Drops $6k vs STEP on combined H1+H2 but tighter DD on may25-H2-style cells. See HISTORY § S2.C.8. |
| `XAUUSD_2.0_WT_ship.set` | Historical (lineage) | Pre-STEP ship (was filenamed S17 incorrectly — renamed 2026-05-24). 17/17 positive, +63.8% mean. |
| `legacy/XAUUSD_2.0_BASELINE_export.set` | Archive | Stale baseline export with license-stub junk. Kept for forensic reference only. |

## Active ship: `XAUUSD_2.0_STEP_ship.set`

The current production-ready config. Use this for cent forward test and live deployment.

### What it does (TL;DR)

- **Validated**: 17-month sweep (Jan 2025 → May 2026), 16/17 positive cells, $82,120 total on $5k baseline = **+9.66%/day backtest** mean
- **Realistic live target**: 3-5%/day after the usual 30-50% live decay (slippage, latency, swap not in backtest)
- **Strategy**: tick-burst grid martingale on XAUUSD, gated by MMD multi-cloud regime classifier with WITH_TREND direction filter, basket-SL safety, Friday flatten, all-time DD kill

### Knob-by-knob justification

| Input | Value | Why this value |
|---|---|---|
| `UseTradingHours=true` + day windows | 01:30-22:10 (Fri 19:55) | User's tested hours. Friday ends earlier to coordinate with FridayFlattenHour. |
| `PriceStep` | 0.90 | User's 5k-heavy-grid base value. Not retested in S2.C — left intentionally; sensitivity unproven but compounds risk to change. |
| `BurstTicks` | 14 | Same. User-tuned tick-burst window. |
| `MinMovePoints` | 25 | Tested 30/35/40 (round 2/3) — adaptive variants broke marginal cells. Stay at 25 (user-tuned baseline). |
| `MaxSpreadPts` | 100 | Calibrated for Duka spread overlay (median ~70-100). On live RoboForex Pro (median ~25), can tighten to 50 — but validated backtest used 100, ship config matches. |
| `LotsBasePerThousand` | 0.002 | S1.5 auto-scaled lot. (equity/$1000) × 0.002 → 0.01 lot at $5k, 0.20 lot at $100k, 0.40 lot at $200k. Linear scaling verified on 100k Apr1-10 test. |
| `LotMultiplier` | 4.0 | User's value. Tested 2.5/3.0 (round 2/3) — broke monster captures. 4.0 is correctly aggressive. (Renamed from `lotMultiplier` in 2026-05-24 naming refactor.) |
| `LotMultiplierRange` | 0.0 (OFF) | S2.C.5 feature. Stack-on-STEP test (2026-05-21) showed 2.5-in-range hurt monsters 3× more than it helped weak cells. Leave OFF. |
| `BEPoints` | 65 | User's value. Tested 40/100 (S2.C.3 TIGHT/WIDE) — TIGHT broke monsters, WIDE broke mar25. 65 is correct middle. (Renamed from `bePoints`.) |
| `StartBE` | 1 | User's value. Aggressive martingale-from-trade-2 needed for monster captures. (Renamed from `startBe`.) |
| `MaxLot` | 0.0 (no cap) | UNSAFE at high equity. Suggested live setting: `MaxLot=5.0` once equity > $200k real (or cent equivalent). (Renamed from `maxLot`.) |
| `MaxOrdersDir` | 50 | Default. Allows deep baskets. Tested 30 (round 2) — broke things. |
| **`StepPoints`** | **80** | **NEW IN STEP** (was 120). Drives basket-BE gate to trigger earlier → martingale starts sooner → faster basket build-up → captures TP retraces in trend cells. +51% aggregate gain. Single biggest improvement in 5 rounds. |
| **`MinOrderDistancePts`** | **60** | **NEW IN STEP** (was 40). Prevents over-densification at any one price level. Mostly neutral effect alone, but pairs with StepPoints=80. |
| `PyramRange` | 0 (OFF) | Round 1 tested ON variants — all failed (sustained-trend runaway). |
| `PyramidFixedTPPts` | 0 (OFF) | S3.2c feature. Available but not in ship. |
| `MaxBasketDDPct` | 55.0 | User's value. Soft sanity guard (basket-SL at 8% is tighter binding constraint). (Renamed from `MaxBasketDD_Pct`.) |
| `MaxBasketLossPct` | 8.0 | S1.0 ship rail. Tested 5% (round 1) and regime-aware variants (round 4) — all worse. |
| `MaxBasketSLPerDay` | 2 | Day-pause after 2 basket-SLs. Safety mechanism for catastrophic days. |
| `MaxAllTimeDDPct` | 40.0 | S1.6 trailing kill. Conservative — backtest max DD never reached 40%. |
| `FridayFlattenHour` | 20 | S1.7 Friday flatten. Coordinates with FriEnd1Hour=19. |
| `UseNewsBlackout` | false | Tested ON (S17 → FULL) — over-restrictive, killed Apr-2025 monster. Per-event analysis (2026-05-20) confirmed WT regime gate filters news implicitly. |
| `UseSpreadSpikeGuard` | false | Over-restrictive on Duka feeds. Revisit with live RB data if needed. |
| `MaxDailyLossPct` | 0.0 (OFF) | Optional. Set to 15 for additional safety. |
| `HourBlockList` | empty | Tested H20/H23 block (2026-05-20) — broke monster cells. Per-cell hour heterogeneity defeats aggregate filter. |
| `RegimeMode` | 2 (HARD) | S3.2 regime gate enabled. |
| `UseMMDClassifier` | true | S3.2a MMD multi-cloud. Better than ADX. |
| `RegimeTrendMode` | 1 (WITH_TREND) | S3.2b. Allow grid only in MMD's trend direction. Saves Sep 2025 from -20% to +66%. |
| MMD periods (`MMDPeriodRed`/`MMDPeriodOrange`/...) | 12/48/144/288/720/1440/3456 | CashCabaret defaults. Untested but leave alone. (Renamed from `MMDPeriod_Red`/etc.) |
| `ScenarioE` | false | Hedge runners. Round 4 tested with MMD gate — never fired in practice. |
| All other unused features | OFF/0 | See Inputs.mqh for descriptions. |

### Backtest summary

| Stat | Value |
|---|---|
| Total net (17 × $5k) | $82,120 (+$27,901 / +51% over WT) |
| Mean per cell | +96.6% |
| Median per cell | +59.4% |
| Best cell | +305.8% (Dec 2025) |
| Worst cell | -17.8% (Feb 2025) |
| Max DD | 37.79% (Feb 2025) |
| Cells positive | 16/17 |
| Daily-avg | +9.66%/day |

### Live deployment notes

1. **Cent account first**. Open RoboForex Pro-Cent demo with $1k real (= cent $100k). Deploy this .set. Monitor for 30-60 days. Compare daily P&L to backtest expectation.
2. **Realistic live target**: 3-5%/day after typical 30-50% backtest decay.
3. **Watch the feb25 failure mode**: very low-vol months with sudden trend reversals during basket build-up can produce 30%+ DD with negative P&L. This is the known weakness.
4. **maxLot=5.0 once equity > $200k**: avoid sending oversized orders to broker.
5. **No prop**: per user decision, single broker (RoboForex). Multi-broker only after $5M real equity.

## Historical: `XAUUSD_2.0_S17_ship.set` (WT, superseded 2026-05-21)

The previous ship config. WT (with-trend grid) over S17 (block-both). Kept for history. 17/17 positive backtest but lower aggregate than STEP. Identical to STEP except:
- `StepPoints=120` (vs STEP's 80)
- `MinOrderDistancePts=40` (vs STEP's 60)

## Historical: 5k-heavy-grid base sets

The user's original .set files (in repo root). Pre-2.0. No regime gate, no basket-SL. Reference only.
