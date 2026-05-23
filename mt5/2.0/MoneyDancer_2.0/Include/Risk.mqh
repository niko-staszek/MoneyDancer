//+------------------------------------------------------------------+
//| Risk.mqh — daily baseline + MT4 risk controls (1:1 port).        |
//| Phase A5.4                                                       |
//|                                                                   |
//| This module ONLY ports the existing MT4 daily-risk layer:         |
//|  - Daily balance baseline snapshot at configured hour             |
//|  - Max Daily Profit cap (closes all + pauses)                     |
//|  - After-This-Hour profit protection                              |
//|  - Profit Lock After Time                                         |
//|                                                                   |
//| The new Phase B rails (MaxDailyLossPct, IDLE state machine,       |
//| news-aware blackout) are NOT added here — they come in Phase B    |
//| after the 1:1 port is validated.                                  |
//|                                                                   |
//| MT5 adaptations:                                                  |
//|  - AccountBalance() → AccountInfoDouble(ACCOUNT_BALANCE)          |
//|  - AccountEquity()  → AccountInfoDouble(ACCOUNT_EQUITY)           |
//|  - StrToTime()      → StringToTime()                              |
//+------------------------------------------------------------------+
#ifndef __MD_RISK_MQH__
#define __MD_RISK_MQH__

//+------------------------------------------------------------------+
//| Auto-pause state                                                  |
//+------------------------------------------------------------------+
bool IsAutoPaused()
{
   if(g_tradePauseUntil <= 0) return false;
   return (TimeCurrent() < g_tradePauseUntil);
}

void PauseAutoUntilNextDay(string reason)
{
   datetime now = TimeCurrent();
   // Pause until next day 00:00 (server time)
   datetime nextDay = StringToTime(TimeToString(now + 86400, TIME_DATE) + " 00:00");
   g_tradePauseUntil  = nextDay;
   g_tradePauseReason = reason;
}

//+------------------------------------------------------------------+
//| Daily baseline + cached metrics                                   |
//+------------------------------------------------------------------+
void UpdateDailyBaselineAndMetrics()
{
   datetime now = TimeCurrent();
   int dk = DayKey(now);

   // New day → reset baseline flag (pause stays until time passes)
   if(dk != g_baseDayKey)
   {
      g_baseDayKey        = dk;
      g_dayBaseReady      = false;
      g_dayBaseBalance    = 0.0;
      g_dayBaseTime       = 0;
      g_dayProfitUsd      = 0.0;
      g_dayProfitPct      = 0.0;
      g_dayTargetBalance  = 0.0;

      // Reset profit lock state for new day
      g_profitLockCaptured = false;
      g_lockedProfitUsd    = 0.0;
      g_profitLockTime     = 0;

      // S1.0 — reset basket-SL counter on day change.
      // CR-I1 fix: gate this on g_basketSLDayKey so a daily-baseline-hour
      // change mid-day doesn't accidentally reset the counter mid-day.
      if(g_basketSLDayKey != dk)
      {
         g_basketSLToday  = 0;
         g_basketSLDayKey = dk;
      }

      // Reset pause reason only if pause already expired
      if(!IsAutoPaused())
      {
         g_tradePauseUntil  = 0;
         g_tradePauseReason = "";
      }
   }

   datetime baseT = TodayAt(DailyBaselineHour, DailyBaselineMinute);
   if(!g_dayBaseReady && now >= baseT)
   {
      g_dayBaseReady   = true;
      g_dayBaseBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      g_dayBaseTime    = now;
   }

   if(g_dayBaseReady)
   {
      g_dayProfitUsd = AccountInfoDouble(ACCOUNT_BALANCE) - g_dayBaseBalance;
      if(g_dayBaseBalance > 0.0)
         g_dayProfitPct = (g_dayProfitUsd / g_dayBaseBalance) * 100.0;
      else
         g_dayProfitPct = 0.0;

      if(MaxDailyProfitPct > 0)
         g_dayTargetBalance = g_dayBaseBalance * (1.0 + (MaxDailyProfitPct / 100.0));
      else
         g_dayTargetBalance = 0.0;
   }
}

//+------------------------------------------------------------------+
//| Apply the three MT4-era controls: daily profit cap, after-hour   |
//| protect, profit lock. Closes all positions + pauses on trigger.   |
//+------------------------------------------------------------------+
void ApplyDailyRiskControls()
{
   UpdateDailyBaselineAndMetrics();
   if(IsAutoPaused()) return;
   if(!g_dayBaseReady) return;  // baseline not yet set

   double bal      = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq       = AccountInfoDouble(ACCOUNT_EQUITY);
   double floatPL  = BasketFloatingAllMine();
   double dayProfitUsd = (bal - g_dayBaseBalance);

   // 1) Max Daily Profit cap
   if(MaxDailyProfitPct > 0 && g_dayTargetBalance > 0.0)
   {
      if(bal >= g_dayTargetBalance)
      {
         CloseAllPositions();
         PauseAutoUntilNextDay("DAILY_CAP");
         return;
      }
   }

   // 2) After This Hour Close (S1.2: % parallels override USD when set)
   double minProfitUsdEff = AfterThisHourMinProfitUsd;
   double maxFloatLossUsdEff = AfterThisHourMaxFloatingLossUsd;
   if(AfterThisHourMinProfitPct > 0.0)
      minProfitUsdEff = g_dayBaseBalance * AfterThisHourMinProfitPct / 100.0;
   if(AfterThisHourMaxFloatingLossPct > 0.0)
      maxFloatLossUsdEff = -1.0 * g_dayBaseBalance * AfterThisHourMaxFloatingLossPct / 100.0;

   if(AfterThisHourCloseHour >= 0 && AfterThisHourCloseHour <= 23 && minProfitUsdEff > 0.0)
   {
      datetime tLock = TodayAt(AfterThisHourCloseHour, AfterThisHourCloseMinute);
      if(TimeCurrent() >= tLock)
      {
         if(dayProfitUsd >= minProfitUsdEff && floatPL >= maxFloatLossUsdEff)
         {
            CloseAllPositions();
            PauseAutoUntilNextDay("AFTER_HOUR_PROTECT");
            return;
         }
      }
   }

   // 3) Profit Lock After Time (RiskFromCurrentProfit)
   if(RiskFromCurrentProfit)
   {
      datetime tLock = TodayAt(RiskFromCurrentProfitUntilHour, RiskFromCurrentProfitUntilMinute);

      if(TimeCurrent() >= tLock)
      {
         // Snapshot today's realized profit at lock time (non-negative clamp)
         if(!g_profitLockCaptured)
         {
            g_lockedProfitUsd = dayProfitUsd;
            if(g_lockedProfitUsd < 0.0) g_lockedProfitUsd = 0.0;
            g_profitLockCaptured = true;
            g_profitLockTime     = tLock;
         }

         // After lock time: do NOT allow giving back the locked profit
         if(g_lockedProfitUsd > 0.0)
         {
            double floorEq = g_dayBaseBalance + g_lockedProfitUsd;
            if(eq < floorEq)
            {
               CloseAllPositions();
               PauseAutoUntilNextDay("PROFIT_LOCK");
               return;
            }
         }
      }
      else
      {
         // Before lock time: ensure lock is not captured yet
         g_profitLockCaptured = false;
         g_lockedProfitUsd    = 0.0;
         g_profitLockTime     = 0;
      }
   }

   // 4) Total Profit Target (realized + floating) — 1.1
   if(ProfitTargetMode != PROFIT_TARGET_OFF)
   {
      double totalProfit = eq - g_dayBaseBalance;   // equity already includes float
      double targetUsd   = 0.0;

      if(ProfitTargetMode == PROFIT_TARGET_PCT && ProfitTargetPct > 0.0)
         targetUsd = g_dayBaseBalance * (ProfitTargetPct / 100.0);
      else if(ProfitTargetMode == PROFIT_TARGET_USD && ProfitTargetUsd > 0.0)
         targetUsd = ProfitTargetUsd;

      if(targetUsd > 0.0 && totalProfit >= targetUsd)
      {
         CloseAllPositions();
         PauseAutoUntilNextDay("PROFIT_TARGET");
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| S1.0 — per-basket equity stop-loss enforcement.                  |
//|                                                                   |
//| Runs once per tick BEFORE Scenario E activation. For each active |
//| series, if floating loss / equity-at-series-open >= MaxBasketLossPct
//| the series' basket positions (excluding pyramid + runners) are    |
//| closed, the series is marked dead + SL-fired, and the daily      |
//| trigger counter increments. After MaxBasketSLPerDay triggers the |
//| EA pauses until the next 00:00 (server time).                     |
//+------------------------------------------------------------------+
int CloseSeriesBasketPositions_S10(int dir, string seriesKey)
{
   int closed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!IsMinePosition()) continue;
      if(IsPyramidTicket(ticket)) continue;
      if(IsRunner()) continue;
      if(!IsSelectedPositionInSeries(seriesKey)) continue;

      long typ = PositionGetInteger(POSITION_TYPE);
      if(dir > 0 && typ != POSITION_TYPE_BUY)  continue;
      if(dir < 0 && typ != POSITION_TYPE_SELL) continue;

      if(trade.PositionClose(ticket)) closed++;
   }
   return closed;
}

// S5.5f: market-closed detection. The pre-check was deleted (CR-C4) since
// SYMBOL_TRADE_MODE_DISABLED is a permanent state not a session window —
// the pre-check was dead code in practice. The post-attempt error path
// (line ~290) is the real market-closed handler.
datetime g_basketSLMarketClosedLogged_Buy  = 0;
datetime g_basketSLMarketClosedLogged_Sell = 0;

void EnforceBasketSL_Dir(int dir)
{
   if(!BasketEquitySLTriggered(dir)) return;

   int    seriesId = CurrentSeriesId(dir);
   string skey     = SeriesKey(dir, seriesId);

   int closed = CloseSeriesBasketPositions_S10(dir, skey);

   // Defensive: if the series-scoped close found nothing, escalate to a full
   // CloseAll on this tick. This recovers from the Feb-2025 failure mode where
   // a stale-series-key mismatch caused CloseSeriesBasketPositions to return 0
   // while positions continued bleeding.
   if(closed == 0)
   {
      int forced = CloseAllPositions();
      PrintFormat("[S1.0] WARN series close returned 0 (dir=%+d series=%s) -> CloseAll forced=%d",
                  dir, skey, forced);
      if(forced == 0)
      {
         // S5.5f: classify the failure. If MT5 last error indicates market closed,
         // back off (positions can't be closed; we'll retry next tick when open).
         // Otherwise log CRITICAL (rare broker edge case).
         int err = GetLastError();
         if(err == 4756 || err == 132 /*ERR_MARKET_CLOSED variants*/)
         {
            datetime lastLog2 = (dir > 0 ? g_basketSLMarketClosedLogged_Buy : g_basketSLMarketClosedLogged_Sell);
            datetime now2 = TimeCurrent();
            if(lastLog2 == 0 || (now2 - lastLog2) > 300)
            {
               PrintFormat("[S1.0] market-closed error %d — basket SL deferred (dir=%+d, eq=%.2f)",
                           err, dir, AccountInfoDouble(ACCOUNT_EQUITY));
               if(dir > 0) g_basketSLMarketClosedLogged_Buy = now2;
               else        g_basketSLMarketClosedLogged_Sell = now2;
            }
            return;
         }

         // Even nuclear close failed for non-market-closed reason. Log critical.
         PrintFormat("[S1.0] CRITICAL cannot close any positions; eq=%.2f peak=%.2f err=%d",
                     AccountInfoDouble(ACCOUNT_EQUITY), g_peakEquityEver, err);
         return;
      }
      closed = forced;
   }

   // Mark series dead + SL-fired so a new entry starts a fresh series and
   // Scenario E never promotes leftover positions to runners.
   SetSeriesActive(dir, false);
   if(dir > 0) g_buySeriesSLFired  = true;
   else        g_sellSeriesSLFired = true;

   g_basketSLToday++;

   PrintFormat("[S1.0] basket SL fired: dir=%+d series=%s closed=%d count_today=%d",
               dir, skey, closed, g_basketSLToday);

   // PL.4 — telemetry: log basket-SL fire event
   TelemetryLogEvent("basket_sl_fired",
                     StringFormat("dir=%+d series=%s closed=%d", dir, skey, closed),
                     skey);

   if(MaxBasketSLPerDay > 0 && g_basketSLToday >= MaxBasketSLPerDay)
   {
      // Close runners and pyramid too — the day is over for new entries.
      CloseAllPositions();
      PauseAutoUntilNextDay("BASKET_SL_DAY_LIMIT");
      TelemetryLogEvent("pause_set",
                        StringFormat("reason=BASKET_SL_DAY_LIMIT count=%d", g_basketSLToday));
   }
}

void EnforceBasketSL()
{
   // CR-C1 fix: also enable rail when only the regime-aware S2.A.7 overrides
   // are set (without a base MaxBasketLossPct). Previously the rail was
   // silently disabled for users following the regime-aware setup docs.
   bool any_override = (MaxBasketLossPctRange        > 0.0
                     || MaxBasketLossPctTrendWith    > 0.0
                     || MaxBasketLossPctTrendAgainst > 0.0);
   if(MaxBasketLossPct <= 0.0 && !any_override) return;

   // Intentionally does NOT respect IsAutoPaused(): pause blocks new entries,
   // but existing positions still need rail-level monitoring. The Feb-2025
   // catastrophe happened because the rails went idle during pause while the
   // open basket continued losing for 22 hours.

   if(g_buySeriesActive)  EnforceBasketSL_Dir(+1);
   if(g_sellSeriesActive) EnforceBasketSL_Dir(-1);
}

//+------------------------------------------------------------------+
//| S1.7 — Friday flatten + weekend block.                            |
//| Closes all positions Friday >= FridayFlattenHour and pauses entries
//| until Monday 00:00 server time. Targets the weekend-gap losses    |
//| (4 of 5 worst OOS-2025 drawdowns started Friday and bled through  |
//| the weekend).                                                      |
//+------------------------------------------------------------------+
void PauseAutoUntilMonday(string reason)
{
   datetime now = TimeCurrent();
   MqlDateTime mdt;
   TimeToStruct(now, mdt);
   // day_of_week: 0=Sun, 1=Mon, ..., 5=Fri, 6=Sat
   int days_to_monday = (8 - mdt.day_of_week) % 7;
   if(days_to_monday == 0) days_to_monday = 7;
   datetime monday = now + (datetime)(days_to_monday * 86400);
   string mondayDate = TimeToString(monday, TIME_DATE);
   g_tradePauseUntil  = StringToTime(mondayDate + " 00:00");
   g_tradePauseReason = reason;
}

void EnforceFridayFlatten()
{
   if(FridayFlattenHour <= 0 || FridayFlattenHour > 23) return;

   MqlDateTime mdt;
   TimeToStruct(TimeCurrent(), mdt);
   if(mdt.day_of_week != 5) return;          // Friday only
   if(mdt.hour < FridayFlattenHour) return;  // before cutoff
   if(IsAutoPaused()) return;                // already paused (don't re-fire)

   int closed = CloseAllPositions();
   PrintFormat("[S1.7] Friday flatten: closed %d positions at %02d:%02d (cutoff=%d)",
               closed, mdt.hour, mdt.min, FridayFlattenHour);
   PauseAutoUntilMonday("FRIDAY_FLATTEN");

   // PL.4 — telemetry: log Friday flatten event
   TelemetryLogEvent("friday_flatten", StringFormat("closed=%d hour=%d", closed, mdt.hour));
}

//+------------------------------------------------------------------+
//| S2.C.8 — Daily pre-close flatten + XAU daily-break pause.         |
//| Closes everything N minutes before the broker's XAU daily-break   |
//| window (~00:00 UTC), then pauses until DailyResumeHour the next   |
//| day. Targets the may25-H2 mechanism where basket-SL rail couldn't |
//| close baskets during the market-closed pocket and the basket bled |
//| past the all-time DD ceiling. Friday is left to S1.7 when on.     |
//+------------------------------------------------------------------+
void EnforceDailyPreClose()
{
   if(DailyPreCloseHour <= 0 || DailyPreCloseHour > 23) return;

   datetime now = TimeCurrent();
   MqlDateTime mdt;
   TimeToStruct(now, mdt);
   // CR-I5 fix: MT5 day_of_week: 0=Sunday, 6=Saturday. Both are non-trading.
   if(mdt.day_of_week == 0 || mdt.day_of_week == 6) return;

   bool past_cutoff = (mdt.hour > DailyPreCloseHour) ||
                      (mdt.hour == DailyPreCloseHour && mdt.min >= DailyPreCloseMinute);
   if(!past_cutoff) return;
   if(IsAutoPaused()) return;                // already paused (S1.7, daily-loss, etc.)

   int closed = 0;

   if(DailyPreCloseLossThresholdPct > 0.0)
   {
      // Conditional close: only flatten baskets whose floating loss exceeds threshold.
      // Lets winning baskets continue capturing the overnight move while cutting off
      // baskets that are heading into the closed-window with a deficit.
      double eq = AccountInfoDouble(ACCOUNT_EQUITY);
      double lossAbsThreshold = (DailyPreCloseLossThresholdPct / 100.0) * eq;

      if(g_buySeriesActive)
      {
         double pl = BasketFloatingPL(+1, false);
         if(pl <= -lossAbsThreshold)
         {
            int    sid  = CurrentSeriesId(+1);
            string skey = SeriesKey(+1, sid);
            int    n    = CloseSeriesBasketPositions_S10(+1, skey);
            closed += n;
            PrintFormat("[S2.C.8] daily pre-close: closed BUY basket n=%d pl=%.2f thr=-%.2f%%eq=-%.2f @ %02d:%02d",
                        n, pl, DailyPreCloseLossThresholdPct, lossAbsThreshold, mdt.hour, mdt.min);
         }
      }
      if(g_sellSeriesActive)
      {
         double pl = BasketFloatingPL(-1, false);
         if(pl <= -lossAbsThreshold)
         {
            int    sid  = CurrentSeriesId(-1);
            string skey = SeriesKey(-1, sid);
            int    n    = CloseSeriesBasketPositions_S10(-1, skey);
            closed += n;
            PrintFormat("[S2.C.8] daily pre-close: closed SELL basket n=%d pl=%.2f thr=-%.2f%%eq=-%.2f @ %02d:%02d",
                        n, pl, DailyPreCloseLossThresholdPct, lossAbsThreshold, mdt.hour, mdt.min);
         }
      }

      // CR-I9 fix: in conditional-close mode, if we closed any basket
      // direction, ALSO sweep up runners and pyramid positions in that
      // direction. Otherwise the broker enters the daily-break window
      // with hedge runners / pyramid open and the rail's "no exposure
      // during closed window" purpose is defeated.
      if(closed > 0)
      {
         int extras = CloseAllPositions();  // closes runners + pyramid + any leftovers
         if(extras > closed) PrintFormat("[S2.C.8] daily pre-close: also closed %d extras (runners/pyramid)", extras - closed);
      }
   }
   else
   {
      // Unconditional close (legacy).
      closed = CloseAllPositions();
      PrintFormat("[S2.C.8] daily pre-close flatten: closed %d positions at %02d:%02d (cutoff=%02d:%02d)",
                  closed, mdt.hour, mdt.min, DailyPreCloseHour, DailyPreCloseMinute);
   }

   if(closed <= 0) return;  // nothing closed — let winners run; no pause

   // Resume target: today at DailyResumeHour:00 if still in the future,
   // otherwise tomorrow at DailyResumeHour:00.
   int rh = DailyResumeHour;
   if(rh < 0) rh = 0;
   if(rh > 23) rh = 23;
   datetime today_resume = StringToTime(TimeToString(now, TIME_DATE) + " " +
                                         StringFormat("%02d:00", rh));
   datetime resume = (today_resume > now) ? today_resume : today_resume + 86400;
   g_tradePauseUntil  = resume;
   g_tradePauseReason = "DAILY_PRECLOSE";

   // PL.4 — telemetry: log daily-pre-close event
   TelemetryLogEvent("daily_preclose",
                     StringFormat("closed=%d threshold=%.2f resume=%s",
                                  closed, DailyPreCloseLossThresholdPct, TimeToString(resume)));
}

//+------------------------------------------------------------------+
//| S1.3 - intraday hard daily-loss kill (separate from S1.6 which is |
//| all-time). Triggers when today's realized+floating loss vs the    |
//| daily baseline reaches MaxDailyLossPct%. Closes all + pauses day. |
//+------------------------------------------------------------------+
void EnforceDailyLossKill()
{
   if(MaxDailyLossPct <= 0.0) return;
   if(IsAutoPaused()) return;
   if(!g_dayBaseReady || g_dayBaseBalance <= 0.0) return;

   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double dayLossPct = (g_dayBaseBalance - eq) / g_dayBaseBalance * 100.0;
   if(dayLossPct >= MaxDailyLossPct)
   {
      CloseAllPositions();
      PauseAutoUntilNextDay("DAILY_LOSS_KILL");
      PrintFormat("[S1.3] daily loss kill: baseline=%.2f eq=%.2f loss=%.2f%% limit=%.2f%%",
                  g_dayBaseBalance, eq, dayLossPct, MaxDailyLossPct);

      // PL.4 — telemetry: log daily-loss kill
      TelemetryLogEvent("daily_loss_kill",
                        StringFormat("loss_pct=%.2f limit=%.2f", dayLossPct, MaxDailyLossPct));
   }
}

//+------------------------------------------------------------------+
//| S1.6 — all-time peak-to-trough drawdown trailing kill.            |
//|                                                                   |
//| Tracks the running max equity since EA start. When the drawdown   |
//| from that peak reaches MaxAllTimeDDPct, close everything and      |
//| pause until next 00:00. Peak is also kept fresh here so the rail  |
//| is self-contained — does not depend on the dashboard updater.    |
//|                                                                   |
//| Peak is now persisted across EA restart by PL.1 (RailStatePersist).|
//+------------------------------------------------------------------+
void EnforceAllTimeDD()
{
   if(MaxAllTimeDDPct <= 0.0) return;
   if(IsAutoPaused()) return;

   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_peakEquityEver <= 0.0 || eq > g_peakEquityEver) g_peakEquityEver = eq;
   if(g_peakEquityEver <= 0.0) return;

   double ddPct = (g_peakEquityEver - eq) / g_peakEquityEver * 100.0;
   if(ddPct > g_maxDDEver) g_maxDDEver = ddPct;

   if(ddPct >= MaxAllTimeDDPct)
   {
      CloseAllPositions();
      PauseAutoUntilNextDay("ALL_TIME_DD_LIMIT");
      PrintFormat("[S1.6] all-time DD kill: peak=%.2f eq=%.2f dd=%.2f%% limit=%.2f%%",
                  g_peakEquityEver, eq, ddPct, MaxAllTimeDDPct);

      // PL.4 — telemetry: log all-time DD trigger
      TelemetryLogEvent("all_time_dd_kill",
                        StringFormat("peak=%.2f eq=%.2f dd_pct=%.2f limit=%.2f",
                                     g_peakEquityEver, eq, ddPct, MaxAllTimeDDPct));
   }
}

#endif // __MD_RISK_MQH__
