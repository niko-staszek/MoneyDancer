//+------------------------------------------------------------------+
//| Regime.mqh — S3.2 ADX regime gate (1.2-line: ADX only).          |
//|                                                                    |
//| When RegimeMode = HARD and ADX >= RegimeAdxThresh, HandleSignal   |
//| short-circuits — no new grid entries. Pyramid is unaffected (its  |
//| own slope filter is the trend-following lane).                    |
//|                                                                    |
//| 2.0 extends this with the MMD multi-cloud classifier; 1.2 stays  |
//| at the ADX rule-based first cut.                                  |
//+------------------------------------------------------------------+
#ifndef __MD_REGIME_MQH__
#define __MD_REGIME_MQH__

int      g_adxHandle      = INVALID_HANDLE;
double   g_lastADX        = 0.0;
datetime g_lastADXBar     = 0;
bool     g_adxInitFailed  = false;

bool RegimeInit()
{
   // Lazy-init the iADX handle in GetCurrentADX — custom symbols in tester
   // don't have indicator-ready bars at OnInit time (4805).
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

double GetCurrentADX()
{
   if(g_adxInitFailed) return 0.0;
   if(g_adxHandle == INVALID_HANDLE)
   {
      g_adxHandle = iADX(_Symbol, RegimeTimeframe, RegimePeriod);
      if(g_adxHandle == INVALID_HANDLE)
      {
         g_adxInitFailed = true;
         PrintFormat("[S3.2] iADX init failed (err=%d) on %s tf=%d period=%d - regime gate disabled",
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
   double adx = GetCurrentADX();
   return (adx >= (double)RegimeAdxThresh);
}

bool RegimeBlocksGridEntries()
{
   if(RegimeMode != REGIME_HARD) return false;
   return IsTrendRegime();
}

#endif
