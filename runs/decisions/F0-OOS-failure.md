---
date: 2026-05-15
story_id: F0
action: invalidates-prior-conclusion
severity: HIGH
---

# F0 — Out-of-sample failure of the 5k-heavy-grid "winner"

## What we tested

Same `# GOLD cap 5k dd 4100 - hard scal, mix time, range burst zone.set` config
that delivered the F0 "winner" result (+87.86% on RoboForex January 2026,
+79.81% on Dukascopy January 2026). Tested on **held-out Apr-May 2026 data**
(Dukascopy ticks, same `MaxSpreadPts=100` override).

## Result

| Metric | Train (RoboForex Jan) | Train (Duka Jan) | **OOS (Duka Apr-May 2026)** |
|---|---|---|---|
| Net P/L | +$4,393 | +$3,991 | **-$21,464** (deposit was $5,000) |
| Net % | +87.86% | +79.81% | **-429%** (account went deep negative) |
| Profit factor | 1.97 | 2.34 | **0.05** |
| Balance DD% | 8.68 | 3.68 | **394.05** |
| Equity DD% | 11.66 | 15.15 | **407.13** |
| Trades | 2,619 | 1,520 | 207 |
| **Test ended** | normal | normal | **broker stop-out at 14% of interval (Apr 7)** |

The strategy survived **6 days** of out-of-sample data before the broker's
stop-out logic terminated the test with the account 4× below deposit.

## Why this matters

This is the **textbook overfitting / regime-shift failure** the IS/OOS split was
designed to detect. The cross-broker validation (Jan-RB vs Jan-Duka, both ~80%)
gave a **false confidence signal** — both feeds covered the same January regime,
so the same .set worked on both. Once moved to *different months* on the same
broker, the strategy collapsed catastrophically.

**The Jan-2026 +87% was a regime-fit, not a robust strategy edge.**

## Why the strategy blew up

Best inference from log + config:
- `lotMultiplier=4.0`, `startBe=1`, `StartOpenLots=0.10` is an aggressive
  martingale starting from order #2.
- After 6 martingale escalations: 0.10 → 0.40 → 1.60 → 6.40 → 25.6 → 102.4 → 409.6 lots.
- Strategy depends on basket-BE closing before deep escalation. In January 2026,
  gold was range-bound enough for BE recovery to complete before martingale
  ran out of margin.
- In April 2026, gold likely trended strongly (NFP Apr 4 + post-Easter moves);
  the martingale escalated past safety; broker margin-call fired.

## Implications for the plan

This finding **changes everything downstream**:

1. **F0 "winner" is invalidated.** The 5k-heavy-grid config is not a Sprint 2 seed.
   Cross-broker confirmation alone was insufficient validation — temporal
   robustness is the binding constraint.

2. **Sprint 1 survival rails are non-negotiable** before any Sprint 2 work.
   Without S1.0 (basket-equity-SL) and S1.3 (daily-loss kill-switch), this
   strategy class can produce -$21k from a $5k account in 6 days.

3. **The compounding 2.5%/day target is now an OPEN QUESTION** — we have *no*
   surviving config across all 4.5 months of 2026 data. Sprint 2 must
   discover one from scratch (via the recipe engine + overfitting defense),
   not seed from a prior "winner".

4. **S2.B overfitting defense (CPCV / PBO / DSR) is validated as critical.**
   This finding is a real-world demonstration of why single-period optimization
   produces misleading results. The plan's gates (PBO < 0.4, DSR > 0,
   CPCV-Ulcer median ≥ static-reference) are the right thresholds.

5. **Re-examine the other 4 configs.** TEST 1.3a-scalper showed broker-sensitivity
   (cap=15 → -$1k on Duka, cap=100 → +$3k on Duka). 3k-heavy-pyramid showed
   broker-stability (+14% on both). But none of them have been OOS-validated.
   They might survive Apr-May better than 5k did — or worse.

6. **Reframe Sprint 2 seeding strategy.** Instead of seeding from "the best
   January config," use **cross-period stability** as the seed criterion:
   - Run all 5 configs across Jan, Feb, Mar, Apr, May separately
   - Pick the config(s) whose monthly net stays in a narrow band (positive +
     similar magnitude across months)
   - That's the seed for recipe discovery

## Per-month breakdown (5k config, Duka, MaxSpreadPts=100)

| Month | Net P/L | Net % | PF | Bal DD% | Eq DD% | Trades | Verdict |
|---|---|---|---|---|---|---|---|
| Jan | +$3,991 | +79.81% | 2.34 | 3.68 ✓ | 15.15 ✓ | 1,520 | Profitable, controlled DD |
| Feb | +$3,594 | +71.94% | 2.10 | 6.28 ✓ | 11.55 ✓ | 1,419 | Profitable, controlled DD |
| **Mar** | +$4,428 | **+88.55%** | 1.62 | **30.79 ⚠** | **100.59 ⚠⚠⚠** | 2,337 | **Near-blowup; recovered** |
| Apr (6 days) | -$21,464 | -429% | 0.05 | 394 ⚠⚠⚠ | 407 ⚠⚠⚠ | 207 | **Stop-out** |

**March is the critical month** — the strategy hit **100.59% equity DD** during
the month (account went to zero in floating terms), but recovered to a positive
close. In a real account this would have triggered:
- Broker margin call (typically 50–100% margin level)
- Our locked 30% DD ceiling kill-switch
- Personal common sense

The recovery in March was **luck of post-drawdown reversal**, not strategy
edge. April didn't get that reversal — the same regime, no mean-reversion.

**Diagnosis confirmed: grid-martingale's textbook failure mode.**
- Jan + Feb: gold ranged → basket BE recovers easily → strategy wins
- Mar: gold trended into a strong move → martingale escalated → near-blowup,
  saved by reversal
- Apr: gold trended again → same escalation, no reversal → broker stop-out

## What this implies for the plan

1. **The 5k config's January edge is regime-dependent, not robust.**
   The cross-broker validation succeeded *only because both feeds covered the
   same January range regime*. Cross-period validation (the right test)
   exposed the strategy is grid-trend-fragile.

2. **No naive .set will solve this.** It's a structural property of the
   strategy: 4× martingale + no SL + no regime gate = blows up in trends.

3. **The plan's Sprint 1 + Sprint 3 stories become the critical path:**
   - **S1.0 basket-equity-SL** — would have stopped March at -30% basket DD
     instead of letting it run to -100%
   - **S1.6 all-time DD trailing kill** — would have stopped April after the
     first deep escalation
   - **S3.2 regime gate (ADX/MMD)** — would have BLOCKED entries during
     trending March/April, sidestepping the failure entirely
   - **S1.5 auto-scaled `LotsBase`** — would have reduced exposure as equity
     dropped, preventing the catastrophic escalation

4. **Sprint 2's seeding strategy must change.** Instead of seeding from
   "best Jan config", run all 5 configs across all months and rank by
   **cross-period stability**. The criterion is monthly returns that stay
   in a narrow band (positive, similar magnitude), not just one breakout
   month.

## Recommended next steps (high-priority order)

1. **Run all 5 user configs across all 5 months (Jan–May)** on Duka — full
   25-cell stability matrix. The config(s) with positive returns in the
   most months become the Sprint 2 seed candidates.
2. **Implement S1.0 basket-equity-SL FIRST** (before any optimization).
   With basket-SL at 8%, re-run the 5k config on Apr-May — does it survive?
3. **Then S3.2 regime gate** — does adding "no entries when ADX > X" save
   the 5k config on Mar-Apr?
4. **Sprint 2 recipe discovery only AFTER** survival rails are in. Without
   them we'd be optimizing on a foundation that catastrophically fails.

## Status of F0 story

**conditional-passed.** The cross-broker AND cross-period exploration
delivered the key empirical insight: **no .set survives without survival
rails**. That's the genuine finding, more valuable than the false "winner"
the single-period test produced.
