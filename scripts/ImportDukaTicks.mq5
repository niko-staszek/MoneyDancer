//+------------------------------------------------------------------+
//| ImportDukaTicks.mq5                                              |
//| Imports a Dukascopy-derived tick CSV into a custom MT5 symbol.   |
//|                                                                  |
//| Usage:                                                           |
//|   1. Drop this script in MQL5/Scripts/.                          |
//|   2. Compile in MetaEditor (F7).                                 |
//|   3. Drag onto any chart in the running terminal.                |
//|   4. CSV must live at <MQL5/Files/>/<TickCsvPath>.               |
//|                                                                  |
//| CSV columns: utc_datetime,bid,ask,bid_vol,ask_vol                |
//| utc_datetime format: YYYY-MM-DD HH:MM:SS.fff                     |
//+------------------------------------------------------------------+

#property script_show_inputs

input string  CustomName     = "XAUUSD.duk";
input string  CustomPath     = "Custom\\Dukascopy";
input string  CustomDescr    = "XAU/USD (Dukascopy historical, imported)";
input string  TickCsvPath    = "duka\\XAUUSD_2026_jan-may.csv";   // relative to MQL5/Files/
input int     SymbolDigits   = 2;        // RoboForex-Pro uses 2 digits for gold
input double  PointSize      = 0.01;     // 10 ^ -digits
input double  ContractSize   = 100.0;
input double  TickValue      = 1.0;
input double  TickSize       = 0.01;
input long    BaseSpreadPts  = 30;       // typical broker spread fallback
input bool    DeleteFirst    = true;     // delete the custom symbol before re-creating

//+------------------------------------------------------------------+
//| Parse "YYYY-MM-DD HH:MM:SS.fff" into (datetime, ms)              |
//+------------------------------------------------------------------+
bool ParseTs(const string s, datetime &dt_out, int &ms_out)
{
   // expected: 2026-01-29 19:00:00.123
   if(StringLen(s) < 19) return(false);
   string ymd = StringSubstr(s, 0, 10);
   string hms = StringSubstr(s, 11, 8);
   ms_out = 0;
   if(StringLen(s) > 20)
   {
      string mstr = StringSubstr(s, 20);
      ms_out = (int)StringToInteger(mstr);
   }
   string full = ymd + " " + hms;
   dt_out = StringToTime(full);
   if(dt_out == 0) return(false);
   return(true);
}

//+------------------------------------------------------------------+
//| Apply common gold-symbol properties to the custom symbol         |
//+------------------------------------------------------------------+
void ConfigureSymbol(const string sym)
{
   CustomSymbolSetInteger(sym, SYMBOL_DIGITS, SymbolDigits);
   CustomSymbolSetDouble (sym, SYMBOL_POINT, PointSize);
   CustomSymbolSetDouble (sym, SYMBOL_TRADE_TICK_SIZE,  TickSize);
   CustomSymbolSetDouble (sym, SYMBOL_TRADE_TICK_VALUE, TickValue);
   CustomSymbolSetDouble (sym, SYMBOL_TRADE_CONTRACT_SIZE, ContractSize);
   CustomSymbolSetInteger(sym, SYMBOL_TRADE_CALC_MODE,  SYMBOL_CALC_MODE_FOREX);
   CustomSymbolSetInteger(sym, SYMBOL_TRADE_MODE,       SYMBOL_TRADE_MODE_FULL);
   CustomSymbolSetInteger(sym, SYMBOL_TRADE_EXEMODE,    SYMBOL_TRADE_EXECUTION_MARKET);
   CustomSymbolSetDouble (sym, SYMBOL_VOLUME_MIN,       0.01);
   CustomSymbolSetDouble (sym, SYMBOL_VOLUME_MAX,       100.0);
   CustomSymbolSetDouble (sym, SYMBOL_VOLUME_STEP,      0.01);
   CustomSymbolSetInteger(sym, SYMBOL_SPREAD,           BaseSpreadPts);
   CustomSymbolSetString (sym, SYMBOL_DESCRIPTION,      CustomDescr);
   CustomSymbolSetString (sym, SYMBOL_CURRENCY_BASE,    "XAU");
   CustomSymbolSetString (sym, SYMBOL_CURRENCY_PROFIT,  "USD");
   CustomSymbolSetString (sym, SYMBOL_CURRENCY_MARGIN,  "USD");
}

//+------------------------------------------------------------------+
//| Script entry                                                     |
//+------------------------------------------------------------------+
void OnStart()
{
   PrintFormat("ImportDukaTicks: starting; csv=%s", TickCsvPath);

   // --- Re-create the symbol ----------------------------------------------
   if(DeleteFirst && SymbolSelect(CustomName, false))
      CustomSymbolDelete(CustomName);
   if(!CustomSymbolCreate(CustomName, CustomPath, "XAUUSD"))
   {
      // Fallback: create without cloning a base symbol
      if(!CustomSymbolCreate(CustomName, CustomPath))
      {
         PrintFormat("CustomSymbolCreate(%s) failed: %d", CustomName, GetLastError());
         return;
      }
   }
   ConfigureSymbol(CustomName);
   SymbolSelect(CustomName, true);

   // --- Open the CSV (relative to MQL5/Files/) ----------------------------
   int handle = FileOpen(TickCsvPath, FILE_READ | FILE_ANSI | FILE_TXT);
   if(handle == INVALID_HANDLE)
   {
      PrintFormat("FileOpen(%s) failed: %d", TickCsvPath, GetLastError());
      return;
   }
   string header = FileReadString(handle);
   PrintFormat("CSV header: %s", header);

   MqlTick   batch[];
   ArrayResize(batch, 50000);
   int batchIdx = 0;
   long totalTicks = 0;
   datetime firstTime = 0, lastTime = 0;

   while(!FileIsEnding(handle))
   {
      string line = FileReadString(handle);
      if(StringLen(line) < 10) continue;
      string parts[];
      int n = StringSplit(line, ',', parts);
      if(n < 3) continue;

      datetime ts;
      int ms;
      if(!ParseTs(parts[0], ts, ms)) continue;
      double bid = StringToDouble(parts[1]);
      double ask = StringToDouble(parts[2]);
      double bidVol = (n > 3) ? StringToDouble(parts[3]) : 0.0;
      double askVol = (n > 4) ? StringToDouble(parts[4]) : 0.0;

      MqlTick t;
      t.time       = ts;
      t.bid        = bid;
      t.ask        = ask;
      t.last       = bid;     // gold has no last; use bid
      t.volume     = (ulong)MathRound(bidVol + askVol);
      t.time_msc   = (long)ts * 1000 + ms;
      t.flags      = TICK_FLAG_BID | TICK_FLAG_ASK;
      t.volume_real= bidVol + askVol;
      batch[batchIdx++] = t;
      if(firstTime == 0) firstTime = ts;
      lastTime = ts;

      if(batchIdx >= 50000)
      {
         long n_added = CustomTicksReplace(CustomName,
                                           batch[0].time_msc,
                                           batch[batchIdx-1].time_msc,
                                           batch);
         if(n_added < 0)
            PrintFormat("CustomTicksReplace failed at %s: %d",
                        TimeToString(batch[0].time, TIME_DATE|TIME_SECONDS),
                        GetLastError());
         else
            totalTicks += n_added;
         batchIdx = 0;
      }
   }
   // Flush the remainder
   if(batchIdx > 0)
   {
      MqlTick tail[];
      ArrayResize(tail, batchIdx);
      ArrayCopy(tail, batch, 0, 0, batchIdx);
      long n_added = CustomTicksReplace(CustomName,
                                        tail[0].time_msc,
                                        tail[batchIdx-1].time_msc,
                                        tail);
      if(n_added < 0)
         PrintFormat("CustomTicksReplace tail failed: %d", GetLastError());
      else
         totalTicks += n_added;
   }

   FileClose(handle);
   PrintFormat("ImportDukaTicks: imported %d ticks, %s -> %s",
               (int)totalTicks,
               TimeToString(firstTime, TIME_DATE|TIME_SECONDS),
               TimeToString(lastTime,  TIME_DATE|TIME_SECONDS));
}
//+------------------------------------------------------------------+
