//+------------------------------------------------------------------+
//| MMD.mqh — Magic Moving Averages (cloud-stack regime signals)     |
//| S3.2a — lifted from CashCabaret 2026-05-16, telemetry stubs cut. |
//|                                                                   |
//| Seven SMA/EMA cloud pairs at periods {12, 48, 144, 288, 720,     |
//| 1440, 3456}. Regime classifier reads cloud stacking order and    |
//| returns +1 (bull trend) / 0 (range) / -1 (bear trend).           |
//|                                                                   |
//| Public API used by Regime.mqh:                                    |
//|   bool MMD_Init()                                                 |
//|   void MMD_Deinit()                                               |
//|   void MMD_OnNewBarIfAny()  — call every tick; per-bar deduped   |
//|   int  MMD_RegimeSimple()   — -1/0/+1 (block grid in -1 and +1)  |
//+------------------------------------------------------------------+
#ifndef __MD_MMD_MQH__
#define __MD_MMD_MQH__

#define MMD_IDX_RED     0   // 12
#define MMD_IDX_ORANGE  1   // 48
#define MMD_IDX_LBLUE   2   // 144
#define MMD_IDX_BLUE    3   // 288
#define MMD_IDX_LGREEN  4   // 720
#define MMD_IDX_GREEN   5   // 1440
#define MMD_IDX_PURPLE  6   // 3456

double MMD_SMA(int period_idx, int bar)
{
   if(period_idx < 0 || period_idx > 6) return 0;
   if(g_mmdHandlesSMA[period_idx] == INVALID_HANDLE) return 0;
   double v[];
   if(CopyBuffer(g_mmdHandlesSMA[period_idx], 0, bar, 1, v) != 1) return 0;
   return v[0];
}

double MMD_EMA(int period_idx, int bar)
{
   if(period_idx < 0 || period_idx > 6) return 0;
   if(g_mmdHandlesEMA[period_idx] == INVALID_HANDLE) return 0;
   double v[];
   if(CopyBuffer(g_mmdHandlesEMA[period_idx], 0, bar, 1, v) != 1) return 0;
   return v[0];
}

double MMD_CloudMid(int period_idx, int bar)
{
   double s = MMD_SMA(period_idx, bar);
   double e = MMD_EMA(period_idx, bar);
   if(s == 0 || e == 0) return 0;
   return (s + e) / 2.0;
}

bool MMD_Init()
{
   g_mmdPeriods[MMD_IDX_RED]    = MMDPeriodRed;
   g_mmdPeriods[MMD_IDX_ORANGE] = MMDPeriodOrange;
   g_mmdPeriods[MMD_IDX_LBLUE]  = MMDPeriodLBlue;
   g_mmdPeriods[MMD_IDX_BLUE]   = MMDPeriodBlue;
   g_mmdPeriods[MMD_IDX_LGREEN] = MMDPeriodLGreen;
   g_mmdPeriods[MMD_IDX_GREEN]  = MMDPeriodGreen;
   g_mmdPeriods[MMD_IDX_PURPLE] = MMDPeriodPurple;

   // Match Regime.mqh's deferred-init pattern: don't fail OnInit if handles
   // can't be created yet (custom symbols in tester may not have bars ready).
   // We retry lazily in MMD_OnNewBarIfAny / MMD_RegimeSimple.
   for(int i = 0; i < 7; i++)
   {
      g_mmdHandlesSMA[i] = INVALID_HANDLE;
      g_mmdHandlesEMA[i] = INVALID_HANDLE;
   }
   for(int i = 0; i < 3; i++)
   {
      g_mmdLastCrossBarTime[i] = 0;
      g_mmdLastCrossSign[i]    = 0;
   }
   g_mmdLastBarProcessed = 0;
   return true;
}

void MMD_Deinit()
{
   for(int i = 0; i < 7; i++)
   {
      if(g_mmdHandlesSMA[i] != INVALID_HANDLE) { IndicatorRelease(g_mmdHandlesSMA[i]); g_mmdHandlesSMA[i] = INVALID_HANDLE; }
      if(g_mmdHandlesEMA[i] != INVALID_HANDLE) { IndicatorRelease(g_mmdHandlesEMA[i]); g_mmdHandlesEMA[i] = INVALID_HANDLE; }
   }
}

bool MMD_EnsureHandles()
{
   bool all_ok = true;
   for(int i = 0; i < 7; i++)
   {
      if(g_mmdHandlesSMA[i] == INVALID_HANDLE)
         g_mmdHandlesSMA[i] = iMA(_Symbol, _Period, g_mmdPeriods[i], 0, MODE_SMA, PRICE_CLOSE);
      if(g_mmdHandlesEMA[i] == INVALID_HANDLE)
         g_mmdHandlesEMA[i] = iMA(_Symbol, _Period, g_mmdPeriods[i], 0, MODE_EMA, PRICE_CLOSE);
      if(g_mmdHandlesSMA[i] == INVALID_HANDLE || g_mmdHandlesEMA[i] == INVALID_HANDLE) all_ok = false;
   }
   return all_ok;
}

void MMD_EvalCross(int pair_idx, int pFast, int pSlow, datetime barTime)
{
   double fastMid = MMD_CloudMid(pFast, 1);
   double slowMid = MMD_CloudMid(pSlow, 1);
   if(fastMid == 0 || slowMid == 0) return;
   int sign = (fastMid > slowMid) ? +1 : (fastMid < slowMid ? -1 : 0);
   if(sign == 0) return;
   if(g_mmdLastCrossSign[pair_idx] == 0)
   {
      g_mmdLastCrossSign[pair_idx] = sign;
   }
   else if(sign != g_mmdLastCrossSign[pair_idx])
   {
      g_mmdLastCrossSign[pair_idx]    = sign;
      g_mmdLastCrossBarTime[pair_idx] = barTime;
   }
}

void MMD_OnNewBarIfAny()
{
   if(!UseMMDClassifier) return;

   datetime t1 = iTime(_Symbol, _Period, 1);
   if(t1 == 0 || t1 == g_mmdLastBarProcessed) return;
   g_mmdLastBarProcessed = t1;

   MMD_EnsureHandles();
   MMD_EvalCross(0, MMD_IDX_RED,    MMD_IDX_ORANGE, t1);
   MMD_EvalCross(1, MMD_IDX_ORANGE, MMD_IDX_BLUE,   t1);
   MMD_EvalCross(2, MMD_IDX_BLUE,   MMD_IDX_GREEN,  t1);
}

double MMD_Stack()
{
   int bullPairs = 0, bearPairs = 0;
   for(int i = 0; i < 6; i++)
   {
      double fastMid = MMD_CloudMid(i,     0);
      double slowMid = MMD_CloudMid(i + 1, 0);
      if(fastMid == 0 || slowMid == 0) continue;
      if(fastMid > slowMid)      bullPairs++;
      else if(fastMid < slowMid) bearPairs++;
   }
   if(bullPairs == 6) return +1.0;
   if(bullPairs >= 4) return +0.5;
   if(bearPairs == 6) return -1.0;
   if(bearPairs >= 4) return -0.5;
   return 0.0;
}

//+------------------------------------------------------------------+
//| 3-regime classifier consumed by Regime.mqh's gate.                |
//| +1 = bull trend, 0 = range, -1 = bear trend.                     |
//| Grid entries are blocked in both +1 and -1; allowed in 0.        |
//+------------------------------------------------------------------+
int MMD_RegimeSimple()
{
   if(!UseMMDClassifier) return 0;
   MMD_EnsureHandles();
   double s = MMD_Stack();
   if(s >= 0.5)  return +1;
   if(s <= -0.5) return -1;
   return 0;
}

#endif // __MD_MMD_MQH__
