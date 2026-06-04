# STEP Forward-Test Kit — the one test that can't lie

**Goal:** find out if the 17-month STEP backtest is REAL or curve-fit, by running it on
unseen live ticks. Demo, standard account, ~30 days, hands-off. No further dev.

**Why this and not more backtesting:** 7 parameter hunts all died OOS. Backtesting can only
produce in-sample lies now. Only forward ticks generate new truth.

---

## What to deploy

- **EA:** `MoneyDancer_2.0.ex5` (already compiled in the RoboForex terminal `5FFA5681`,
  with the OnTester change — harmless live).
- **Set file:** `mt5/2.0/MoneyDancer_2.0/presets/XAUUSD_2.0_STEP_ship.set`
  (camelCase, matches the current EA — the validated STEP ship config: LotMultiplier=4.0,
  MaxOrdersDir=50, StepPoints, the S1.0/S1.6/S1.7 rails, RegimeMode HARD + with-trend).
- **Account:** a **standard** RoboForex demo (NOT cent — cent's contract-size differs and
  may trip `VerifySymbolSpec`; we already confirmed standard RoboForex XAUUSD passes).
- **Symbol/chart:** XAUUSD, M5 (the EA is tick/burst driven; timeframe is just the chart).
- **Balance:** $10,000 demo. With `LotsBasePerThousand=0.002` → base lot 0.02, auto-scaling.
  (5k → 0.01, 100k → 0.20. Pick the one matching your real intent; 10k is a clean middle.)

## Deploy steps (5 minutes)

1. Open the RoboForex MT5 terminal, log into a **standard demo** ($10k).
2. Open an **XAUUSD M5** chart. Enable AutoTrading (the toolbar button, green).
3. Drag `MoneyDancer_2.0` onto the chart. In the inputs dialog → **Load** →
   `XAUUSD_2.0_STEP_ship.set`. OK. Confirm "Allow Algo Trading" is checked.

## Pre-flight (MUST see all three, else STOP)

Check the **Experts** tab log right after attach:
1. `MoneyDancer 2.0 init — Sprint 1 rails + Sprint 2 entry`
2. `[PL.3] OK: symbol spec passes critical assertions`
   - If instead `[PL.3] CRITICAL: contract_size=... Refusing` → the broker's gold spec is
     non-standard (cent-like). STOP, paste me the `[PL.3]` lines, I fix the gate.
3. The **dashboard panel** renders top-left of the chart.

If all three: it's live and trading. Walk away.

## Pre-registered PASS / FAIL (decide NOW, don't move the goalposts later)

Run ~30 days (or until a verdict triggers). Honest bar, set before seeing results:

- **PASS** — survives 30 days, **max all-time DD < 40%** (never trips the S1.6 kill),
  net equity **positive**. → STEP is plausibly real. THEN: scale up / cent / portfolio.
- **FAIL** — trips the S1.6 40% DD kill, OR net negative at 30 days, OR a single basket
  blows past the basket-SL into a multi-day bleed. → the backtest was a mirage; the whole
  param hunt was deck chairs. Saved months.
- **AMBIGUOUS** — positive but lumpy / one scary drawdown that recovered. → extend to 60
  days before deciding.

**Honest expectation:** the backtest's ~9.7%/day-avg is fantasy compounding. Live will be
far lower, lumpier, and the OOS cells (mar26/may26-type) showed this family *loses* on some
stretches. Expect drawdowns. The test is **survival + net-positive**, not reproducing the
backtest dream.

## Monitoring (hands-off — DO NOT tune mid-run, that's just live overfitting)

- Once/week: screenshot the dashboard, note equity + max-DD-ever + #baskets.
- Watch for: S1.6 (all-time DD kill), S1.0 (basket-SL pauses), S1.7 (Friday flatten).
- Do NOT change inputs, close trades manually, or "help" it. Let it run or die honestly.

## After

Bring me the 30-day equity + max-DD + the verdict. That result — not another backtest —
decides everything next: scale, cent/real, portfolio netting-escape, or back to the drawing
board with proof the vehicle is wrong.
