//+------------------------------------------------------------------+
//| AtrSpacing.mqh — ATR-adaptive grid spacing (v3.2, opt-in)        |
//| OFF (AtrSpacingMode==0) => returns the fixed inputs, 3.1-ident.  |
//| Mirrors the Slope.mqh / Regime.mqh handle-lifecycle pattern.     |
//+------------------------------------------------------------------+
#ifndef __MD_ATRSPACING_MQH__
#define __MD_ATRSPACING_MQH__

int    g_atrHandle    = INVALID_HANDLE;
double g_basketAtrPts = -1.0;   // mode 1: ATR(points) frozen for the current basket's life

bool AtrSpacingInit()
{
   g_atrHandle    = INVALID_HANDLE;
   g_basketAtrPts = -1.0;
   if(AtrSpacingMode <= 0) return true;                 // OFF: no handle, no work
   g_atrHandle = iATR(_Symbol, AtrTimeframe, AtrPeriod);
   if(g_atrHandle == INVALID_HANDLE)
      Print("AtrSpacingInit: iATR handle failed (tf=", EnumToString(AtrTimeframe),
            " period=", AtrPeriod, ") — falling back to fixed spacing");
   return true;                                         // non-fatal: helpers fall back to fixed
}

void AtrSpacingDeinit()
{
   if(g_atrHandle != INVALID_HANDLE)
   {
      IndicatorRelease(g_atrHandle);
      g_atrHandle = INVALID_HANDLE;
   }
   g_basketAtrPts = -1.0;
}

// Latest completed-bar ATR in POINTS, or -1 if not ready / invalid.
double AtrPoints()
{
   if(g_atrHandle == INVALID_HANDLE) return -1.0;
   double buf[];
   if(CopyBuffer(g_atrHandle, 0, 0, 1, buf) < 1) return -1.0;
   if(buf[0] <= 0.0) return -1.0;
   return buf[0] / _Point;
}

// Effective spacing in points: fixed when OFF/not-ready, else clamped ATR*mult.
int EffectiveSpacing(int fixedVal, double mult)
{
   if(AtrSpacingMode == 0) return fixedVal;                            // OFF: identical path
   double atrPts = (AtrSpacingMode == 1) ? g_basketAtrPts : AtrPoints();
   if(atrPts <= 0.0) return fixedVal;                                  // not-ready -> fixed fallback
   double v  = MathRound(atrPts * mult);
   double lo = AtrSpacingFloorFrac * fixedVal;
   double hi = AtrSpacingCeilFrac  * fixedVal;
   return (int)MathMax(lo, MathMin(hi, v));
}

int EffectiveStepPoints()      { return EffectiveSpacing(StepPoints,          StepAtrMult); }
int EffectiveMinOrderDistPts() { return EffectiveSpacing(MinOrderDistancePts, MinOrderDistAtrMult); }

#endif // __MD_ATRSPACING_MQH__
