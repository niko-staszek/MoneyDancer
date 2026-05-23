//+------------------------------------------------------------------+
//| RailStatePersist.mqh — PL.1 rail state persistence across EA restart |
//|                                                                   |
//| Tier-A scalars (real-money risk if reset on restart):             |
//|   S1.6 g_peakEquityEver          — all-time DD trailing peak      |
//|   S1.6 g_maxDDEver               — historical worst DD            |
//|   S1.0 g_basketSLToday/DayKey    — daily basket-SL counter        |
//|        g_tradePauseUntil         — active pause timestamp         |
//|        g_buySeriesOpenEquity     — basket-SL anchor (buy)         |
//|        g_sellSeriesOpenEquity    — basket-SL anchor (sell)        |
//|        g_buy/sellSeriesActive    — current series state           |
//|        g_buy/sellSeriesId        — series generation              |
//|   S1.0 g_buy/sellSeriesSLFired   — re-entry block                 |
//|        g_baseDayKey/Balance/Ready/Time — daily baseline           |
//|        g_lastBuyTime/SellTime    — cooldown anchors               |
//|        g_lastDealsCount          — Scenario E siphon              |
//|        g_profitLockCaptured/Usd/Time — RiskFromCurrentProfit lock |
//|                                                                   |
//| Storage: CSV file MoneyDancer_railstate_<Magic>_<Symbol>.csv.     |
//| Key-value pairs, one per line. Survives terminal restart AND      |
//| recompile (since GlobalVariables get cleared on recompile but     |
//| files persist).                                                   |
//|                                                                   |
//| Skipped in tester (MQL_TESTER) so backtest runs stay deterministic.|
//+------------------------------------------------------------------+
#ifndef __MD_RAILSTATEPERSIST_MQH__
#define __MD_RAILSTATEPERSIST_MQH__

string RailStateFileName()
{
   return("MoneyDancer_railstate_" + IntegerToString(Magic) + "_" + _Symbol + ".csv");
}

void SaveRailState()
{
   // Skip in tester — backtest runs must start fresh each time
   if(MQLInfoInteger(MQL_TESTER)) return;

   string fn = RailStateFileName();
   int h = FileOpen(fn, FILE_CSV | FILE_WRITE | FILE_ANSI);
   if(h == INVALID_HANDLE)
   {
      PrintFormat("[PL.1] FAILED to open %s for write (err=%d)", fn, GetLastError());
      return;
   }

   // S1.6 all-time DD trailing
   FileWrite(h, "peakEquityEver",     DoubleToString(g_peakEquityEver, 2));
   FileWrite(h, "maxDDEver",          DoubleToString(g_maxDDEver, 4));

   // S1.0 basket-SL day counter
   FileWrite(h, "basketSLToday",      IntegerToString(g_basketSLToday));
   FileWrite(h, "basketSLDayKey",     IntegerToString(g_basketSLDayKey));

   // Active pause
   FileWrite(h, "tradePauseUntil",    IntegerToString((long)g_tradePauseUntil));
   FileWrite(h, "tradePauseReason",   g_tradePauseReason);

   // Series state + basket-SL anchors
   FileWrite(h, "buySeriesActive",    g_buySeriesActive ? "1" : "0");
   FileWrite(h, "sellSeriesActive",   g_sellSeriesActive ? "1" : "0");
   FileWrite(h, "buySeriesId",        IntegerToString(g_buySeriesId));
   FileWrite(h, "sellSeriesId",       IntegerToString(g_sellSeriesId));
   FileWrite(h, "buySeriesOpenEq",    DoubleToString(g_buySeriesOpenEquity, 2));
   FileWrite(h, "sellSeriesOpenEq",   DoubleToString(g_sellSeriesOpenEquity, 2));
   FileWrite(h, "buySeriesSLFired",   g_buySeriesSLFired ? "1" : "0");
   FileWrite(h, "sellSeriesSLFired",  g_sellSeriesSLFired ? "1" : "0");

   // Daily baseline
   FileWrite(h, "baseDayKey",         IntegerToString(g_baseDayKey));
   FileWrite(h, "dayBaseBalance",     DoubleToString(g_dayBaseBalance, 2));
   FileWrite(h, "dayBaseReady",       g_dayBaseReady ? "1" : "0");
   FileWrite(h, "dayBaseTime",        IntegerToString((long)g_dayBaseTime));

   // Cooldown anchors
   FileWrite(h, "lastBuyTime",        IntegerToString((long)g_lastBuyTime));
   FileWrite(h, "lastSellTime",       IntegerToString((long)g_lastSellTime));

   // Scenario E siphon tracker
   FileWrite(h, "lastDealsCount",     IntegerToString(g_lastDealsCount));

   // Profit lock state
   FileWrite(h, "profitLockCaptured", g_profitLockCaptured ? "1" : "0");
   FileWrite(h, "lockedProfitUsd",    DoubleToString(g_lockedProfitUsd, 2));
   FileWrite(h, "profitLockTime",     IntegerToString((long)g_profitLockTime));

   FileClose(h);
}

void LoadRailState()
{
   if(MQLInfoInteger(MQL_TESTER)) return;

   string fn = RailStateFileName();
   int h = FileOpen(fn, FILE_CSV | FILE_READ | FILE_ANSI);
   if(h == INVALID_HANDLE)
   {
      PrintFormat("[PL.1] no saved rail state at %s — fresh start", fn);
      return;
   }

   int loaded = 0;
   while(!FileIsEnding(h))
   {
      string key = FileReadString(h);
      if(FileIsEnding(h) && key == "") break;
      string val = FileReadString(h);

      if(key == "peakEquityEver")          { g_peakEquityEver     = StringToDouble(val);  loaded++; }
      else if(key == "maxDDEver")          { g_maxDDEver          = StringToDouble(val);  loaded++; }
      else if(key == "basketSLToday")      { g_basketSLToday      = (int)StringToInteger(val); loaded++; }
      else if(key == "basketSLDayKey")     { g_basketSLDayKey     = (int)StringToInteger(val); loaded++; }
      else if(key == "tradePauseUntil")    { g_tradePauseUntil    = (datetime)StringToInteger(val); loaded++; }
      else if(key == "tradePauseReason")   { g_tradePauseReason   = val; loaded++; }
      else if(key == "buySeriesActive")    { g_buySeriesActive    = (val == "1"); loaded++; }
      else if(key == "sellSeriesActive")   { g_sellSeriesActive   = (val == "1"); loaded++; }
      else if(key == "buySeriesId")        { g_buySeriesId        = (int)StringToInteger(val); loaded++; }
      else if(key == "sellSeriesId")       { g_sellSeriesId       = (int)StringToInteger(val); loaded++; }
      else if(key == "buySeriesOpenEq")    { g_buySeriesOpenEquity= StringToDouble(val); loaded++; }
      else if(key == "sellSeriesOpenEq")   { g_sellSeriesOpenEquity = StringToDouble(val); loaded++; }
      else if(key == "buySeriesSLFired")   { g_buySeriesSLFired   = (val == "1"); loaded++; }
      else if(key == "sellSeriesSLFired")  { g_sellSeriesSLFired  = (val == "1"); loaded++; }
      else if(key == "baseDayKey")         { g_baseDayKey         = (int)StringToInteger(val); loaded++; }
      else if(key == "dayBaseBalance")     { g_dayBaseBalance     = StringToDouble(val); loaded++; }
      else if(key == "dayBaseReady")       { g_dayBaseReady       = (val == "1"); loaded++; }
      else if(key == "dayBaseTime")        { g_dayBaseTime        = (datetime)StringToInteger(val); loaded++; }
      else if(key == "lastBuyTime")        { g_lastBuyTime        = (datetime)StringToInteger(val); loaded++; }
      else if(key == "lastSellTime")       { g_lastSellTime       = (datetime)StringToInteger(val); loaded++; }
      else if(key == "lastDealsCount")     { g_lastDealsCount     = (int)StringToInteger(val); loaded++; }
      else if(key == "profitLockCaptured") { g_profitLockCaptured = (val == "1"); loaded++; }
      else if(key == "lockedProfitUsd")    { g_lockedProfitUsd    = StringToDouble(val); loaded++; }
      else if(key == "profitLockTime")     { g_profitLockTime     = (datetime)StringToInteger(val); loaded++; }
   }
   FileClose(h);

   PrintFormat("[PL.1] restored %d rail state fields from %s", loaded, fn);
   PrintFormat("[PL.1]   peakEq=%.2f basketSL=%d/day=%d pauseUntil=%s baseBal=%.2f",
               g_peakEquityEver, g_basketSLToday, g_basketSLDayKey,
               TimeToString(g_tradePauseUntil), g_dayBaseBalance);
   PrintFormat("[PL.1]   buySer:%s id=%d openEq=%.2f SLfired=%s | sellSer:%s id=%d openEq=%.2f SLfired=%s",
               g_buySeriesActive ? "ACTIVE" : "off", g_buySeriesId, g_buySeriesOpenEquity, g_buySeriesSLFired ? "y" : "n",
               g_sellSeriesActive ? "ACTIVE" : "off", g_sellSeriesId, g_sellSeriesOpenEquity, g_sellSeriesSLFired ? "y" : "n");
}

#endif // __MD_RAILSTATEPERSIST_MQH__
