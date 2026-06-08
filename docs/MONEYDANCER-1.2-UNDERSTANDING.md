# MoneyDancer 1.2 — how the EA works + the author's set patterns (2026-06)

Reverse-understood from source (`mt5/1.2/MoneyDancer_1.2/`) + backtests of 5 author sets on native 1.2.

## The engine (one machine)

**A momentum-burst martingale grid with a breakeven-TP basket.**

1. **Entry trigger** (`Signal.mqh`, "AI order detection"): watches tick speed. Fast ticks → per-second
   mode; quiet → tick-window mode. Fires when price jerks **≥ MinMovePoints** in a burst, **in the burst
   direction**. With `UseSlopeFilter`, only enters **with the slope** (a with-trend breakout).
2. **Gates** (`HandleSignal`): in trading session? cooldown? **spread < MaxSpreadPts** (a 15 here blocks
   all entries on a wider broker — the most-sensitive knob); regime not blocking; slope agrees.
3. **Basket build:** first `startBe` orders = base lot, each carrying `TP_Points`. Then **ScenarioD
   martingale**: when price moves **away** from basket breakeven by `StepPoints`, add
   `firstLot × lotMultiplier^N`, and recompute a **basket-wide breakeven TP** (`|D=N` tag).
4. **Exits:** basket breakeven-TP (whole basket green), OR `SL_Points` hard stop, OR
   `MaxBasketDD_Pct`/`MaxBasketLossPct`, OR `AfterThisHourClose` time rule, OR `MaxAllTimeDDPct` kill.
5. **Pyramid** (`PyramRange`): separate with-trend runners on strong moves. **ScenarioE**: hedge/runner
   rescue for big losing baskets.

1.2 = 131 inputs, this one engine. **2.0 piled 52 more** (MMD, extra regime, adaptive, telemetry) the
winning sets never use — hence "2.0 is overkill," confirmed from source.

## The author's three archetypes (one engine, dialed differently)

| archetype | sets | PriceStep | TP | SL | lotMult | step | what it does |
|---|---|--:|--:|--:|--:|--:|---|
| **wide-grind** | 35k, 3k* | 0.90 | **1550** | 0/515 | 2–3 | 35 | ride basket to a fat TP through pullbacks |
| **tight-scalp** | 13a, 1.3a | 0.20 | **~100** | **1500–7500** | 1.5 | 15–55 | quick small TPs, hard-stop the basket |
| **aggressive** | 5k | 0.90 | 60 | 0 | **4.0** | 120 | deep martingale, no stop (STEP grew from this) |

The knobs trace one **risk/return dial**: quiet wide-grind → smooth tight-scalp → aggressive martingale.

## Empirical (native 1.2, 1-week sample Apr 6–13 2026 — a GOOD trending week)

| set | deals | ret% | maxDD% | losers | maxlot | note |
|---|--:|--:|--:|--:|--:|---|
| 35k m15 | 143 | +3.3 | 1.0 | 1 | 0.08 | quiet; big TP rarely fills in a week |
| 1.3a m30 | 1467 | +14.2 | **0.9** | 2 | 0.07 | **smoothest** — SL 7500 blocks deep martingale |
| 13a m30 | 5852 | +11.2 | 10.9 | 182 | 1.12 | hyperactive scalp (PriceStep 0.20) |
| 3k m1 | 666 | +49.9 | 7.1 | 177 | 0.81 | aggressive mult 3.0 |
| 5k m5 | 4068 | +128.7 | 12.3 | 0 | 2.56 | mult 4.0 → monster week + blowup fuel |

**Caveats (mandatory):** ONE good week in trending 2026. Aggressive monster returns (5k +128%) are the
martingale honeymoon — they do NOT survive bad weeks (proven: 35k = +65% in 2026 but **+3.2% across all
2025**). MaxSpreadPts raised 15→45 on all (their 15 blocks duka_robo's 25-28 spread). Every-tick: the
PriceStep-0.20 scalp configs are too slow for 4-month runs (timeout) — hence the 1-week sample.

## Takeaways
- The EA has **no inherent edge** — it's a configurable martingale. Good weeks print, bad weeks give back.
- The **risk dial is real and legible**: lotMultiplier + SL presence govern smoothness vs blowup.
- Smoothest deployable-looking config = **1.3a** (hard SL + spacing → 0.9% DD) or **35k** (gentle, doesn't
  bleed). Both candidates for the forward test; aggressive (5k) is a slug-lottery only.
- Confirms the rebuild plan: **1.2 is the clean base** (lean engine, all features the sets use); v3.0
  renames it cleanly, then add auto-lot / ATR-adaptive / manual-orders as verified increments.
