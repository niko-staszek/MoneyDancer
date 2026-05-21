//+------------------------------------------------------------------+
//| Regime.mqh — S3.2 simple regime gate (ADX-based)                 |
//|                                                                   |
//| Classifies the current market as TREND vs RANGE/CHOP using ADX.  |
//| When RegimeMode == HARD and ADX >= RegimeAdxThresh, HandleSignal |
//| short-circuits — no new grid entries (initial OR martingale).    |
//| Pyramid (slope-driven, trend-following) is unaffected and keeps  |
//| running through PyramidManage().                                  |
//|                                                                   |
//| This is the rule-based first cut for Sprint 1 critical-path.     |
//| A later story will replace ADX with the MMD multi-cloud regime   |
//| classifier (3-state bull/range/bear) lifted from CashCabaret.    |
//+------------------------------------------------------------------+
#ifndef __MD_REGIME_MQH__
#define __MD_REGIME_MQH__

int      g_adxHandle      = INVALID_HANDLE;
double   g_lastADX        = 0.0;
datetime g_lastADXBar     = 0;
bool     g_adxInitFailed  = false;   // one-shot: stop retrying iADX once it has failed

bool RegimeInit()
{
   // Don't create the iADX handle here — for custom symbols in the tester
   // the bar history isn't ready at OnInit time and iADX returns 4805
   // (ERR_INDICATOR_CANNOT_LOAD). We lazy-init in GetCurrentADX() instead,
   // by which time bars exist. Returning success here keeps the EA running
   // even when RegimeMode is OFF or HARD.
   g_adxHandle     = INVALID_HANDLE;
   g_lastADX       = 0.0;
   g_lastADXBar    = 0;
   g_adxInitFailed = false;
   return true;
}

void RegimeDeinit()
{
   if(g_adxHandle != INVALID_HANDLE)
   {
      IndicatorRelease(g_adxHandle);
      g_adxHandle = INVALID_HANDLE;
   }
}

//+------------------------------------------------------------------+
//| Cached ADX read — refreshed on each new bar of RegimeTimeframe.  |
//| Handle is created on first call so custom-symbol tester runs     |
//| can attach the indicator after ticks have been ingested.          |
//+------------------------------------------------------------------+
double GetCurrentADX()
{
   if(g_adxInitFailed) return 0.0;   // give up silently after first failure

   if(g_adxHandle == INVALID_HANDLE)
   {
      g_adxHandle = iADX(_Symbol, RegimeTimeframe, RegimePeriod);
      if(g_adxHandle == INVALID_HANDLE)
      {
         g_adxInitFailed = true;
         PrintFormat("[S3.2] iADX init failed (err=%d) on %s tf=%d period=%d — regime gate disabled for this run",
                     GetLastError(), _Symbol, (int)RegimeTimeframe, RegimePeriod);
         return 0.0;
      }
   }

   datetime bar = iTime(_Symbol, RegimeTimeframe, 0);
   if(bar == g_lastADXBar && g_lastADX > 0.0) return g_lastADX;

   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(g_adxHandle, 0, 0, 1, buf) <= 0) return g_lastADX;

   g_lastADX    = buf[0];
   g_lastADXBar = bar;
   return g_lastADX;
}

bool IsTrendRegime()
{
   if(RegimeMode == REGIME_OFF) return false;
   if(UseMMDClassifier) return (MMD_RegimeSimple() != 0);
   double adx = GetCurrentADX();
   return (adx >= (double)RegimeAdxThresh);
}

//+------------------------------------------------------------------+
//| Single check Signal.mqh consults before opening any grid entry.  |
//| Returns true when entries must be blocked by the regime filter.   |
//| Source: MMD multi-cloud when UseMMDClassifier=true, else ADX.     |
//+------------------------------------------------------------------+
bool RegimeBlocksGridEntries()
{
   if(RegimeMode != REGIME_HARD) return false;
   return IsTrendRegime();
}

//+------------------------------------------------------------------+
//| S3.2b direction-aware regime gate.                                |
//|                                                                   |
//| RegimeTrendMode=BLOCK_BOTH (default; S17 behavior): same as the  |
//|   boolean RegimeBlocksGridEntries() — block both dirs in trend.  |
//|                                                                   |
//| RegimeTrendMode=WITH_TREND: in MMD-flagged trend, allow grid only|
//|   in the trend direction. MMD=+1 blocks SELL only, MMD=-1 blocks |
//|   BUY only, MMD=0 (range) allows both. Reduces counter-trend SLs.|
//|                                                                   |
//| Only meaningful with UseMMDClassifier=true. ADX has no direction;|
//|   under ADX, falls back to BLOCK_BOTH semantics regardless of mode.|
//+------------------------------------------------------------------+
bool RegimeBlocksEntryDir(int signalDir)
{
   if(RegimeMode != REGIME_HARD) return false;
   if(!UseMMDClassifier)
   {
      // ADX path: directionless threshold. Mode flag has no effect.
      double adx = GetCurrentADX();
      return (adx >= (double)RegimeAdxThresh);
   }
   int mmd = MMD_RegimeSimple();
   if(mmd == 0) return false;  // RANGE — both dirs allowed
   if(RegimeTrendMode == REGIME_TREND_WITH_TREND)
   {
      // Block only entries opposite to the trend.
      return (mmd != signalDir);
   }
   // Default BLOCK_BOTH — any trend regime kills new grid entries.
   return true;
}

#endif // __MD_REGIME_MQH__
