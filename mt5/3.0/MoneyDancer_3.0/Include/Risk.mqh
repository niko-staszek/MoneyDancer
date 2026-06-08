//+------------------------------------------------------------------+
//| Risk.mqh â€” daily baseline + MT4 risk controls (1:1 port).        |
//| Phase A5.4                                                       |
//|                                                                   |
//| This module ONLY ports the existing MT4 daily-risk layer:         |
//|  - Daily balance baseline snapshot at configured hour             |
//|  - Max Daily Profit cap (closes all + pauses)                     |
//|  - After-This-Hour profit protection                              |
//|  - Profit Lock After Time                                         |
//|                                                                   |
//| The new Phase B rails (MaxDailyLossPct, IDLE state machine,       |
//| news-aware blackout) are NOT added here â€” they come in Phase B    |
//| after the 1:1 port is validated.                                  |
//|                                                                   |
//| MT5 adaptations:                                                  |
//|  - AccountBalance() â†’ AccountInfoDouble(ACCOUNT_BALANCE)          |
//|  - AccountEquity()  â†’ AccountInfoDouble(ACCOUNT_EQUITY)           |
//|  - StrToTime()      â†’ StringToTime()                              |
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

   // New day â†’ reset baseline flag (pause stays until time passes)
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

      // â€” reset basket-SL day counter
      g_basketSLToday  = 0;
      g_basketSLDayKey = dk;

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

   // 2) After This Hour Close
   if(AfterThisHourCloseHour >= 0 && AfterThisHourCloseHour <= 23 && AfterThisHourMinProfitUsd > 0.0)
   {
      datetime tLock = TodayAt(AfterThisHourCloseHour, AfterThisHourCloseMinute);
      if(TimeCurrent() >= tLock)
      {
         if(dayProfitUsd >= AfterThisHourMinProfitUsd && floatPL >= AfterThisHourMaxFloatingLossUsd)
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

   // 4) Total Profit Target (realized + floating) â€” 1.1
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
//| â€” per-basket equity SL enforcement (with bugfix backport).  |
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

void EnforceBasketSL_Dir(int dir)
{
   if(!BasketEquitySLTriggered(dir)) return;

   int    seriesId = CurrentSeriesId(dir);
   string skey     = SeriesKey(dir, seriesId);

   int closed = CloseSeriesBasketPositions_S10(dir, skey);

   // BUGFIX 2026-05-17: on close-failure, escalate to CloseAll on the same
   // tick and do NOT increment the counter (which would trigger a spurious
   // day-pause and leave positions to bleed unmonitored).
   if(closed == 0)
   {
      int forced = CloseAllPositions();
      PrintFormat("[] WARN series close returned 0 (dir=%+d series=%s) -> CloseAll forced=%d",
                  dir, skey, forced);
      if(forced == 0)
      {
         PrintFormat("[] CRITICAL cannot close any positions; eq=%.2f peak=%.2f",
                     AccountInfoDouble(ACCOUNT_EQUITY), g_peakEquityEver);
         return;
      }
      closed = forced;
   }

   SetSeriesActive(dir, false);
   if(dir > 0) g_buySeriesSLFired  = true;
   else        g_sellSeriesSLFired = true;
   g_basketSLToday++;

   PrintFormat("[] basket SL fired: dir=%+d series=%s closed=%d count_today=%d",
               dir, skey, closed, g_basketSLToday);

   if(MaxBasketSlPerDay > 0 && g_basketSLToday >= MaxBasketSlPerDay)
   {
      CloseAllPositions();
      PauseAutoUntilNextDay("BASKET_SL_DAY_LIMIT");
   }
}

void EnforceBasketSL()
{
   if(MaxBasketLossPct <= 0.0) return;
   // BUGFIX 2026-05-17: do NOT respect IsAutoPaused() â€” open positions still
   // need rail-level monitoring even while new entries are paused.
   if(g_buySeriesActive)  EnforceBasketSL_Dir(+1);
   if(g_sellSeriesActive) EnforceBasketSL_Dir(-1);
}

//+------------------------------------------------------------------+
//| â€” all-time peak-to-trough DD trailing kill.                  |
//| Self-maintains g_peakEquityEver / g_maxDDEver so it does not      |
//| depend on the Dashboard updater. Does NOT respect IsAutoPaused.   |
//+------------------------------------------------------------------+
void EnforceAllTimeDD()
{
   if(MaxAllTimeDdPct <= 0.0) return;
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_peakEquityEver <= 0.0 || eq > g_peakEquityEver) g_peakEquityEver = eq;
   if(g_peakEquityEver <= 0.0) return;
   double ddPct = (g_peakEquityEver - eq) / g_peakEquityEver * 100.0;
   if(ddPct > g_maxDDEver) g_maxDDEver = ddPct;
   if(ddPct >= MaxAllTimeDdPct)
   {
      CloseAllPositions();
      PauseAutoUntilNextDay("ALL_TIME_DD_LIMIT");
      PrintFormat("[] all-time DD kill: peak=%.2f eq=%.2f dd=%.2f%% limit=%.2f%%",
                  g_peakEquityEver, eq, ddPct, MaxAllTimeDdPct);
   }
}

#endif // __MD_RISK_MQH__
