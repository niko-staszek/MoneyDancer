# MoneyDancer Cent Forward Runbook

Operational guide for deploying STEP on RoboForex Pro-Cent demo as part of S5.5e (cent-account forward test). This is the only remaining actionable work — backtest iteration was declared exhausted 2026-05-23 after 4 consecutive failures since STEP.

**Goal**: validate STEP's +9.66%/day H1 backtest realizes 40-50% live (= 4-5%/day target) over 30-60 calendar days, and surface any live-broker behavior that backtest doesn't capture.

---

## 1. Pre-deploy checklist

- [ ] **RoboForex Pro-Cent demo opened**
  - Sign up at roboforex.com → Open Demo Account → choose "Pro-Cent" type
  - Use $1,000 USD real funding (the platform will display as **100,000 cents**)
  - Save login credentials in a password manager
- [ ] **MT5 terminal configured**
  - Already installed: `C:\Program Files\RoboForex MT5 Terminal\terminal64.exe`
  - Already paired with: `C:\Users\nikof\AppData\Roaming\MetaQuotes\Terminal\5FFA568149E88FCD5B44D926DCFEAA79\`
  - Login to the cent demo via File > Login to Trade Account
- [ ] **EA files deployed** (already done — these copies live at):
  - `MQL5\Experts\MoneyDancer_2.0\MoneyDancer_2.0.ex5`
  - `MQL5\Experts\MoneyDancer_2.0\Include\*.mqh`
  - `MQL5\Experts\MoneyDancer_2.0\presets\XAUUSD_2.0_STEP_ship.set`
- [ ] **AutoTrading button enabled** in MT5 toolbar
- [ ] **Algorithmic trading allowed** in Tools > Options > Expert Advisors

## 2. EA attach

1. Open MT5 → connect to Pro-Cent demo
2. Find symbol `XAUUSD` in Market Watch (right-click > Show All if not visible)
3. Open XAUUSD M5 chart (Window > New Chart > XAUUSD; switch to M5)
4. Drag `MoneyDancer_2.0` from Navigator (Experts folder) onto the chart
5. In the EA properties dialog:
   - **Inputs tab** → Load → select `XAUUSD_2.0_STEP_ship.set`
   - **Common tab** → check "Allow Algo Trading"
   - **Dependencies tab** → if WebRequest URL prompt appears, accept
6. Click OK

## 3. Verify init log

After EA attaches, **Experts log tab** should show (in order):

```
MoneyDancer 2.0 init — Sprint 1 rails + Sprint 2 entry
[PL.3] === Symbol Spec for XAUUSD ===
[PL.3]   digits=2  point=0.01000  tick_size=0.01000  tick_value=1.00000
[PL.3]   contract_size=100.00  vol_min=0.01  vol_max=...  vol_step=0.01
[PL.3]   ...
[PL.3] OK: symbol spec passes critical assertions
[PL.1] no saved rail state at MoneyDancer_railstate_21010_XAUUSD.csv — fresh start
```

**If any `[PL.3] CRITICAL`** → EA refuses to trade. Read message, verify symbol spec via Market Watch → Symbols → XAUUSD → Properties. Contact RoboForex support if spec is genuinely different on cent (not just a misconfigured symbol).

**If contract_size is NOT 100 on cent** → STOP. The lot scaling assumes 100 oz. Need to recalibrate `LotsBasePerThousand` for cent semantics before deploying.

## 4. Webhook setup (PL.5 — daily monitoring)

### Discord
1. In a Discord server you control: Server Settings → Integrations → Webhooks → New Webhook
2. Name it "MoneyDancer", pick a channel, **Copy Webhook URL** (looks like `https://discord.com/api/webhooks/...`)

### Telegram
1. Chat with `@BotFather` → `/newbot` → name it → save the token
2. Chat with your bot once (so it knows you) → `https://api.telegram.org/bot<TOKEN>/getUpdates` → find your chat_id
3. Webhook URL: `https://api.telegram.org/bot<TOKEN>/sendMessage?chat_id=<CHAT_ID>`

### Wire it
1. Tools > Options > Expert Advisors → check **"Allow WebRequest for listed URL"** → add `https://discord.com` (or `https://api.telegram.org`)
2. EA properties → Inputs → set:
   - `WebhookEnabled = true`
   - `WebhookUrl = <your URL>`
   - `WebhookEodHour = 22` (or your preferred server-time hour)
   - `WebhookEodMinute = 30`
3. Apply. First push fires at next `WebhookEodHour:Min` past current time.

To smoke-test the webhook immediately: set `WebhookEodHour` to current server hour + 0 and `WebhookEodMinute` to current minute + 1; wait one minute; verify Discord/Telegram receives the push; then restore to 22:30.

## 5. Daily monitoring (what to check each day)

**Via webhook (Discord/Telegram)** — should arrive every day at WebhookEodHour:
- Day P/L: target +0.5% to +5%; sustained negative days = investigate
- Basket-SL count today: 0 normal; 1 is OK; 2 → day-pause auto-fires
- Paused: should be "no" most days. If reason is `BASKET_SL_DAY_LIMIT` or `DAILY_LOSS_KILL`, day was bad; rails worked.
- Current DD: should stay under 30%. If approaching 35%, S1.6 trailing kill is close.

**In MT5 directly** (weekly review):
- Open the chart, look at the dashboard
- View > Strategy Tester > Account History tab → review closed positions
- Experts log tab → grep for `CRITICAL`, `FAIL`, `[PL.2]` (broker rejections)

## 6. Emergency stop (full halt)

If something looks wrong and you want to stop everything immediately:

1. **Disable AutoTrading** (toolbar button) → blocks new entries. Existing positions stay open.
2. **Remove EA from chart**: right-click chart → Expert Advisors → Remove → confirm.
   - On removal, PL.1 saves rail state to disk so re-attach later resumes correctly.
   - Open positions stay; you can manually close from Terminal panel > Trade tab.
3. **Manual close all**: Terminal panel > Trade tab → right-click any position → "Close All" (if available) or close each manually.

Do NOT just close MT5 — positions stay live on the broker side regardless.

## 7. Weekly review

- Webhook P/L trend: 5-day rolling average daily %
- Compare to backtest expectation: STEP H2 was +5.18%/day for 16 cells
- If 5-day live < 1%/day: investigate (check log for unusual events, basket-SL spikes)
- If 5-day live > 8%/day: also investigate (overshoot suggests larger DD coming)
- Check for new `[PL.2]` retcode patterns in Experts log
- Verify `MoneyDancer_railstate_21010_XAUUSD.csv` is being written (MQL5/Files folder)

## 8. Decision criteria (when to pause / extend / escalate)

| Day | Observation | Action |
|---|---|---|
| 1-3 | Anything other than catastrophic loss | continue, day-1 baseline noise |
| 4-7 | 5-day P/L ≥ 0 and DD < 20% | continue normally |
| 4-7 | 5-day P/L ≥ 0 and DD 20-30% | continue, watch DD trend |
| 4-7 | 5-day P/L < 0 OR DD > 30% | report to research; pause if DD > 35% |
| 8-14 | Mean ≥ +1%/day on $1k = +$10/day = +1 cent-lot equiv | on-track, continue |
| 8-14 | Mean +1-3%/day with bounded DD | good signal, continue 30-day arc |
| 14-30 | Steady positive with rails firing as expected | continue to 60-day arc |
| anywhere | S1.6 all-time DD trigger fires | EA auto-pauses 24h; do NOT manually restart faster |
| anywhere | Two PL.3 spec assertions fail in a row | escalate; broker spec may be inconsistent |
| anywhere | Single-day P/L < -10% | escalate immediately |

## 9. End-of-test debrief

After 30-60 days, do a debrief:
- Total cumulative P/L vs backtest expected on same calendar period
- Max DD vs backtest expected on same calendar period
- Basket-SL fire count distribution
- Whether any rail saved us from a catastrophe
- Whether any unmodeled broker behavior surfaced (PL.2 retcodes, slippage profile)
- Whether STEP behavior matches backtest direction (more or less, not exact)

Update `docs/HISTORY.md` § "Validated facts" with what we learned and § "Open queue" with what to attempt next (e.g., S2.C.9 if cell-specific patterns showed up live, S3.2c if trend-cell behavior was off, etc.).

---

## Quick reference

| File | Purpose |
|---|---|
| `MQL5\Experts\MoneyDancer_2.0\MoneyDancer_2.0.ex5` | Compiled EA |
| `MQL5\Experts\MoneyDancer_2.0\presets\XAUUSD_2.0_STEP_ship.set` | Ship config |
| `MQL5\Files\MoneyDancer_railstate_21010_XAUUSD.csv` | PL.1 state file (auto-written every 60s) |
| `MQL5\Files\MoneyDancer_positions_21010_XAUUSD.csv` | Position memory file (per-tick sync) |
| MT5 Experts log tab | All EA Print() output, scroll-back for grep |

## Inputs you might want to tweak

| Input | Default | When to change |
|---|---|---|
| `WebhookEnabled` / `WebhookUrl` | false / "" | Always enable on live for daily summary |
| `MaxAllTimeDDPct` | 40 | Tighten to 30 once 30-day arc shows DD bound holds |
| `MaxBasketLossPct` | 8 | Leave as-is; this is the per-basket floor |
| `MaxBasketSLPerDay` | 2 | Leave as-is; 2 fires = day-pause is the safety design |
| `FridayFlattenHour` | 20 | Leave as-is; protects against weekend gaps |
| `UseNewsBlackout` | false | Enable if a specific event window starts giving live trouble |
