//+------------------------------------------------------------------+
//| RegimeTrace.mqh — S2.C.9 per-trade regime trace                   |
//|                                                                   |
//| Tester-ALLOWED regime trace (PL.4 Telemetry is live-only). Writes |
//| one row per trade open + close with: timestamp, ticket, dir,      |
//| regime, slope-dir, basket-id, lot, price. Enables post-hoc        |
//| per-(DOW, regime, hour) profitability aggregation.                |
//|                                                                   |
//| Default OFF. Enable via `UseRegimeTrace=true` in .set / inputs.   |
//|                                                                   |
//| Output file: MoneyDancer_regime_<Magic>_<Symbol>.csv (single file |
//| per test run, in MQL5/Files; tester writes to its own sandbox).   |
//| Format:                                                            |
//|   ts, event, ticket, dir, regime, slope, basket_id, lot, price   |
//| Event: "open" | "close"                                            |
//| Regime: -1 (bear-trend) | 0 (range) | +1 (bull-trend)            |
//| Slope: -1 (down) | 0 (flat) | +1 (up)                            |
//|                                                                   |
//| Post-process: join with trades.csv on ticket to get profit, then  |
//| group by (DOW, regime, hour) for the S2.C.9 analysis.            |
//+------------------------------------------------------------------+
#ifndef __MD_REGIMETRACE_MQH__
#define __MD_REGIMETRACE_MQH__

int g_regimeTraceFile = INVALID_HANDLE;

string RegimeTraceFileName()
{
   return "MoneyDancer_regime_" + IntegerToString(Magic) + "_" + _Symbol + ".csv";
}

void RegimeTrace_Init()
{
   if(!UseRegimeTrace) return;

   string fn = RegimeTraceFileName();
   int h = FileOpen(fn, FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_SHARE_READ, ',');
   if(h == INVALID_HANDLE)
   {
      PrintFormat("[S2.C.9] regime trace FileOpen failed: %s err=%d", fn, GetLastError());
      return;
   }

   bool isNew = (FileSize(h) == 0);
   FileSeek(h, 0, SEEK_END);
   g_regimeTraceFile = h;

   if(isNew)
      FileWrite(h, "ts", "event", "ticket", "dir", "regime", "slope", "basket_id", "lot", "price");
}

void RegimeTrace_Deinit()
{
   if(g_regimeTraceFile != INVALID_HANDLE)
   {
      FileClose(g_regimeTraceFile);
      g_regimeTraceFile = INVALID_HANDLE;
   }
}

// Called when a position opens (from OpenPosition wrapper).
// regime: -1/0/+1 from MMD_RegimeSimple()
// slope: -1/0/+1 from g_cachedSlopeDir
void RegimeTrace_LogOpen(ulong ticket, int dir, double lot, double price, int basketId)
{
   if(!UseRegimeTrace || g_regimeTraceFile == INVALID_HANDLE) return;
   int regime = (UseMMDClassifier ? MMD_RegimeSimple() : 0);
   FileWrite(g_regimeTraceFile,
      TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
      "open",
      IntegerToString((long)ticket),
      IntegerToString(dir),
      IntegerToString(regime),
      IntegerToString(g_cachedSlopeDir),
      IntegerToString(basketId),
      DoubleToString(lot, 2),
      DoubleToString(price, _Digits));
   FileFlush(g_regimeTraceFile);
}

// Called when a position closes (best-effort: from CloseAllPositions /
// CloseSeriesBasketPositions_S10 — wherever a close fires).
void RegimeTrace_LogClose(ulong ticket, int dir, double lot, double price, int basketId)
{
   if(!UseRegimeTrace || g_regimeTraceFile == INVALID_HANDLE) return;
   int regime = (UseMMDClassifier ? MMD_RegimeSimple() : 0);
   FileWrite(g_regimeTraceFile,
      TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
      "close",
      IntegerToString((long)ticket),
      IntegerToString(dir),
      IntegerToString(regime),
      IntegerToString(g_cachedSlopeDir),
      IntegerToString(basketId),
      DoubleToString(lot, 2),
      DoubleToString(price, _Digits));
   FileFlush(g_regimeTraceFile);
}

#endif // __MD_REGIMETRACE_MQH__
