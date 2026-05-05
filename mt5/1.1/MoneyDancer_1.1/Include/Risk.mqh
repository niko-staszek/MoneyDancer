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

#endif // __MD_RISK_MQH__
