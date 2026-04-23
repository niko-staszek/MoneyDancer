# MoneyDancer

Tick-burst grid EA with martingale basket + hedge-runner recovery. MT4 and MT5 versions live side by side in this repo.

```
mt4/    Cleaned legacy MT4 EA    → mt4/README.md
mt5/    MT5 port (bare, 1:1)     → mt5/README.md
```

---

## How it works

- **Entry: burst detector.** Waits for price to cluster at one level long enough to look like consolidation (a "burst"), then enters in the direction of the move.
- **Adverse move: martingale (Scenario D).** If price moves against the position, scales in with a grid ladder — bigger lots further from entry, once past the first few positions.
- **Trend confirmation: pyramid.** Optionally scales in *with* the trend too, while an EMA slope filter agrees.
- **Exit: basket break-even TP.** Never closes a basket manually. Instead re-levels every position's TP to the basket's weighted break-even + a few points, so one price touch closes the whole basket at once.
- **Recovery: hedge runners (Scenario E).** If a basket gets deep underwater, opens opposite-direction "runners" that trail profit and siphon it back into the worst-losing position to drag the basket toward break-even.
- **Daily risk layer.** Three independent kill-switches (daily profit cap, after-hour profit-protect, profit-lock floor). Any one of them flattens every position and pauses the EA until the next trading day.
- **Two variants.** `mt4/` is the cleaned legacy MT4 EA. `mt5/` is a bare 1:1 MT5 port of that same EA — no refactoring, no new features.

---

## What it is (detail)

MoneyDancer is a **tick-burst grid EA with a martingale basket, a single-direction pyramid, and an opposite-direction hedge-runner safety layer**. It enters when the price stalls at one level long enough to look like consolidation (a "burst"), scales into the position as price moves against it (Scenario D, martingale), optionally scales in the same direction while the trend confirms (pyramiding), and — when the loss on a basket gets dangerous — opens opposite-side runners that trail a profit back and siphon it into the worst-loser to drag the basket toward break-even (Scenario E).

The EA never closes a basket manually — instead it re-levels the **take-profit of every position in a series to the basket's weighted break-even price + a small offset (`bePoints`)**. When price touches that combined TP, every position in the basket closes at once, netting roughly `bePoints` points of profit regardless of how many martingale adds were done.

On top of the trading mechanics, a **daily risk layer** enforces three independent kill-switches: a daily profit cap, an after-hour profit-protect gate, and a profit-lock floor that captures a mid-day profit and refuses to let equity fall back through it. Any of these, when tripped, closes every open position and pauses the EA until the next trading day.

## Tick-loop order

What happens each `OnTick()`, in sequence (see `MoneyDancer.mq5`):

1. **Position sync** — every 5 s, scan the terminal for open tickets and refresh in-memory state.
2. **Pyramid sync** — every 5 s, reload pyramid CSV, drop closed pyramid tickets, refresh SL/TP from terminal.
3. **Pyramid management** — BUILDING (TP = 0, slope agrees) vs. COASTING (TP = last add's trigger, slope fading), and propagate a weighted-average break-even SL across all pyramid positions.
4. **Tick-rate ring** — push the current tick timestamp into a circular buffer (feeds SECOND/WINDOW mode selection).
5. **Slope cache refresh** — on new bar only, recompute MA slope (cheap no-op otherwise).
6. **Daily risk controls** — evaluate profit cap, after-hour protect, and profit-lock; close-all + pause if any fires.
7. **Scenario E bookkeeping** — count runners, set `IDLE / D / E` state, scan closed runners in deal history, siphon profit into the worst-loser basket position.
8. **Runner trailing** — if runners exist, climb their SLs to break-even at `RunnerBE_StartPts`, then trail at `RunnerTrailDistPts` behind price.
9. **Entry signal** — if not paused, run the burst detector; route through `HandleSignal` which picks basic / Scenario D / Scenario E per state.

## Subsystems

**Signal / burst detector.** Two modes. **SECOND** mode buckets ticks into per-second levels and fires when one level is hit `BurstTicks` times in a row. **WINDOW** mode looks at a rolling `TickWindowTicks`-tick window and fires on the same clustering condition. The EA auto-switches to WINDOW when tick rate falls below `TickRateThreshold` (low-liquidity sessions). Every burst must also clear: spread ≤ `MaxSpreadPts`, price move ≥ `MinMovePoints`, cooldown ≥ `CooldownSec`, slope filter (if enabled), and the same-direction min-distance gate.

**Slope filter.** Two EMAs: `maPeriod` for entry confirmation, `PyramSlopeEmaPeriod` for pyramid gating. Produces a direction (+1 / -1 / 0) and strength in points. Entries are blocked against the slope; pyramid adds require a slope angle ≥ `PyramSlopeAngleDeg`. A "strong counter-trend" threshold (`strongTrendPts`) blocks Scenario D entirely and routes to Scenario E instead.

**Pyramid.** Single-direction scaling on a running trend. Each add registers a trigger (TP\_Points away from its open). While BUILDING, positions carry TP = 0. When slope fades, the module snaps TP on every pyramid position to the last add's trigger, locking the run in. Uses weighted-average BE from the two most-recent adds for a safety SL. Setting `PyramRange = 0` disables the feature and releases all current pyramid positions back to basic TP.

**Basket.** Pure analytics — no trades. Computes running P/L, lot sums, weighted-average BE (simple or cost-aware via bisection with swap + commission), step gates (price must drift `StepPoints` from BE before a new add is allowed), and DD guards (`MaxBasketDD_Pct`, `MaxEquityDD_Pct`). Scenario D and Scenario E read from Basket to decide what to do.

**Scenario D (martingale).** After the first `startBe` positions in a series, further adds use a lot multiplier (`lotMultiplier`) — raising stakes as price moves further from BE. On each add, the basket's TP is re-leveled to `BE + bePoints`. If price is **recovering toward BE** (favorable side), the multiplier does NOT apply — basic lot is used instead. Adds respect `MaxOrdersDir`, `MinOrderDistancePts`, and the Basket step gate.

**Scenario E (hedge runners).** Triggers when Basket or Equity DD breaches guard thresholds, or when a strong counter-trend blocks Scenario D. Opens one or more runners in the **opposite** direction, total lots capped by `HedgeRatio × losing-basket lots`. Runner SL goes to break-even at `RunnerBE_StartPts` profit, then trails `RunnerTrailDistPts` behind price in `RunnerTrailStepPts` increments. When a runner closes in profit, Scenario E siphons `SiphonPct` of that profit into partial-closing the worst-loser basket position (min `MinPartialCloseLot`).

**Risk / IDLE / daily layer.** Snapshots start-of-day balance at `DailyBaselineHour:DailyBaselineMinute`. Three kill-switches, all reading that baseline:
- **Daily profit cap** (`MaxDailyProfitPct`): close-all + pause when equity gain ≥ threshold.
- **After-hour protect** (`AfterThisHourCloseHour/Minute`): after the chosen time, if daily profit ≥ `AfterThisHourMinProfitUsd` AND floating loss ≤ `AfterThisHourMaxFloatingLossUsd`, close-all + pause.
- **Profit-lock** (`RiskFromCurrentProfit` + `UntilHour/Minute`): at the lock time, snapshot current profit; if equity ever drops below `baseline + lockedProfit`, close-all + pause. Hard floor.

Pause lasts until the next calendar day rolls over (00:00).

**Series tracking.** Each direction (buy/sell) maintains an independent series counter. When a basket empties and re-activates, the series ID increments. Position comments embed a `SeriesKey` like `TBb7` (buy, series 7) so baskets from different generations don't contaminate each other's BE calc. Recovered from position comments on EA restart.

**Persistence.** CSVs store position metadata (ticket, TP, SL) and pyramid state (trigger, index, direction). Loaded on `OnInit`, saved on `OnDeinit` and periodically throughout. Allows the EA to reload without losing state.

---

## Parameters

Every `input` in `mt5/MoneyDancer/Include/Inputs.mqh`, grouped by section.

### Working Hours

Time-window filter. Disabled entirely with `UseTradingHours = false`.

| Parameter | Default | Purpose |
|---|---|---|
| `UseTradingHours` | `true` | Master on/off for time filtering |
| `MondayTrading` … `FridayTrading` | `true` | Per-day on/off |
| `MonStart1_Hour / _Minute`, `MonEnd1_Hour / _Minute`, `MonStart2_Hour / _Minute`, `MonEnd2_Hour / _Minute` | `0` | Mon window pair 1 + pair 2. Repeated for Tue–Fri (40 integer fields total). |

**Semantics of the time windows:**
- Both pairs `00:00 – 00:00` → trading allowed 24 h that day.
- `Start == End` and not `00:00` → that set is **DISABLED**.
- Two pairs allow split sessions (e.g. London AM + NY PM).

### Tick-Burst Detection

Core entry signal thresholds.

| Parameter | Default | Purpose |
|---|---|---|
| `PriceStep` | `0.25` | Bucket size for level clustering |
| `BurstTicks` | `10` | Min hits on the same level to qualify as a burst |
| `MinMovePoints` | `20` | Min absolute price drift during the burst |
| `CooldownSec` | `45` | Min seconds between accepted signals |
| `MaxSpreadPts` | `45` | Reject trades when spread exceeds this |

### Hybrid / Window Fallback

Low-liquidity fallback: switches from SECOND to WINDOW mode when the market slows down.

| Parameter | Default | Purpose |
|---|---|---|
| `UseTickWindowFallback` | `true` | Enable the fallback |
| `TickRateLookbackSec` | `10` | Lookback window for tick-rate calc |
| `TickRateThreshold` | `4.0` | Ticks/sec below which WINDOW activates |
| `TickWindowTicks` | `25` | Rolling window size in WINDOW mode |

### MA Slope Filter

EMA-based trend filter for entries + Scenario routing.

| Parameter | Default | Purpose |
|---|---|---|
| `UseSlopeFilter` | `true` | Enable slope check on entries |
| `maPeriod` | `50` | Main EMA period |
| `slopeLookbackBars` | `5` | Bars used to measure slope |
| `slopeThresholdPts` | `20` | Min slope strength to confirm a direction |
| `strongTrendPts` | `60` | Above this, block Scenario D (route to E) |

### Orders / SL / TP

Core trade defaults.

| Parameter | Default | Purpose |
|---|---|---|
| `LotsBase` | `0.01` | Base lot size |
| `TP_Points` | `50` | TP distance for basic (non-Scenario-D) orders |
| `SL_Points` | `0` | SL distance (0 = no SL) |
| `Slippage` | `10` | Max slippage in points |
| `Magic` | `21010` | Magic number for order filtering |

### Scenario D (Martingale Basket)

Grid / martingale escalation.

| Parameter | Default | Purpose |
|---|---|---|
| `ScenarioD` | `true` | Enable martingale layer |
| `startBe` | `5` | Positions before the multiplier kicks in |
| `lotMultiplier` | `1.50` | Applied to basic lot on each D-add |
| `bePoints` | `30` | Basket TP offset (TP = BE + bePoints) |
| `maxLot` | `0.0` | Hard cap on a single lot (0 = unlimited) |
| `MaxOrdersDir` | `50` | Max positions per direction (incl. runners) |
| `StepPoints` | `120` | Required distance from BE before a new add |
| `MinOrderDistancePts` | `100` | Min price gap between same-direction positions |

### Pyramiding

Single-direction scale-in on trend confirmation. `PyramRange = 0` disables the whole module.

| Parameter | Default | Purpose |
|---|---|---|
| `PyramRange` | `0` | Pyramid TP distance (0 = OFF) |
| `PyramSlopeEmaPeriod` | `3` | EMA period for pyramid slope |
| `PyramSlopeLookbackBars` | `5` | Bars for pyramid slope |
| `PyramSlopeAngleDeg` | `20.0` | Min slope angle (degrees) for a pyramid add |
| `PyramBEBufPts` | `0` | Optional buffer added to BE-based SL |

### Loss Guards

Thresholds that arm Scenario E (open hedge runners).

| Parameter | Default | Purpose |
|---|---|---|
| `MaxBasketDD_Pct` | `55.0` | Basket max drawdown (% of balance) |
| `MaxEquityDD_Pct` | `80.0` | Account-level max drawdown (% of balance) |

### Daily Risk Locks

Three independent daily kill-switches. All use the same baseline snapshotted at `DailyBaselineHour:Minute`.

| Parameter | Default | Purpose |
|---|---|---|
| `MaxDailyProfitPct` | `0` | Daily profit cap in % (0 = OFF). Close-all + pause on hit. |
| `DailyBaselineHour` | `1` | Hour when baseline balance is captured |
| `DailyBaselineMinute` | `0` | Minute for the above |
| `AfterThisHourCloseHour` | `-1` | Hour after which the protect gate arms (−1 = OFF) |
| `AfterThisHourCloseMinute` | `0` | Minute for the above |
| `AfterThisHourMinProfitUsd` | `0.0` | Daily profit (USD) required to arm the protect gate |
| `AfterThisHourMaxFloatingLossUsd` | `-10.0` | Floating loss (USD, negative) that trips the gate |
| `RiskFromCurrentProfit` | `false` | Enable the profit-lock floor |
| `RiskFromCurrentProfitUntilHour` | `13` | Hour at which profit is snapshotted and locked |
| `RiskFromCurrentProfitUntilMinute` | `30` | Minute for the above |

### Scenario E (Hedge Runners)

Opposite-direction runners that siphon profit into the losing basket.

| Parameter | Default | Purpose |
|---|---|---|
| `ScenarioE` | `false` | Enable hedge runners |
| `HedgeRatio` | `0.35` | Runner total lots ≤ losing-basket lots × this |
| `RunnerBE_StartPts` | `120` | Profit (points) at which SL snaps to BE |
| `RunnerTrailDistPts` | `200` | Trailing SL distance behind price |
| `RunnerTrailStepPts` | `50` | Min step before SL is climbed again |
| `SiphonPct` | `0.90` | Fraction of closed-runner profit to siphon |
| `MinPartialCloseLot` | `0.01` | Min lot size for a basket partial close |

### Dashboard + Markers (stubs in this bare port)

Present as `input`s so the legacy `.set` presets load cleanly. No visual effect in this repo.

| Parameter | Default | Purpose |
|---|---|---|
| `ShowProDashboard` | `true` | Show dashboard (stub) |
| `DashboardX / Y / Width` | `20 / 30 / 420` | Position + width in pixels |
| `DashAccentColor / DashProfitColor / DashLossColor` | DodgerBlue / Lime / Crimson | Dashboard colors |
| `ShowModernMarkers` | `true` | Chart markers (stub) |
| `ShowBasketLabels` | `true` | Basket labels (stub) |
| `ShowBottomResults` | `true` | Bottom-of-chart results panel (stub) |
| `BottomResultsCount` | `8` | How many recent trades to show |
| `MarkerArrowSize` | `2` | Entry-arrow size |

---

## Gotchas

- **Time-window "disabled" is sneaky.** `Start == End` means trading 24 h **only when both are `00:00`**. Any other value where start equals end **disables** that set. Set one pair active and leave the other at `00:00–00:00` if you only want one window.
- **Pyramid TP flips mid-run.** BUILDING phase holds TP = 0; the moment slope weakens, every pyramid position's TP snaps to the last add's trigger. A position you thought had no TP can close on the next tick.
- **Series are isolated.** Two buy baskets (series 7 and series 8) don't share BE. When a basket closes and a new one starts, it gets a fresh series ID and its own BE calc. This is why position comments carry a `TBbN` / `TBsN` key.
- **Scenario D only escalates on the losing side.** If the price is coming back toward BE, the multiplier isn't used — the EA falls back to `LotsBase`. Prevents throwing bigger lots at a recovery.
- **Runner siphon is close-triggered.** Open runners in profit don't siphon anything. Only a fully-closed runner with positive P/L is scanned from deal history and routed into a basket partial-close.
- **Daily baseline = one snapshot per day.** All three daily locks share the one `DailyBaselineHour` baseline. Crossing midnight resets, but moving the baseline hour mid-day won't re-snapshot.
- **Profit-Lock is a hard floor.** Once armed at `UntilHour`, equity cannot drop below `baseline + lockedProfit`. On breach: close-all + pause until next day. No soft warning — it's a kill-switch.
- **`MaxOrdersDir` counts runners too.** A direction's position cap includes its own basket positions AND any opposite-side runners that were just opened. A high runner count can starve further basket adds.
- **Runner lot ceiling is `HedgeRatio`, not `MaxOrdersDir`.** Both apply simultaneously. Raising `MaxOrdersDir` doesn't let you open more runners if `HedgeRatio × lossBasketLots` is already reached.
- **`SL_Points = 0` means no SL at all.** Basic entries with zero SL rely on the basket BE mechanism and/or the daily risk layer to cut losses. If both are disabled, there is no floor.
- **Cost-aware BE uses bisection.** `BasketBEWithCostsSeries` includes swap + commission and solves the BE price numerically. If the bracket doesn't bound the BE, it falls back to simple weighted-average — silent fallback.

---

## Conventions

- Risk thresholds are always **% of balance**, never fixed dollars.
- The MT5 port is a literal 1:1 translation of `mt4/MoneyDancer_legacy.mq4`. No refactoring, no new features.
