//+------------------------------------------------------------------+
//| Slope.mqh — MA slope cache + pyramid slope angle                 |
//| Phase A5.1                                                       |
//|                                                                   |
//| MT5 semantic adaptations vs MT4:                                  |
//|  - iMA() signature — MT4: call returned the value at a bar.      |
//|                      MT5: call returns a handle; CopyBuffer      |
//|                      reads the actual value. Handles created     |
//|                      once in SlopeInit, released in SlopeDeinit. |
//|  - Time[0] → iTime(_Symbol, _Period, 0)                          |
//+------------------------------------------------------------------+
#ifndef __MD_SLOPE_MQH__
#define __MD_SLOPE_MQH__

//+------------------------------------------------------------------+
//| Lifecycle                                                         |
//+------------------------------------------------------------------+
bool SlopeInit()
{
   g_ma_handle_main  = iMA(_Symbol, _Period, maPeriod,            0, MODE_EMA, PRICE_CLOSE);
   g_ma_handle_pyram = iMA(_Symbol, _Period, PyramSlopeEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);

   if(g_ma_handle_main == INVALID_HANDLE)
   {
      Print("SlopeInit: failed to create main MA handle (period=", maPeriod, ")");
      return false;
   }
   if(g_ma_handle_pyram == INVALID_HANDLE)
   {
      Print("SlopeInit: failed to create pyram MA handle (period=", PyramSlopeEmaPeriod, ")");
      return false;
   }
   return true;
}

void SlopeDeinit()
{
   if(g_ma_handle_main != INVALID_HANDLE)
   {
      IndicatorRelease(g_ma_handle_main);
      g_ma_handle_main = INVALID_HANDLE;
   }
   if(g_ma_handle_pyram != INVALID_HANDLE)
   {
      IndicatorRelease(g_ma_handle_pyram);
      g_ma_handle_pyram = INVALID_HANDLE;
   }
}

//+------------------------------------------------------------------+
//| Read one MA value at a bar offset. Returns 0.0 on failure.       |
//+------------------------------------------------------------------+
double MA_Value(int handle, int bar)
{
   if(handle == INVALID_HANDLE) return 0.0;
   double buf[];
   if(CopyBuffer(handle, 0, bar, 1, buf) != 1) return 0.0;
   return buf[0];
}

//+------------------------------------------------------------------+
//| Cache slope direction + strength when a new bar appears.          |
//| Called every tick; cheap no-op unless the bar rolled over.        |
//+------------------------------------------------------------------+
void UpdateSlopeCacheIfNewBar()
{
   datetime barTime = iTime(_Symbol, _Period, 0);
   if(barTime == 0) return;
   if(barTime == g_lastBarTime) return;

   g_lastBarTime = barTime;

   double ma0 = MA_Value(g_ma_handle_main, 0);
   double maL = MA_Value(g_ma_handle_main, slopeLookbackBars);
   if(ma0 == 0.0 || maL == 0.0) return;  // buffer not yet populated

   g_cachedSlopePts = (int)MathRound((ma0 - maL) / _Point);

   if(g_cachedSlopePts >= slopeThresholdPts)       g_cachedSlopeDir = +1;
   else if(g_cachedSlopePts <= -slopeThresholdPts) g_cachedSlopeDir = -1;
   else                                             g_cachedSlopeDir = 0;
}

int MarketSlopeSignalCached()       { return g_cachedSlopeDir; }
int MarketSlopeStrengthPtsCached()  { return g_cachedSlopePts; }

//+------------------------------------------------------------------+
//| Pyramid EMA slope angle (signed) in degrees; positive = up.      |
//| Used by Pyramid.mqh (A5.2) to gate adds.                         |
//+------------------------------------------------------------------+
double PyramSlopeAngleCurrentDeg()
{
   int lb = MathMax(1, PyramSlopeLookbackBars);
   double e0 = MA_Value(g_ma_handle_pyram, 0);
   double eL = MA_Value(g_ma_handle_pyram, lb);
   if(e0 == 0.0 || eL == 0.0) return 0.0;

   double diffPts = (e0 - eL) / _Point;
   double ang = MathArctan(diffPts / lb) * 180.0 / 3.141592653589793;
   return ang;
}

bool PyramSlopeOKForDir(int dir)
{
   double ang = PyramSlopeAngleCurrentDeg();
   if(dir > 0) return (ang >=  PyramSlopeAngleDeg);
   if(dir < 0) return (ang <= -PyramSlopeAngleDeg);
   return false;
}

#endif // __MD_SLOPE_MQH__
