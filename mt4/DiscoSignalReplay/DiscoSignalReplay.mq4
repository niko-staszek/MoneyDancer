//+------------------------------------------------------------------+
//|                                        DiscoSignalReplay (MT4)    |
//|                                                                    |
//| MT4 port of the MT5 DiscoSignalReplay EA. Reads pre-processed     |
//| Discord signal CSVs from MQL4/Files/disco/ and replays them in    |
//| the MT4 Strategy Tester (or runs live for forward-test).          |
//|                                                                    |
//| Functional parity with MT5 version:                                |
//|  - 3 exit policies: SCALE_OUT, TP1_BE, TP1_ONLY                   |
//|  - Per-signal % equity sizing (compounding)                       |
//|  - Pending-order semantics: wait for entry CROSS, then market open|
//|  - Daily loss guard with auto-close + day lock                    |
//|  - Margin check, concurrency cap, lot cap                         |
//|  - UTC -> server time conversion via ServerTzOffsetHours          |
//|                                                                    |
//| MT4-specific:                                                      |
//|  - Parallel arrays instead of struct array (MT4 quirk-proof)      |
//|  - Direct OrderSend / OrderSelect (no CTrade)                     |
//|  - MarketInfo / AccountBalance / OrdersTotal etc.                 |
//+------------------------------------------------------------------+
#property copyright "Discord/Telegram signal replay EA (MT4)"
#property version   "1.10"
#property strict

// v1.10: CSV format adds `channel` column. Order comment becomes
//        DSC_<channel>_<msgid>_<slice> for per-provider attribution.


//==================== Signal source ====================
input string __sec_src__              = "==== Signal source ====";
input string SignalCsvPath            = "disco/tnfx_processed.csv";   // path under MQL4/Files/
input string SymbolFilter             = "XAUUSD";                       // "" = any

//==================== Strategy ====================
input string __sec_strat__            = "==== Strategy ====";
enum EXIT_POLICY { POLICY_SCALE_OUT = 0, POLICY_TP1_BE = 1, POLICY_TP1_ONLY = 2 };
input EXIT_POLICY ExitPolicy          = POLICY_SCALE_OUT;
input double      RiskPerSignalPct    = 1.0;     // % of equity per signal
input int         LatencyToleranceSec = 3;       // delay before signal eligible
input int         SignalValidityHours = 24;      // expire after this if never filled

//==================== Risk management ====================
input string __sec_risk__             = "==== Risk management ====";
input double DailyMaxLossPct          = 5.0;     // close all + lock on daily DD
input int    MaxConcurrentPositions   = 30;
input double MaxLotCap                = 100.0;
input int    MagicNumber              = 990001;

//==================== Symbol mapping ====================
input string __sec_sym__              = "==== Symbol mapping ====";
input string SymbolSuffix             = "";      // append to signal symbol (e.g. "m")

//==================== Time handling ====================
input string __sec_time__             = "==== Time handling ====";
input int    ServerTzOffsetHours      = 3;       // CSV is UTC; server is UTC+N (Roboforex usually 3)

//==================== Live ingestion ====================
input string __sec_live__             = "==== Live ingestion ====";
input int    CsvReloadIntervalSec     = 0;       // 0 = static (Tester); >0 = re-read CSV every N sec for live signals

//==================== Misc ====================
input string __sec_misc__             = "==== Misc ====";
input bool   DebugMode                = false;   // log fills, do NOT trade
input bool   VerboseLog               = false;
input int    Slippage                 = 100;     // OrderSend slippage in points


//==================== Globals (parallel signal arrays) ====================
#define MAX_TPS 15
#define POS_UNINIT  9

int      g_sig_id[];
datetime g_sig_time[];           // server-time (already offset-adjusted)
string   g_sig_channel[];        // short alpha alias used in order comment (e.g. "APL")
string   g_sig_symbol[];
int      g_sig_side[];           // +1 BUY, -1 SELL
double   g_sig_entry[];
double   g_sig_sl[];
int      g_sig_n_tps[];
double   g_sig_tps[][MAX_TPS];   // 2D: [signal_idx][tp_idx]
bool     g_sig_processed[];
bool     g_sig_filled[];
bool     g_sig_expired[];
int      g_sig_init_pos[];       // -1/+1/0/POS_UNINIT

int      g_n_signals  = 0;

string   g_tradeSymbol = "";
double   g_dailyStartBalance = 0;
bool     g_dailyLocked = false;
datetime g_lastDayChecked = 0;
int      g_filledCount  = 0;
int      g_expiredCount = 0;


//+------------------------------------------------------------------+
//| OnInit                                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   g_tradeSymbol = (SymbolFilter == "") ? Symbol() : SymbolFilter + SymbolSuffix;
   g_dailyStartBalance = AccountBalance();

   // Make sure symbol is available in Market Watch
   double check = MarketInfo(g_tradeSymbol, MODE_BID);
   if(check <= 0)
   {
      PrintFormat("ERROR: symbol %s not available on this account (MarketInfo returned %.5f)",
                  g_tradeSymbol, check);
      return INIT_PARAMETERS_INCORRECT;
   }

   if(!LoadSignalsFromCsv(SignalCsvPath))
   {
      // For live mode the CSV may not exist yet (poller hasn't run). Allow empty.
      if(CsvReloadIntervalSec <= 0)
      {
         PrintFormat("ERROR: failed to load signals from MQL4/Files/%s", SignalCsvPath);
         return INIT_FAILED;
      }
      PrintFormat("WARN: no signals at startup (live mode); will retry on timer");
   }

   if(CsvReloadIntervalSec > 0)
      EventSetTimer(CsvReloadIntervalSec);

   PrintFormat("DiscoSignalReplay MT4 v1.10 ready. %d signals loaded, symbol=%s, policy=%s, risk/sig=%.2f%%, daily_max_loss=%.1f%%, reload=%ds, debug=%s",
               g_n_signals, g_tradeSymbol, PolicyName(ExitPolicy),
               RiskPerSignalPct, DailyMaxLossPct, CsvReloadIntervalSec, (DebugMode ? "ON" : "OFF"));
   ReportChannelCounts();
   return INIT_SUCCEEDED;
}


//+------------------------------------------------------------------+
//| Print a per-channel signal-count summary                          |
//+------------------------------------------------------------------+
void ReportChannelCounts()
{
   if(g_n_signals == 0) return;
   // Unique channels and counts (small data; O(n^2) is fine)
   string seen = "";
   for(int i = 0; i < g_n_signals; i++)
   {
      string ch = g_sig_channel[i];
      if(StringFind(seen, "|" + ch + "|") >= 0) continue;
      seen += "|" + ch + "|";
      int cnt = 0;
      for(int j = 0; j < g_n_signals; j++)
         if(g_sig_channel[j] == ch) cnt++;
      PrintFormat("  channel %s : %d signal(s)", ch, cnt);
   }
}


//+------------------------------------------------------------------+
//| OnTimer                                                            |
//+------------------------------------------------------------------+
void OnTimer()
{
   int added = ReloadCsvForNewSignals();
   if(added > 0)
      PrintFormat("[reload] +%d new signal(s) from CSV (now total: %d)", added, g_n_signals);
}


//+------------------------------------------------------------------+
//| OnTick                                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   UpdateDailyGuard();
   if(g_dailyLocked) return;

   ProcessDueSignals();

   if(ExitPolicy == POLICY_TP1_BE)
      ManageBreakEvenCascade();
}


//+------------------------------------------------------------------+
//| OnDeinit                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(CsvReloadIntervalSec > 0) EventKillTimer();
   PrintFormat("DiscoSignalReplay deinit. Reason=%d. %d signals total: %d filled, %d expired, %d unfilled.",
               reason, g_n_signals, g_filledCount, g_expiredCount,
               g_n_signals - g_filledCount - g_expiredCount);
}


//+------------------------------------------------------------------+
//| Re-read CSV, append only msg_ids not already in g_sig_id[].       |
//| Returns count added.                                               |
//+------------------------------------------------------------------+
int ReloadCsvForNewSignals()
{
   int h = FileOpen(SignalCsvPath, FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ | FILE_SHARE_WRITE, ',');
   if(h == INVALID_HANDLE) return 0;
   for(int i = 0; i < 9; i++) FileReadString(h);  // skip header (9 cols)

   int added = 0;
   while(!FileIsEnding(h))
   {
      int    f_id   = (int)StringToInteger(FileReadString(h));
      string f_time = FileReadString(h);
      string f_ch   = FileReadString(h);
      string f_sym  = FileReadString(h);
      string f_side = FileReadString(h);
      double f_ent  = StringToDouble(FileReadString(h));
      double f_sl   = StringToDouble(FileReadString(h));
      int    f_ntps = (int)StringToInteger(FileReadString(h));
      string f_tps  = FileReadString(h);

      if(SymbolFilter != "" && f_sym != SymbolFilter) continue;
      if(IsKnownMsgId(f_id)) continue;

      string parts[];
      int nParts = StringSplit(f_tps, '|', parts);
      int actual = MathMin(nParts, MAX_TPS);

      int newSize = g_n_signals + 1;
      ArrayResize(g_sig_id,        newSize);
      ArrayResize(g_sig_time,      newSize);
      ArrayResize(g_sig_channel,   newSize);
      ArrayResize(g_sig_symbol,    newSize);
      ArrayResize(g_sig_side,      newSize);
      ArrayResize(g_sig_entry,     newSize);
      ArrayResize(g_sig_sl,        newSize);
      ArrayResize(g_sig_n_tps,     newSize);
      ArrayResize(g_sig_tps,       newSize);
      ArrayResize(g_sig_processed, newSize);
      ArrayResize(g_sig_filled,    newSize);
      ArrayResize(g_sig_expired,   newSize);
      ArrayResize(g_sig_init_pos,  newSize);

      g_sig_id[g_n_signals]        = f_id;
      g_sig_time[g_n_signals]      = StringToTime(f_time) + ServerTzOffsetHours * 3600;
      g_sig_channel[g_n_signals]   = (StringLen(f_ch) > 0 ? f_ch : "DISCO");
      g_sig_symbol[g_n_signals]    = f_sym;
      g_sig_side[g_n_signals]      = (f_side == "BUY") ? +1 : -1;
      g_sig_entry[g_n_signals]     = f_ent;
      g_sig_sl[g_n_signals]        = f_sl;
      g_sig_n_tps[g_n_signals]     = MathMin(f_ntps, actual);
      for(int k = 0; k < MAX_TPS; k++) g_sig_tps[g_n_signals][k] = 0.0;
      for(int k = 0; k < actual; k++) g_sig_tps[g_n_signals][k] = StringToDouble(parts[k]);
      g_sig_processed[g_n_signals] = false;
      g_sig_filled[g_n_signals]    = false;
      g_sig_expired[g_n_signals]   = false;
      g_sig_init_pos[g_n_signals]  = POS_UNINIT;

      g_n_signals++;
      added++;
   }
   FileClose(h);
   return added;
}


bool IsKnownMsgId(int id)
{
   for(int i = 0; i < g_n_signals; i++)
      if(g_sig_id[i] == id) return true;
   return false;
}


//+------------------------------------------------------------------+
//| CSV loading                                                        |
//+------------------------------------------------------------------+
bool LoadSignalsFromCsv(string path)
{
   int h = FileOpen(path, FILE_READ | FILE_CSV | FILE_ANSI, ',');
   if(h == INVALID_HANDLE)
   {
      PrintFormat("FileOpen failed for %s, error=%d", path, GetLastError());
      return false;
   }

   // Skip header (9 fields): id,time_mt5,channel,symbol,side,entry,sl,n_tps,tps
   for(int i = 0; i < 9; i++) FileReadString(h);

   while(!FileIsEnding(h))
   {
      int    f_id   = (int)StringToInteger(FileReadString(h));
      string f_time = FileReadString(h);
      string f_ch   = FileReadString(h);
      string f_sym  = FileReadString(h);
      string f_side = FileReadString(h);
      double f_ent  = StringToDouble(FileReadString(h));
      double f_sl   = StringToDouble(FileReadString(h));
      int    f_ntps = (int)StringToInteger(FileReadString(h));
      string f_tps  = FileReadString(h);

      if(SymbolFilter != "" && f_sym != SymbolFilter) continue;

      // Parse TPs from pipe-separated string
      string parts[];
      int nParts = StringSplit(f_tps, '|', parts);
      int actual = MathMin(nParts, MAX_TPS);

      // Grow all parallel arrays in lockstep
      int newSize = g_n_signals + 1;
      ArrayResize(g_sig_id,        newSize);
      ArrayResize(g_sig_time,      newSize);
      ArrayResize(g_sig_channel,   newSize);
      ArrayResize(g_sig_symbol,    newSize);
      ArrayResize(g_sig_side,      newSize);
      ArrayResize(g_sig_entry,     newSize);
      ArrayResize(g_sig_sl,        newSize);
      ArrayResize(g_sig_n_tps,     newSize);
      ArrayResize(g_sig_tps,       newSize);
      ArrayResize(g_sig_processed, newSize);
      ArrayResize(g_sig_filled,    newSize);
      ArrayResize(g_sig_expired,   newSize);
      ArrayResize(g_sig_init_pos,  newSize);

      g_sig_id[g_n_signals]        = f_id;
      // CSV is UTC; convert to server time
      g_sig_time[g_n_signals]      = StringToTime(f_time) + ServerTzOffsetHours * 3600;
      g_sig_channel[g_n_signals]   = (StringLen(f_ch) > 0 ? f_ch : "DISCO");
      g_sig_symbol[g_n_signals]    = f_sym;
      g_sig_side[g_n_signals]      = (f_side == "BUY") ? +1 : -1;
      g_sig_entry[g_n_signals]     = f_ent;
      g_sig_sl[g_n_signals]        = f_sl;
      g_sig_n_tps[g_n_signals]     = MathMin(f_ntps, actual);

      for(int k = 0; k < MAX_TPS; k++) g_sig_tps[g_n_signals][k] = 0.0;
      for(int k = 0; k < actual; k++) g_sig_tps[g_n_signals][k] = StringToDouble(parts[k]);

      g_sig_processed[g_n_signals] = false;
      g_sig_filled[g_n_signals]    = false;
      g_sig_expired[g_n_signals]   = false;
      g_sig_init_pos[g_n_signals]  = POS_UNINIT;

      g_n_signals++;
   }
   FileClose(h);

   if(VerboseLog && g_n_signals > 0)
   {
      PrintFormat("First signal: id=%d t=%s %s entry=%.2f sl=%.2f n_tps=%d",
                  g_sig_id[0], TimeToString(g_sig_time[0]),
                  (g_sig_side[0] > 0 ? "BUY" : "SELL"),
                  g_sig_entry[0], g_sig_sl[0], g_sig_n_tps[0]);
      int last = g_n_signals - 1;
      PrintFormat("Last signal:  id=%d t=%s %s entry=%.2f sl=%.2f n_tps=%d",
                  g_sig_id[last], TimeToString(g_sig_time[last]),
                  (g_sig_side[last] > 0 ? "BUY" : "SELL"),
                  g_sig_entry[last], g_sig_sl[last], g_sig_n_tps[last]);
   }
   return g_n_signals > 0;
}


//+------------------------------------------------------------------+
//| Signal processing                                                  |
//+------------------------------------------------------------------+
void ProcessDueSignals()
{
   datetime now = TimeCurrent();
   double ask = MarketInfo(g_tradeSymbol, MODE_ASK);
   double bid = MarketInfo(g_tradeSymbol, MODE_BID);
   if(ask <= 0 || bid <= 0) return;

   for(int i = 0; i < g_n_signals; i++)
   {
      if(g_sig_processed[i]) continue;
      if(now < g_sig_time[i] + LatencyToleranceSec) continue;

      // Expiry
      if(now > g_sig_time[i] + SignalValidityHours * 3600)
      {
         g_sig_processed[i] = true;
         g_sig_expired[i]   = true;
         g_expiredCount++;
         if(VerboseLog) PrintFormat("Signal %d EXPIRED (validity %dh elapsed)", g_sig_id[i], SignalValidityHours);
         continue;
      }

      double refPrice = (g_sig_side[i] > 0) ? ask : bid;

      // Capture initial position on first eligible tick
      if(g_sig_init_pos[i] == POS_UNINIT)
      {
         double diff = refPrice - g_sig_entry[i];
         double pt = MarketInfo(g_tradeSymbol, MODE_POINT);
         double eps = pt * 5;
         if(diff > eps)       g_sig_init_pos[i] = +1;
         else if(diff < -eps) g_sig_init_pos[i] = -1;
         else                 g_sig_init_pos[i] = 0;

         if(VerboseLog)
            PrintFormat("Signal %d eligible. refPrice=%.2f entry=%.2f init_pos=%d",
                        g_sig_id[i], refPrice, g_sig_entry[i], g_sig_init_pos[i]);

         if(g_sig_init_pos[i] == 0)
            TryPlaceOrders(i, refPrice);
         continue;
      }

      // Cross detection
      bool crossed = false;
      if(g_sig_init_pos[i] > 0 && refPrice <= g_sig_entry[i]) crossed = true;
      if(g_sig_init_pos[i] < 0 && refPrice >= g_sig_entry[i]) crossed = true;
      if(!crossed) continue;

      TryPlaceOrders(i, refPrice);
   }
}


void TryPlaceOrders(int idx, double refPrice)
{
   if(CountOurPositions() >= MaxConcurrentPositions)
   {
      if(VerboseLog) PrintFormat("Signal %d skipped: MaxConcurrentPositions reached", g_sig_id[idx]);
      return;
   }

   double entry   = g_sig_entry[idx];
   double sl      = g_sig_sl[idx];
   int    side    = g_sig_side[idx];
   int    n_tps   = g_sig_n_tps[idx];
   int    sigId   = g_sig_id[idx];

   double slDist = MathAbs(entry - sl);
   if(slDist <= 0)
   {
      PrintFormat("Signal %d: invalid SL distance, skipping", sigId);
      g_sig_processed[idx] = true;
      return;
   }

   int nSlices;
   if(ExitPolicy == POLICY_SCALE_OUT)      nSlices = n_tps;
   else if(ExitPolicy == POLICY_TP1_BE)    nSlices = 2;
   else                                     nSlices = 1;
   if(nSlices < 1) nSlices = 1;

   double totalLot = CalculateLotSize(slDist);
   if(totalLot <= 0)
   {
      PrintFormat("Signal %d: lot calc returned 0, skipping", sigId);
      g_sig_processed[idx] = true;
      return;
   }
   double sliceLot = NormalizeLot(totalLot / nSlices);
   double minLot = MarketInfo(g_tradeSymbol, MODE_MINLOT);
   if(sliceLot < minLot)
   {
      while(sliceLot < minLot && nSlices > 1)
      {
         nSlices--;
         sliceLot = NormalizeLot(totalLot / nSlices);
      }
      if(sliceLot < minLot)
      {
         PrintFormat("Signal %d: total lot %.3f too small for any slice (minLot=%.3f), skipping",
                     sigId, totalLot, minLot);
         g_sig_processed[idx] = true;
         return;
      }
   }

   PrintFormat("Signal %d FILL: %s %s ref=%.2f entry=%.2f sl=%.2f n_tps=%d policy=%s totalLot=%.2f sliceLot=%.2f nSlices=%d",
               sigId, g_tradeSymbol, (side > 0 ? "BUY" : "SELL"),
               refPrice, entry, sl, n_tps, PolicyName(ExitPolicy),
               totalLot, sliceLot, nSlices);

   if(DebugMode)
   {
      g_sig_processed[idx] = true;
      g_sig_filled[idx]    = true;
      g_filledCount++;
      return;
   }

   int placed = 0;
   string ch = g_sig_channel[idx];
   for(int k = 0; k < nSlices; k++)
   {
      double tp = SelectTpForSlice(idx, k, nSlices);
      // Format: DSC_<channel>_<msgid>_<slice>  e.g. DSC_TNFX_42_1
      string comment = StringFormat("DSC_%s_%d_%d", ch, sigId, k + 1);
      int ticket = -1;

      RefreshRates();
      if(side > 0)
      {
         double openPrice = MarketInfo(g_tradeSymbol, MODE_ASK);
         ticket = OrderSend(g_tradeSymbol, OP_BUY, sliceLot, openPrice,
                            Slippage, sl, tp, comment, MagicNumber, 0, clrGreen);
      }
      else
      {
         double openPrice = MarketInfo(g_tradeSymbol, MODE_BID);
         ticket = OrderSend(g_tradeSymbol, OP_SELL, sliceLot, openPrice,
                            Slippage, sl, tp, comment, MagicNumber, 0, clrRed);
      }

      if(ticket > 0) placed++;
      else PrintFormat("Signal %d slice %d OrderSend FAILED. err=%d",
                       sigId, k + 1, GetLastError());
   }

   g_sig_processed[idx] = true;
   g_sig_filled[idx]    = (placed > 0);
   if(placed > 0) g_filledCount++;
}


double SelectTpForSlice(int idx, int sliceIdx, int totalSlices)
{
   int n_tps = g_sig_n_tps[idx];
   if(ExitPolicy == POLICY_SCALE_OUT)
   {
      int k = MathMin(sliceIdx, n_tps - 1);
      return g_sig_tps[idx][k];
   }
   if(ExitPolicy == POLICY_TP1_BE)
   {
      if(sliceIdx == 0) return g_sig_tps[idx][0];
      return g_sig_tps[idx][n_tps - 1];
   }
   return g_sig_tps[idx][0];
}


//+------------------------------------------------------------------+
//| Break-even cascade for TP1_BE                                     |
//+------------------------------------------------------------------+
void ManageBreakEvenCascade()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderMagicNumber() != MagicNumber) continue;
      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL) continue;

      string comment = OrderComment();
      string parts[];
      // New format: DSC_<channel>_<msgid>_<slice>  -> 4 parts
      if(StringSplit(comment, '_', parts) != 4) continue;
      if(parts[0] != "DSC") continue;
      string ch    = parts[1];
      int sigId    = (int)StringToInteger(parts[2]);
      int slice    = (int)StringToInteger(parts[3]);
      if(slice == 1) continue;  // slice 1 has its own TP

      if(IsSlice1ClosedForSignal(ch, sigId))
      {
         double openPrice = OrderOpenPrice();
         double currentSL = OrderStopLoss();
         double currentTP = OrderTakeProfit();
         bool shouldMove;
         if(type == OP_BUY)  shouldMove = (currentSL < openPrice);
         else                shouldMove = (currentSL > openPrice || currentSL == 0);
         if(shouldMove)
         {
            double newSL = openPrice;
            int ticket = OrderTicket();
            if(OrderModify(ticket, openPrice, newSL, currentTP, 0, clrYellow))
               PrintFormat("BE move: ticket %d sigId=%d slice=%d SL %.2f -> %.2f",
                           ticket, sigId, slice, currentSL, newSL);
            else
               PrintFormat("BE move FAILED: ticket %d err=%d", ticket, GetLastError());
         }
      }
   }
}


bool IsSlice1ClosedForSignal(string ch, int sigId)
{
   string target = StringFormat("DSC_%s_%d_1", ch, sigId);
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderMagicNumber() != MagicNumber) continue;
      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL) continue;
      if(OrderComment() == target) return false;
   }
   return true;
}


//+------------------------------------------------------------------+
//| Sizing                                                             |
//+------------------------------------------------------------------+
double CalculateLotSize(double slDistance)
{
   double equity = AccountEquity();
   double riskUsd = equity * RiskPerSignalPct / 100.0;

   double tickValue = MarketInfo(g_tradeSymbol, MODE_TICKVALUE);
   double tickSize  = MarketInfo(g_tradeSymbol, MODE_TICKSIZE);
   if(tickValue <= 0 || tickSize <= 0)
   {
      PrintFormat("ERROR: tick value/size invalid for %s (tv=%.5f ts=%.5f)",
                  g_tradeSymbol, tickValue, tickSize);
      return 0;
   }
   double lossPerLot = slDistance / tickSize * tickValue;
   if(lossPerLot <= 0) return 0;

   double lots = riskUsd / lossPerLot;
   if(lots > MaxLotCap) lots = MaxLotCap;
   lots = NormalizeLot(lots);

   // Margin sanity check: MarketInfo MODE_MARGINREQUIRED is per 1.0 lot for buy
   double marginPerLot = MarketInfo(g_tradeSymbol, MODE_MARGINREQUIRED);
   if(marginPerLot > 0)
   {
      double freeMargin = AccountFreeMargin();
      if(marginPerLot * lots > freeMargin * 0.5)
      {
         PrintFormat("WARN: margin %.0f > 50%% of free %.0f for lot=%.2f, shrinking",
                     marginPerLot * lots, freeMargin, lots);
         lots = NormalizeLot(MathMax(MarketInfo(g_tradeSymbol, MODE_MINLOT), lots * 0.5));
      }
   }
   return lots;
}


double NormalizeLot(double lots)
{
   double step = MarketInfo(g_tradeSymbol, MODE_LOTSTEP);
   double minL = MarketInfo(g_tradeSymbol, MODE_MINLOT);
   double maxL = MarketInfo(g_tradeSymbol, MODE_MAXLOT);
   if(step <= 0) step = 0.01;
   lots = MathFloor(lots / step) * step;
   if(lots < minL) lots = minL;
   if(lots > maxL) lots = maxL;
   return NormalizeDouble(lots, 2);
}


//+------------------------------------------------------------------+
//| Daily loss guard                                                   |
//+------------------------------------------------------------------+
void UpdateDailyGuard()
{
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   datetime today = now - (dt.hour * 3600 + dt.min * 60 + dt.sec);
   if(today != g_lastDayChecked)
   {
      g_lastDayChecked = today;
      g_dailyStartBalance = AccountBalance();
      if(g_dailyLocked)
         PrintFormat("New day. Unlocking. start balance=%.2f", g_dailyStartBalance);
      g_dailyLocked = false;
   }
   if(g_dailyLocked) return;

   double equity = AccountEquity();
   double dd = (g_dailyStartBalance - equity) / g_dailyStartBalance * 100.0;
   if(dd >= DailyMaxLossPct)
   {
      PrintFormat("DAILY LOSS LIMIT HIT: DD=%.2f%% >= %.2f%%. Closing all and locking for day.",
                  dd, DailyMaxLossPct);
      CloseAllOurPositions();
      g_dailyLocked = true;
   }
}


//+------------------------------------------------------------------+
//| Helpers                                                            |
//+------------------------------------------------------------------+
int CountOurPositions()
{
   int n = 0;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderMagicNumber() != MagicNumber) continue;
      int type = OrderType();
      if(type == OP_BUY || type == OP_SELL) n++;
   }
   return n;
}


void CloseAllOurPositions()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderMagicNumber() != MagicNumber) continue;
      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL) continue;

      RefreshRates();
      double closePrice = (type == OP_BUY) ?
                          MarketInfo(g_tradeSymbol, MODE_BID) :
                          MarketInfo(g_tradeSymbol, MODE_ASK);
      int ticket = OrderTicket();
      double lots = OrderLots();
      if(!OrderClose(ticket, lots, closePrice, Slippage, clrViolet))
         PrintFormat("CloseAll: OrderClose %d FAILED, err=%d", ticket, GetLastError());
   }
}


string PolicyName(EXIT_POLICY p)
{
   if(p == POLICY_SCALE_OUT) return "SCALE_OUT";
   if(p == POLICY_TP1_BE)    return "TP1_BE";
   if(p == POLICY_TP1_ONLY)  return "TP1_ONLY";
   return "UNKNOWN";
}
//+------------------------------------------------------------------+
