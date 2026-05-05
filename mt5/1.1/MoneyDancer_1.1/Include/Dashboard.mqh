//+------------------------------------------------------------------+
//| Dashboard.mqh — UI layer (A7b full port)                         |
//|                                                                   |
//| Port of MT4 legacy dashboard: Wall Street panel + trade markers  |
//| + bottom M15 PnL strip + control buttons + AI-sim status. All    |
//| visual — strategy has zero functional dependency on anything     |
//| here.                                                             |
//|                                                                   |
//| MT4→MT5 semantic adaptations applied inline:                      |
//|   * ObjectCreate/ObjectSet already MT5-style in MT4 source (chart|
//|     id passed as first arg) — no translation needed for draws.   |
//|   * Open-position iteration: OrdersTotal+OrderSelect(MODE_TRADES)|
//|     → PositionsTotal+PositionGetTicket+PositionSelectByTicket.    |
//|   * History iteration: OrdersHistoryTotal+OrderSelect(MODE_HISTORY|
//|     → HistorySelect(from,to) + HistoryDealsTotal +                |
//|     HistoryDealGetTicket/HistoryDealGet*. We only process         |
//|     DEAL_ENTRY_OUT deals (closes), matching the MT4 "closed      |
//|     trade" semantic.                                              |
//|   * OP_BUY/OP_SELL → POSITION_TYPE_BUY/SELL (open) or direction   |
//|     sign derived from DEAL_TYPE for closed deals.                 |
//|   * Bid/Ask → SymbolInfoDouble(_Symbol, SYMBOL_BID/ASK).          |
//|   * Point → _Point. AccountEquity() → AccountInfoDouble(...).    |
//|   * OrderClose() → CTrade::PositionClose(ticket) via g_dashTrade. |
//+------------------------------------------------------------------+
#ifndef __MD_DASHBOARD_MQH__
#define __MD_DASHBOARD_MQH__

// Dedicated CTrade instance for dashboard-initiated closes (button handlers).
// Separate from Orders.mqh's trade object so dashboard activity doesn't
// interleave with the strategy's order-retry bookkeeping mid-call.
CTrade g_dashTrade;

//+------------------------------------------------------------------+
//| Init / deinit                                                     |
//+------------------------------------------------------------------+
void Dashboard_Init()
{
   g_dashTrade.SetExpertMagicNumber(Magic);
   g_dashTrade.SetDeviationInPoints(Slippage);

   g_peakEquityEver  = AccountInfoDouble(ACCOUNT_EQUITY);
   g_peakEquityToday = AccountInfoDouble(ACCOUNT_EQUITY);

   for(int i = 0; i < 5; i++) g_aiMessages[i] = "Initializing...";
   ArrayInitialize(g_m15Pnl, 0.0);
   ArrayInitialize(g_tickSizes, 0.0);
}

//+------------------------------------------------------------------+
//| DRAWING PRIMITIVES                                                |
//| Thin wrappers over ObjectCreate + ObjectSetInteger/String so      |
//| higher-level panels stay readable.                                |
//+------------------------------------------------------------------+
void DrawPanel(string name, int x, int y, int w, int h, color bgClr, color borderClr)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgClr);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, borderClr);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

void DrawLabel(string name, int x, int y, string text, color clr, int fontSize, string font)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, font);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

void CreateButton(string name, int x, int y, int w, int h, string text, color txtClr, color bgClr)
{
   bool justCreated = false;
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
      justCreated = true;
   }

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, txtClr);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgClr);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrDimGray);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);

   // Only initialise OBJPROP_STATE on first creation. DrawProDashboard calls
   // CreateButton on every redraw; re-setting STATE to 0 here would zero out
   // a click made between the redraw and CheckButtonClicks' poll.
   if(justCreated) ObjectSetInteger(0, name, OBJPROP_STATE, 0);
}

void CreateBottomLabel(string name, int x, int y, int w, int h, string text, color txtClr, color bgClr)
{
   // Background rectangle
   string bgName = name + "_bg";
   if(ObjectFind(0, bgName) < 0)
      ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, bgClr);
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_COLOR, clrDimGray);
   ObjectSetInteger(0, bgName, OBJPROP_BACK, false);
   ObjectSetInteger(0, bgName, OBJPROP_HIDDEN, true);

   // Text label
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x + 5);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y - 3);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, txtClr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void DeleteObject(string name)
{
   if(ObjectFind(0, name) >= 0)             ObjectDelete(0, name);
   if(ObjectFind(0, name + "_bg") >= 0)     ObjectDelete(0, name + "_bg");
}

void DrawSmallArrow(string name, datetime t, double price, int arrowCode, color clr, int width)
{
   if(ObjectFind(0, name) >= 0) return;
   ObjectCreate(0, name, OBJ_ARROW, 0, t, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrowCode);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

void DrawProfitLabel(string name, datetime t, double price, string text, color clr, int fsize, int anchor)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TEXT, 0, t, price);

   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fsize);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

void DrawTradeLine(string name, datetime t1, double p1, datetime t2, double p2, color clr, int style)
{
   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| AVG TICK SIZE TRACKING                                            |
//+------------------------------------------------------------------+
void UpdateTickSize()
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(g_lastPrice > 0)
   {
      double tickSize = MathAbs(currentPrice - g_lastPrice) / _Point;
      if(tickSize > 0)
      {
         g_tickSizes[g_tickSizeHead] = tickSize;
         g_tickSizeHead = (g_tickSizeHead + 1) % MAX_TICK_SIZES;
         if(g_tickSizeCount < MAX_TICK_SIZES) g_tickSizeCount++;
      }
   }
   g_lastPrice = currentPrice;
}

double GetAvgTickSize()
{
   if(g_tickSizeCount == 0) return 0;
   double sum = 0;
   for(int i = 0; i < g_tickSizeCount; i++)
      sum += g_tickSizes[i];
   return sum / g_tickSizeCount;
}

//+------------------------------------------------------------------+
//| MAX DRAWDOWN TRACKING                                             |
//+------------------------------------------------------------------+
void UpdateMaxDD()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   int dayKey = DayKey(TimeCurrent());

   // Reset daily tracking if new day
   if(dayKey != g_ddDayKey)
   {
      g_ddDayKey = dayKey;
      g_peakEquityToday = equity;
      g_maxDDToday = 0;
   }

   // Update peak equity
   if(equity > g_peakEquityToday) g_peakEquityToday = equity;
   if(equity > g_peakEquityEver)  g_peakEquityEver  = equity;

   // Calculate current DD
   if(g_peakEquityToday > 0)
   {
      double ddToday = (g_peakEquityToday - equity) / g_peakEquityToday * 100.0;
      if(ddToday > g_maxDDToday) g_maxDDToday = ddToday;
   }

   if(g_peakEquityEver > 0)
   {
      double ddEver = (g_peakEquityEver - equity) / g_peakEquityEver * 100.0;
      if(ddEver > g_maxDDEver) g_maxDDEver = ddEver;
   }
}

//+------------------------------------------------------------------+
//| HISTORY ITERATION HELPERS (MT4→MT5 adaptation)                    |
//|                                                                   |
//| MT5 closes are represented as OUT deals. We filter:                |
//|   * DEAL_ENTRY == DEAL_ENTRY_OUT  (position was closed)            |
//|   * DEAL_SYMBOL == _Symbol                                         |
//|   * DEAL_MAGIC  == Magic                                           |
//| The OUT deal's DEAL_TYPE is OPPOSITE to the original position      |
//| direction (a BUY position closes via a SELL deal, and vice versa). |
//| So: wasLongPosition = (DEAL_TYPE == DEAL_TYPE_SELL).               |
//+------------------------------------------------------------------+

// Load enough history to cover month-level stats + 24h markers window.
// Called at the top of any dashboard scan.
void Dashboard_LoadHistoryRange()
{
   datetime from = TimeCurrent() - 40 * 86400; // 40 days: spans month boundary + buffer
   HistorySelect(from, TimeCurrent());
}

// True if the indexed history deal belongs to us and is a close.
// Fills out-params used by stats/marker collectors.
bool Dashboard_ReadCloseDeal(int i,
                             ulong &dealTicket,
                             datetime &closeTime,
                             double &closePrice,
                             double &profit,
                             int &longSideSign,
                             string &dealComment,
                             ulong &positionId)
{
   dealTicket = HistoryDealGetTicket(i);
   if(dealTicket == 0) return false;
   if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) return false;
   if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != (long)Magic) return false;
   if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY) != DEAL_ENTRY_OUT) return false;

   closeTime  = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
   closePrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
   profit     = HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
              + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
              + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);

   ENUM_DEAL_TYPE dt = (ENUM_DEAL_TYPE)HistoryDealGetInteger(dealTicket, DEAL_TYPE);
   // Closing deal direction is opposite of original position direction.
   longSideSign = (dt == DEAL_TYPE_SELL) ? +1 : -1;

   dealComment = HistoryDealGetString(dealTicket, DEAL_COMMENT);
   positionId  = (ulong)HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
   return true;
}

// Given an OUT deal's position id, find the corresponding IN deal (open).
// Returns true on success with open time/price filled.
bool Dashboard_FindInDeal(ulong positionId, datetime &openTime, double &openPrice)
{
   if(!HistorySelectByPosition((long)positionId)) return false;
   int n = HistoryDealsTotal();
   for(int i = 0; i < n; i++)
   {
      ulong tk = HistoryDealGetTicket(i);
      if(tk == 0) continue;
      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(tk, DEAL_ENTRY) != DEAL_ENTRY_IN) continue;
      openTime  = (datetime)HistoryDealGetInteger(tk, DEAL_TIME);
      openPrice = HistoryDealGetDouble(tk, DEAL_PRICE);
      // Reload the broader history window so subsequent iterations still see
      // the full range (HistorySelectByPosition narrows the selection).
      Dashboard_LoadHistoryRange();
      return true;
   }
   Dashboard_LoadHistoryRange();
   return false;
}

//+------------------------------------------------------------------+
//| M15 BUCKETED PnL (bottom strip + TodayPnL readout)                |
//+------------------------------------------------------------------+
void Dashboard_AddDealToM15Bucket(datetime closeTime, double profit)
{
   if(DayKey(closeTime) != g_pnlDayKey) return;
   int idx = MinutesOfDay(closeTime) / 15;
   if(idx < 0 || idx > 95) return;
   g_m15Pnl[idx] += profit;
}

void ResetPnLDayIfNeeded()
{
   int dk = DayKey(TimeCurrent());
   if(dk == g_pnlDayKey) return;

   g_pnlDayKey = dk;
   for(int i = 0; i < 96; i++) g_m15Pnl[i] = 0.0;

   Dashboard_LoadHistoryRange();
   int ht = HistoryDealsTotal();
   for(int i = 0; i < ht; i++)
   {
      ulong dealTicket, posId;
      datetime ct;
      double cp, profit;
      int longSign;
      string cmt;
      if(!Dashboard_ReadCloseDeal(i, dealTicket, ct, cp, profit, longSign, cmt, posId)) continue;
      if(DayKey(ct) != g_pnlDayKey) continue;
      Dashboard_AddDealToM15Bucket(ct, profit);
   }
   g_lastHistTotal = ht;
}

double TodayPnL()
{
   double s = 0;
   for(int i = 0; i < 96; i++) s += g_m15Pnl[i];
   return s;
}

//+------------------------------------------------------------------+
//| STATISTICS CALCULATION                                            |
//| Aggregates closed P&L per direction per period (today/week/month) |
//+------------------------------------------------------------------+
void CalculateStatistics()
{
   datetime now = TimeCurrent();
   int todayKey = DayKey(now);
   int weekKey  = WeekKey(now);
   int monthKey = MonthKey(now);

   // Reset counters
   g_closedLongToday = 0; g_closedShortToday = 0;
   g_profitLongToday = 0; g_profitShortToday = 0;
   g_closedLongWeek  = 0; g_closedShortWeek  = 0;
   g_profitLongWeek  = 0; g_profitShortWeek  = 0;
   g_closedLongMonth = 0; g_closedShortMonth = 0;
   g_profitLongMonth = 0; g_profitShortMonth = 0;

   Dashboard_LoadHistoryRange();
   int ht = HistoryDealsTotal();
   for(int i = 0; i < ht; i++)
   {
      ulong dealTicket, posId;
      datetime ct;
      double cp, profit;
      int longSign;
      string cmt;
      if(!Dashboard_ReadCloseDeal(i, dealTicket, ct, cp, profit, longSign, cmt, posId)) continue;

      bool isLong = (longSign > 0);

      int orderDayKey   = DayKey(ct);
      int orderWeekKey  = WeekKey(ct);
      int orderMonthKey = MonthKey(ct);

      // Today
      if(orderDayKey == todayKey)
      {
         if(isLong) { g_closedLongToday++;  g_profitLongToday  += profit; }
         else       { g_closedShortToday++; g_profitShortToday += profit; }
      }

      // This week
      if(orderWeekKey == weekKey)
      {
         if(isLong) { g_closedLongWeek++;  g_profitLongWeek  += profit; }
         else       { g_closedShortWeek++; g_profitShortWeek += profit; }
      }

      // This month
      if(orderMonthKey == monthKey)
      {
         if(isLong) { g_closedLongMonth++;  g_profitLongMonth  += profit; }
         else       { g_closedShortMonth++; g_profitShortMonth += profit; }
      }
   }
}

//+------------------------------------------------------------------+
//| AI SIMULATION ENGINE (cosmetic status widget)                     |
//+------------------------------------------------------------------+
void UpdateAIMessages()
{
   static int msgCounter = 0;
   msgCounter++;

   if(msgCounter % 5 == 0) g_aiMsgIndex = (g_aiMsgIndex + 1) % 5;

   double tickRate = GetAvgTickRate();
   int openBuys  = CountOrdersDir(+1, true);
   int openSells = CountOrdersDir(-1, true);

   g_aiMessages[0] = "Scanning " + IntegerToString((int)(tickRate * 100)) + " data points/sec";
   g_aiMessages[1] = "Pattern recognition: " + g_aiPattern + " detected";
   g_aiMessages[2] = "Market regime: " + g_marketRegime + " | Confidence: " + IntegerToString(g_aiConfidence) + "%";
   g_aiMessages[3] = "Active positions: " + IntegerToString(openBuys) + " LONG / " + IntegerToString(openSells) + " SHORT";
   g_aiMessages[4] = "Risk assessment: " + (g_riskLevel == 0 ? "LOW" : (g_riskLevel == 1 ? "MEDIUM" : "HIGH"));
}

void UpdateAISimulation()
{
   datetime now = TimeCurrent();
   if(now - g_lastAiUpdate < 1) return;
   g_lastAiUpdate = now;

   g_scanPhase = (g_scanPhase + 1) % 100;

   double tickRate = GetAvgTickRate();
   int spread = SpreadPoints();
   int slopePts = MathAbs(g_cachedSlopePts);
   int openOrders = CountOrdersDir(+1, true) + CountOrdersDir(-1, true);

   // AI Status logic
   if(g_scanPhase < 30)        g_aiStatus = "SCANNING MARKET...";
   else if(g_scanPhase < 50)   g_aiStatus = "ANALYZING PATTERNS";
   else if(g_scanPhase < 70)   g_aiStatus = "PROCESSING DATA";
   else if(g_lastSigDir != 0)  g_aiStatus = (g_lastSigDir > 0 ? ">> BUY SIGNAL DETECTED" : ">> SELL SIGNAL DETECTED");
   else if(openOrders > 0)     g_aiStatus = "MONITORING POSITIONS";
   else                        g_aiStatus = "READY - AWAITING SIGNAL";

   // DYNAMIC CONFIDENCE - drifts to 80%, jumps to 93% on new position
   static int lastPositionCount = 0;
   int currentPositions = PositionsTotal();

   if(currentPositions > lastPositionCount)
   {
      g_aiConfidenceTarget = 93;
      g_lastTradeTime = now;
   }
   else if(now - g_lastTradeTime > 30)
   {
      g_aiConfidenceTarget = 80;
   }
   lastPositionCount = currentPositions;

   // Smooth animation - slow transition to target
   if(g_aiConfidence < g_aiConfidenceTarget)
   {
      g_aiConfidence += 2;
      if(g_aiConfidence > g_aiConfidenceTarget) g_aiConfidence = g_aiConfidenceTarget;
   }
   else if(g_aiConfidence > g_aiConfidenceTarget)
   {
      g_aiConfidence -= 1;
      if(g_aiConfidence < g_aiConfidenceTarget) g_aiConfidence = g_aiConfidenceTarget;
   }

   if(g_aiConfidence < 75) g_aiConfidence = 75;
   if(g_aiConfidence > 95) g_aiConfidence = 95;

   // Pattern Recognition
   if(slopePts > strongTrendPts)                     g_aiPattern = "STRONG TREND";
   else if(slopePts > slopeThresholdPts)             g_aiPattern = "MOMENTUM BURST";
   else if(tickRate > TickRateThreshold * 1.5)       g_aiPattern = "HIGH ACTIVITY";
   else if(spread > MaxSpreadPts * 0.8)              g_aiPattern = "SPREAD WARNING";
   else                                              g_aiPattern = "CONSOLIDATION";

   // Market Regime
   if(slopePts > strongTrendPts)                     g_marketRegime = "TRENDING";
   else if(tickRate > TickRateThreshold * 2)         g_marketRegime = "VOLATILE";
   else                                              g_marketRegime = "RANGING";

   // Risk Level
   double ddPct = g_maxDDToday;
   if(ddPct > MaxEquityDD_Pct * 0.7)      g_riskLevel = 2;
   else if(ddPct > MaxEquityDD_Pct * 0.3) g_riskLevel = 1;
   else                                   g_riskLevel = 0;

   // Trade Quality Score
   g_tradeQuality = 0;
   if(InTradingSession(now))              g_tradeQuality += 25;
   if(spread < MaxSpreadPts * 0.5)        g_tradeQuality += 25;
   if(tickRate > TickRateThreshold)       g_tradeQuality += 25;
   if(g_cachedSlopeDir != 0)              g_tradeQuality += 25;

   UpdateAIMessages();
}

//+------------------------------------------------------------------+
//| ELEGANT TRADE MARKERS SYSTEM                                       |
//| Style: Small arrows + dotted lines + profit labels at close        |
//+------------------------------------------------------------------+
void MarkOrderOpen(ulong ticket)
{
   if(!ShowModernMarkers) return;
   if(!PositionSelectByTicket(ticket)) return;
   if(!IsMinePosition()) return;

   datetime t = (datetime)PositionGetInteger(POSITION_TIME);
   if(!InLast24h(t)) return;

   double p = PositionGetDouble(POSITION_PRICE_OPEN);
   ENUM_POSITION_TYPE typ = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

   // Small dot at entry (Wingdings: 159 = small filled circle)
   int dotCode = 159;
   color c = (typ == POSITION_TYPE_BUY ? clrDeepSkyBlue : clrOrangeRed);

   string nm = ObjName("O_" + TicketKey(ticket));
   DrawSmallArrow(nm, t, p, dotCode, c, 1);
}

//+------------------------------------------------------------------+
//| BASKET-CLOSE AGGREGATION (group closes within 5s into one label)  |
//+------------------------------------------------------------------+
void ResetBasketAggregation()
{
   ArrayResize(g_basketCloseTime, 0);
   ArrayResize(g_basketClosePrice, 0);
   ArrayResize(g_basketProfit, 0);
   ArrayResize(g_basketType, 0);
   g_basketCount = 0;
}

// Collect a close for aggregation. Takes the OUT deal ticket and pairs with
// the corresponding IN deal to get open time/price (needed for the trade
// line drawn open→close).
void CollectClosedDealForBasket(ulong outDealTicket)
{
   if(!ShowModernMarkers) return;
   if(outDealTicket == 0) return;

   datetime closeT  = (datetime)HistoryDealGetInteger(outDealTicket, DEAL_TIME);
   if(!InLast24h(closeT)) return;

   double closeP = HistoryDealGetDouble(outDealTicket, DEAL_PRICE);
   double profit = HistoryDealGetDouble(outDealTicket, DEAL_PROFIT)
                 + HistoryDealGetDouble(outDealTicket, DEAL_SWAP)
                 + HistoryDealGetDouble(outDealTicket, DEAL_COMMISSION);

   // Resolve original position direction via the OUT deal's DEAL_TYPE
   // (OUT type is opposite to position direction).
   ENUM_DEAL_TYPE dt = (ENUM_DEAL_TYPE)HistoryDealGetInteger(outDealTicket, DEAL_TYPE);
   int positionSign = (dt == DEAL_TYPE_SELL) ? +1 : -1;  // +1 = BUY position, -1 = SELL

   // Pair with IN deal to get open time/price for the trade line.
   ulong posId = (ulong)HistoryDealGetInteger(outDealTicket, DEAL_POSITION_ID);
   datetime openT = 0;
   double openP = closeP;  // fallback — degenerate line if IN lookup fails
   Dashboard_FindInDeal(posId, openT, openP);
   if(openT == 0) openT = closeT;

   // Colors based on profit
   color profitClr = (profit >= 0 ? clrLime : clrRed);
   color lineClr   = (profit >= 0 ? C'80,200,80' : C'200,100,100');

   // 1. Trade line from open to close
   string lineName = ObjName("L_" + TicketKey(outDealTicket));
   DrawTradeLine(lineName, openT, openP, closeT, closeP, lineClr, STYLE_DOT);

   // 2. Small dot at close
   string closeNm = ObjName("C_" + TicketKey(outDealTicket));
   DrawSmallArrow(closeNm, closeT, closeP, 159, profitClr, 1);

   // 3. Store for basket aggregation
   int idx = g_basketCount;
   ArrayResize(g_basketCloseTime,  idx + 1);
   ArrayResize(g_basketClosePrice, idx + 1);
   ArrayResize(g_basketProfit,     idx + 1);
   ArrayResize(g_basketType,       idx + 1);

   g_basketCloseTime[idx]  = closeT;
   g_basketClosePrice[idx] = closeP;
   g_basketProfit[idx]     = profit;
   g_basketType[idx]       = positionSign;
   g_basketCount++;
}

void DrawAggregatedBasketLabels()
{
   if(g_basketCount == 0) return;

   // Group by close time (within 5 seconds = same basket close)
   int processed[];
   ArrayResize(processed, g_basketCount);
   ArrayInitialize(processed, 0);

   for(int i = 0; i < g_basketCount; i++)
   {
      if(processed[i] == 1) continue;

      datetime baseTime = g_basketCloseTime[i];
      double sumProfit  = g_basketProfit[i];
      double avgPrice   = g_basketClosePrice[i];
      int count         = 1;
      int baseSign      = g_basketType[i];
      processed[i] = 1;

      // Find all orders closed within 5 seconds
      for(int j = i + 1; j < g_basketCount; j++)
      {
         if(processed[j] == 1) continue;
         if(MathAbs((int)(g_basketCloseTime[j] - baseTime)) <= 5)
         {
            sumProfit += g_basketProfit[j];
            avgPrice  += g_basketClosePrice[j];
            count++;
            processed[j] = 1;
         }
      }

      avgPrice /= count;

      // Draw single aggregated label
      color lblClr = (sumProfit >= 0 ? clrLime : clrRed);
      string profitStr = (sumProfit >= 0 ? "+$" : "-$") + DoubleToString(MathAbs(sumProfit), 2);

      // Offset based on original position direction
      double offset = (baseSign > 0 ? 30 * _Point : -30 * _Point);

      string nm = ObjName("BP_" + IntegerToString((int)baseTime));
      DrawProfitLabel(nm, baseTime, avgPrice + offset, profitStr, lblClr, 9, ANCHOR_LEFT);
   }
}

void CleanupOldMarkers()
{
   datetime now = TimeCurrent();
   if(g_lastCleanup != 0 && (now - g_lastCleanup) < 60) return;
   g_lastCleanup = now;

   datetime cutoff = now - MARKERS_WINDOW_SEC;
   int total = ObjectsTotal(0, 0, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, PREFIX + IntegerToString(Magic) + "_", 0) != 0) continue;

      int type = (int)ObjectGetInteger(0, name, OBJPROP_TYPE);
      if(type != OBJ_ARROW && type != OBJ_TEXT && type != OBJ_LABEL && type != OBJ_TREND) continue;

      datetime t1 = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 0);
      if(t1 > 0 && t1 < cutoff) ObjectDelete(0, name);
   }
}

//+------------------------------------------------------------------+
//| REBUILD MARKERS (run once at init / session restart)              |
//+------------------------------------------------------------------+
void RebuildLast24hMarkers()
{
   if(!ShowModernMarkers) return;

   datetime cutoff = TimeCurrent() - MARKERS_WINDOW_SEC;

   ResetBasketAggregation();

   Dashboard_LoadHistoryRange();
   int ht = HistoryDealsTotal();
   for(int i = 0; i < ht; i++)
   {
      ulong dealTicket, posId;
      datetime ct;
      double cp, profit;
      int longSign;
      string cmt;
      if(!Dashboard_ReadCloseDeal(i, dealTicket, ct, cp, profit, longSign, cmt, posId)) continue;
      if(ct < cutoff) continue;
      CollectClosedDealForBasket(dealTicket);
   }

   DrawAggregatedBasketLabels();

   // Mark open positions with dots
   int pt = PositionsTotal();
   for(int j = pt - 1; j >= 0; j--)
   {
      ulong ticket = PositionGetTicket(j);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(!IsMinePosition()) continue;
      datetime ot = (datetime)PositionGetInteger(POSITION_TIME);
      if(ot < cutoff) continue;
      MarkOrderOpen(ticket);
   }
}

//+------------------------------------------------------------------+
//| DASHBOARD - WALL STREET PROFESSIONAL STYLE                        |
//+------------------------------------------------------------------+
void DrawProDashboard()
{
   if(!ShowProDashboard) return;

   datetime now = TimeCurrent();
   if(now - g_lastDashUpdate < 1) return;
   g_lastDashUpdate = now;

   // WALL STREET COLOR PALETTE - Dark professional theme
   color bgDark       = C'18,22,28';
   color bgPanel      = C'24,28,36';
   color borderMain   = C'45,52,65';
   color borderAccent = C'55,90,140';
   color textBright   = C'220,225,230';
   color textMuted    = C'130,140,155';
   color accentGold   = C'212,175,55';
   color accentBlue   = C'70,130,200';
   color profitGreen  = C'50,205,100';
   color lossRed      = C'220,70,70';

   int x = DashboardX;
   int y = DashboardY;
   int w = DashboardWidth;

   // ================================================================
   // HEADER
   // ================================================================
   DrawPanel(ObjName("D_Header"), x, y, w, 40, C'20,35,55', borderAccent);
   DrawLabel(ObjName("D_Title"),   x + 15,     y + 10, "MoneyDancer", textBright, 10, "Arial Bold");
   DrawLabel(ObjName("D_Version"), x + w - 50, y + 12, "v1.0",        accentGold, 8,  "Arial Bold");

   // Status LED
   string ledChar = (g_scanPhase % 20 < 10 ? "o" : "O");
   color  ledClr  = (g_eaStopped ? lossRed : profitGreen);
   DrawLabel(ObjName("D_LED"), x + w - 25, y + 12, ledChar, ledClr, 10, "Webdings");

   y += 45;

   // ================================================================
   // ENGINE PANEL
   // ================================================================
   DrawPanel(ObjName("D_AIPanel"), x, y, w, 70, bgPanel, borderMain);
   DrawLabel(ObjName("D_AITitle"), x + 12, y + 6, ">> ENGINE", accentBlue, 8, "Arial Bold");

   string dots = "";
   int dotCnt = (g_scanPhase / 8) % 4;
   for(int i = 0; i < dotCnt; i++) dots += ".";
   DrawLabel(ObjName("D_AIStatus"), x + 15, y + 24, g_aiStatus + dots,         textBright, 10, "Consolas");
   DrawLabel(ObjName("D_AIMsg"),    x + 15, y + 42, g_aiMessages[g_aiMsgIndex], textMuted, 7,  "Consolas");

   // Confidence bar
   int barW = 80, barH = 10;
   int barX = x + w - barW - 45;
   int barY = y + 22;
   DrawPanel(ObjName("D_ConfBg"), barX, barY, barW, barH, C'35,40,50', borderMain);
   int fillW = (int)(barW * g_aiConfidence / 100.0);
   color confClr = (g_aiConfidence > 70 ? profitGreen : (g_aiConfidence > 40 ? accentGold : lossRed));
   if(fillW > 0) DrawPanel(ObjName("D_ConfFill"), barX + 1, barY + 1, fillW - 2, barH - 2, confClr, clrNONE);
   DrawLabel(ObjName("D_ConfLbl"), barX,            barY - 12, "CONFIDENCE",                  textMuted, 7, "Arial");
   DrawLabel(ObjName("D_ConfPct"), barX + barW + 5, barY,      IntegerToString(g_aiConfidence) + "%", confClr, 9, "Arial Bold");

   y += 75;

   // ================================================================
   // LIVE METRICS PANEL
   // ================================================================
   DrawPanel(ObjName("D_MetricsPanel"), x, y, w, 90, bgPanel, borderMain);
   DrawLabel(ObjName("D_MetricsTitle"), x + 12, y + 6, ">> LIVE METRICS", accentBlue, 8, "Arial Bold");

   double avgTick  = GetAvgTickSize();
   double tickRate = GetAvgTickRate();
   int    spread   = SpreadPoints();

   // Left column
   DrawLabel(ObjName("D_L1"), x + 15,  y + 25, "AVG TICK (100):", textMuted,  8, "Arial");
   DrawLabel(ObjName("D_V1"), x + 120, y + 25, DoubleToString(avgTick, 2),    textBright, 9, "Consolas");

   DrawLabel(ObjName("D_L2"), x + 15,  y + 42, "TICK RATE:",     textMuted,  8, "Arial");
   DrawLabel(ObjName("D_V2"), x + 120, y + 42, DoubleToString(tickRate, 1) + " t/s", textBright, 9, "Consolas");

   DrawLabel(ObjName("D_L3"), x + 15,  y + 59, "SPREAD:",       textMuted,  8, "Arial");
   color spClr = (spread < MaxSpreadPts / 2 ? profitGreen : (spread < MaxSpreadPts ? accentGold : lossRed));
   DrawLabel(ObjName("D_V3"), x + 120, y + 59, IntegerToString(spread) + " pts", spClr, 9, "Consolas");

   // Right column
   DrawLabel(ObjName("D_L4"), x + w/2 + 10,  y + 25, "MAX DD TODAY:", textMuted, 8, "Arial");
   color ddTClr = (g_maxDDToday > MaxEquityDD_Pct * 0.5 ? lossRed : textBright);
   DrawLabel(ObjName("D_V4"), x + w/2 + 110, y + 25, DoubleToString(g_maxDDToday, 2) + "%", ddTClr, 9, "Consolas");

   DrawLabel(ObjName("D_L5"), x + w/2 + 10,  y + 42, "MAX DD EVER:", textMuted, 8, "Arial");
   color ddEClr = (g_maxDDEver > MaxEquityDD_Pct ? lossRed : textBright);
   DrawLabel(ObjName("D_V5"), x + w/2 + 110, y + 42, DoubleToString(g_maxDDEver, 2) + "%", ddEClr, 9, "Consolas");

   DrawLabel(ObjName("D_L6"), x + w/2 + 10,  y + 59, "PATTERN:",     textMuted, 8, "Arial");
   DrawLabel(ObjName("D_V6"), x + w/2 + 110, y + 59, g_aiPattern,    accentGold, 9, "Consolas");

   // Bottom row - Risk/Quality/Regime
   string riskTxt = (g_riskLevel == 0 ? "LOW" : (g_riskLevel == 1 ? "MED" : "HIGH"));
   color  riskClr = (g_riskLevel == 0 ? profitGreen : (g_riskLevel == 1 ? accentGold : lossRed));
   DrawLabel(ObjName("D_RiskL"), x + 15,  y + 75, "RISK:", textMuted, 7, "Arial");
   DrawLabel(ObjName("D_RiskV"), x + 50,  y + 75, riskTxt, riskClr,   8, "Arial Bold");

   DrawLabel(ObjName("D_QualL"), x + 100, y + 75, "QUAL:", textMuted, 7, "Arial");
   color qClr = (g_tradeQuality > 70 ? profitGreen : (g_tradeQuality > 40 ? accentGold : lossRed));
   DrawLabel(ObjName("D_QualV"), x + 135, y + 75, IntegerToString(g_tradeQuality) + "%", qClr, 8, "Arial Bold");

   DrawLabel(ObjName("D_RegL"), x + w/2 + 10, y + 75, "REGIME:", textMuted, 7, "Arial");
   color regClr = (g_marketRegime == "TRENDING" ? profitGreen : (g_marketRegime == "VOLATILE" ? lossRed : accentGold));
   DrawLabel(ObjName("D_RegV"), x + w/2 + 60, y + 75, g_marketRegime, regClr, 8, "Arial Bold");

   y += 95;

   // ================================================================
   // POSITION STATISTICS PANEL
   // ================================================================
   DrawPanel(ObjName("D_StatsPanel"), x, y, w, 105, bgPanel, borderMain);
   DrawLabel(ObjName("D_StatsTitle"), x + 12, y + 6, ">> POSITIONS", accentBlue, 8, "Arial Bold");

   // Period buttons
   int btnW = 60, btnH = 16;
   int btnX = x + w - 195;
   color btnT  = (g_statsViewMode == 0 ? accentBlue : C'40,45,55');
   color btnW2 = (g_statsViewMode == 1 ? accentBlue : C'40,45,55');
   color btnM  = (g_statsViewMode == 2 ? accentBlue : C'40,45,55');
   CreateButton(ObjName("D_BtnToday"), btnX,                y + 5, btnW, btnH, "TODAY", textBright, btnT);
   CreateButton(ObjName("D_BtnWeek"),  btnX + btnW + 3,     y + 5, btnW, btnH, "WEEK",  textBright, btnW2);
   CreateButton(ObjName("D_BtnMonth"), btnX + 2*(btnW + 3), y + 5, btnW, btnH, "MONTH", textBright, btnM);

   int cL = 0, cS = 0; double pL = 0, pS = 0;
   if(g_statsViewMode == 0)      { cL = g_closedLongToday; cS = g_closedShortToday; pL = g_profitLongToday; pS = g_profitShortToday; }
   else if(g_statsViewMode == 1) { cL = g_closedLongWeek;  cS = g_closedShortWeek;  pL = g_profitLongWeek;  pS = g_profitShortWeek;  }
   else                          { cL = g_closedLongMonth; cS = g_closedShortMonth; pL = g_profitLongMonth; pS = g_profitShortMonth; }

   // LONG row
   DrawLabel(ObjName("D_LI"), x + 15, y + 28, "^",     accentBlue, 14, "Wingdings 3");
   DrawLabel(ObjName("D_LL"), x + 35, y + 30, "LONG:", textMuted,   8, "Arial");
   DrawLabel(ObjName("D_LC"), x + 80, y + 30, IntegerToString(cL), textBright, 9, "Consolas");
   color pLClr = (pL >= 0 ? profitGreen : lossRed);
   DrawLabel(ObjName("D_LP"), x + 110, y + 30, (pL >= 0 ? "+" : "") + DoubleToString(pL, 2), pLClr, 9, "Consolas");

   // SHORT row
   DrawLabel(ObjName("D_SI"), x + 15, y + 46, "_",      lossRed,   14, "Wingdings 3");
   DrawLabel(ObjName("D_SL"), x + 35, y + 48, "SHORT:", textMuted,  8, "Arial");
   DrawLabel(ObjName("D_SC"), x + 80, y + 48, IntegerToString(cS), textBright, 9, "Consolas");
   color pSClr = (pS >= 0 ? profitGreen : lossRed);
   DrawLabel(ObjName("D_SP"), x + 110, y + 48, (pS >= 0 ? "+" : "") + DoubleToString(pS, 2), pSClr, 9, "Consolas");

   // TOTAL row
   double totP = pL + pS;
   int    totC = cL + cS;
   DrawLabel(ObjName("D_TL"), x + 15, y + 68, "TOTAL:", textMuted, 9, "Arial Bold");
   DrawLabel(ObjName("D_TC"), x + 70, y + 68, IntegerToString(totC), textBright, 9, "Consolas");
   color totClr = (totP >= 0 ? profitGreen : lossRed);
   DrawLabel(ObjName("D_TP"), x + 110, y + 68, (totP >= 0 ? "+$" : "-$") + DoubleToString(MathAbs(totP), 2), totClr, 11, "Arial Bold");

   // Open positions
   int    oB = CountOrdersDir(+1, true);
   int    oS = CountOrdersDir(-1, true);
   double fB = BasketFloatingPL(+1, true);
   double fS = BasketFloatingPL(-1, true);
   double fT = fB + fS;

   DrawLabel(ObjName("D_OL"), x + w/2 + 15, y + 30, "OPEN:", textMuted, 8, "Arial");
   DrawLabel(ObjName("D_OB"), x + w/2 + 60, y + 30, IntegerToString(oB) + " B", accentBlue, 9, "Consolas");
   DrawLabel(ObjName("D_OS"), x + w/2 + 100, y + 30, IntegerToString(oS) + " S", lossRed,   9, "Consolas");

   DrawLabel(ObjName("D_FL"), x + w/2 + 15, y + 48, "FLOAT:", textMuted, 8, "Arial");
   color fClr = (fT >= 0 ? profitGreen : lossRed);
   DrawLabel(ObjName("D_FV"), x + w/2 + 60, y + 48, (fT >= 0 ? "+$" : "-$") + DoubleToString(MathAbs(fT), 2), fClr, 10, "Consolas");

   y += 110;

   // ================================================================
   // CONTROL BUTTONS PANEL
   // ================================================================
   DrawPanel(ObjName("D_CtrlPanel"), x, y, w, 80, bgPanel, borderMain);
   DrawLabel(ObjName("D_CtrlTitle"), x + 12, y + 6, ">> CONTROLS", accentBlue, 8, "Arial Bold");

   int cBtnW = 95, cBtnH = 20;
   int cY1 = y + 26, cY2 = y + 52;

   CreateButton(ObjName("D_BtnProfitSell"),   x + 8,   cY1, cBtnW, cBtnH, "+ PROFIT SELL", textBright, C'70,45,45');
   CreateButton(ObjName("D_BtnProfitBuy"),    x + 108, cY1, cBtnW, cBtnH, "+ PROFIT BUY",  textBright, C'45,70,45');
   CreateButton(ObjName("D_BtnCloseAllSell"), x + 208, cY1, cBtnW, cBtnH, "X ALL SELL",    textBright, C'100,45,45');
   CreateButton(ObjName("D_BtnCloseAllBuy"),  x + 308, cY1, cBtnW, cBtnH, "X ALL BUY",     textBright, C'45,80,45');

   CreateButton(ObjName("D_BtnCloseAll"), x + 8,   cY2, 195, cBtnH, "!! CLOSE ALL !!", textBright, C'130,50,50');
   string stopTxt = (g_eaStopped ? "> START EA" : "[] STOP EA");
   color  stopBg  = (g_eaStopped ? C'45,90,45' : C'90,45,45');
   CreateButton(ObjName("D_BtnStopEA"),   x + 208, cY2, 195, cBtnH, stopTxt, textBright, stopBg);

   y += 85;

   // ================================================================
   // FOOTER
   // ================================================================
   DrawPanel(ObjName("D_Footer"), x, y, w, 22, bgDark, borderMain);
   string sessStr = (InTradingSession(now) ? "[ACTIVE]" : "[CLOSED]");
   color  sessClr = (InTradingSession(now) ? profitGreen : textMuted);
   DrawLabel(ObjName("D_Sess"), x + 10, y + 4, sessStr, sessClr, 8, "Arial");

   // Daily cap / pause status (compact)
   string capTxt = "";
   color  capClr = textMuted;
   if(IsAutoPaused())
   {
      capTxt = "PAUSE:" + g_tradePauseReason;
      capClr = accentGold;
   }
   else if(g_dayBaseReady)
   {
      string pfx = (g_dayProfitUsd >= 0 ? "+$" : "-$");
      capTxt = "DAY:" + pfx + DoubleToString(MathAbs(g_dayProfitUsd), 0);
      if(MaxDailyProfitPct > 0)
         capTxt = capTxt + " CAP:" + IntegerToString(MaxDailyProfitPct) + "%";

      // Profit lock status
      if(RiskFromCurrentProfit)
      {
         string lockTag = " LOCK@" + TwoDigit(RiskFromCurrentProfitUntilHour) + ":" + TwoDigit(RiskFromCurrentProfitUntilMinute);
         if(g_profitLockCaptured)
            lockTag = lockTag + "+$" + DoubleToString(g_lockedProfitUsd, 0);
         capTxt = capTxt + lockTag;
      }
      capClr = (g_dayProfitUsd >= 0 ? profitGreen : lossRed);
   }
   else
   {
      capTxt = "BASE@" + TwoDigit(DailyBaselineHour) + ":" + TwoDigit(DailyBaselineMinute);
      capClr = textMuted;
   }
   DrawLabel(ObjName("D_Cap"),  x + 90,      y + 4, capTxt,                                        capClr,    8, "Consolas");
   DrawLabel(ObjName("D_Time"), x + w - 115, y + 4, TimeToString(now, TIME_DATE|TIME_MINUTES),     textMuted, 8, "Consolas");
   DrawLabel(ObjName("D_Mode"), x + w/2 - 25, y + 4, g_lastMode,                                    textMuted, 8, "Arial");
}

//+------------------------------------------------------------------+
//| BOTTOM RESULTS PANEL (15-min intervals)                           |
//+------------------------------------------------------------------+
void DrawBottomResultsPanel()
{
   if(!ShowBottomResults) return;

   // Throttle to once per second — M15 bucket data only changes per-minute at
   // finest, so per-tick redraw is pure waste and causes flicker.
   datetime now = TimeCurrent();
   if(now - g_lastBottomUpdate < 1) return;
   g_lastBottomUpdate = now;

   // Get current M15 index
   int curIdx = MinutesOfDay(now) / 15;
   if(curIdx < 0) curIdx = 0;
   if(curIdx > 95) curIdx = 95;

   // Collect non-zero intervals
   int validIdxs[];
   ArrayResize(validIdxs, 0);

   for(int i = curIdx; i >= 0 && ArraySize(validIdxs) < BottomResultsCount; i--)
   {
      if(MathAbs(g_m15Pnl[i]) > 0.001)
      {
         int size = ArraySize(validIdxs);
         ArrayResize(validIdxs, size + 1);
         validIdxs[size] = i;
      }
   }

   int newCount = ArraySize(validIdxs);

   // Delete only slots that are no longer needed. Persisting slots get their
   // text/colour refreshed in place by CreateBottomLabel below — so there's
   // no delete→recreate flicker in the common case.
   for(int j = newCount; j < 20; j++)
      DeleteObject(ObjName("BR_" + IntegerToString(j)));

   if(newCount == 0) return;

   // Draw bottom labels at chart time positions
   int labelW = 100;
   int gap    = 8;
   int yPos   = 25;

   for(int k = 0; k < newCount; k++)
   {
      int    idx = validIdxs[newCount - 1 - k];
      double pnl = g_m15Pnl[idx];

      int hh = idx / 4;
      int mm = (idx % 4) * 15;
      string timeStr = TwoDigit(hh) + ":" + TwoDigit(mm);

      string valStr = (pnl >= 0 ? "+" : "") + DoubleToString(pnl, 2);
      string text   = timeStr + " | " + valStr;

      color bgClr  = (pnl >= 0 ? C'20,80,40'  : C'100,30,30');
      color txtClr = (pnl >= 0 ? clrLime       : clrCoral);

      int xPos = 15 + k * (labelW + gap);

      string nm = ObjName("BR_" + IntegerToString(k));
      CreateBottomLabel(nm, xPos, yPos, labelW, 20, text, txtClr, bgClr);
   }
}

//+------------------------------------------------------------------+
//| BASKET SERIES-END LABELS                                           |
//| Sum of all closes in a series (within 24h), labelled once the     |
//| series has fully closed.                                           |
//+------------------------------------------------------------------+
double SeriesProfitAndLastClose24h(string seriesKey, datetime &lastT, double &lastP)
{
   lastT = 0;
   lastP = 0;
   double sum = 0.0;

   Dashboard_LoadHistoryRange();
   datetime cutoff = TimeCurrent() - MARKERS_WINDOW_SEC;
   int ht = HistoryDealsTotal();
   for(int i = 0; i < ht; i++)
   {
      ulong dealTicket, posId;
      datetime ct;
      double cp, profit;
      int longSign;
      string cmt;
      if(!Dashboard_ReadCloseDeal(i, dealTicket, ct, cp, profit, longSign, cmt, posId)) continue;
      if(ct < cutoff) continue;

      // Series membership: comment must contain seriesKey or "TBE"+seriesKey
      if(StringFind(cmt, seriesKey, 0) < 0 && StringFind(cmt, "TBE" + seriesKey, 0) < 0) continue;

      sum += profit;
      if(ct > lastT) { lastT = ct; lastP = cp; }
   }
   return sum;
}

void FinalizeSeriesIfEnded(int dir)
{
   if(!ShowBasketLabels) return;
   if(!SeriesActive(dir)) return;

   int cnt = CountOrdersDir(dir, true);
   if(cnt > 0) return;

   int id = CurrentSeriesId(dir);
   string key = SeriesKey(dir, id);

   datetime lt; double lp;
   double sum = SeriesProfitAndLastClose24h(key, lt, lp);

   if(lt > 0)
   {
      string dirStr = (dir > 0 ? "BUY" : "SELL");
      string text = "[" + dirStr + " #" + IntegerToString(id) + "] ";
      text += (sum >= 0 ? "+$" : "-$") + DoubleToString(MathAbs(sum), 2);

      double off = (dir > 0 ? -80 * _Point : +80 * _Point);
      color  c   = (sum >= 0 ? clrLime : clrCrimson);

      string nm = ObjName("S_" + (dir > 0 ? "B" : "S") + "_" + IntegerToString(id));
      DrawProfitLabel(nm, lt, lp + off, text, c, 9, ANCHOR_CENTER);
   }

   SetSeriesActive(dir, false);
}

//+------------------------------------------------------------------+
//| PERIODIC HISTORY SCAN (UI-side: PnL bucket + markers)             |
//|                                                                   |
//| NOTE: the siphon-on-close trigger lives in                        |
//| ScenarioE_ScanNewRunnerClosures (ScenarioE.mqh). This function    |
//| handles visual state only — bucketing + marker collection +       |
//| aggregated basket labels. We track g_lastHistTotal so reprocessing |
//| is skipped when no new deals arrived.                             |
//+------------------------------------------------------------------+
void ScanHistoryNewAndUpdatePnLAndMarkers()
{
   Dashboard_LoadHistoryRange();
   int ht = HistoryDealsTotal();
   if(ht <= g_lastHistTotal) return;

   ResetBasketAggregation();

   for(int i = g_lastHistTotal; i < ht; i++)
   {
      ulong dealTicket, posId;
      datetime ct;
      double cp, profit;
      int longSign;
      string cmt;
      if(!Dashboard_ReadCloseDeal(i, dealTicket, ct, cp, profit, longSign, cmt, posId)) continue;

      Dashboard_AddDealToM15Bucket(ct, profit);
      CollectClosedDealForBasket(dealTicket);
   }

   DrawAggregatedBasketLabels();
   g_lastHistTotal = ht;
}

//+------------------------------------------------------------------+
//| POSITION CLOSING (button targets)                                 |
//|                                                                   |
//| Dashboard close buttons operate across ALL our positions,         |
//| including pyramid + runners. Intentional: STOP / CLOSE ALL is a   |
//| human safety control.                                             |
//+------------------------------------------------------------------+
void CloseProfitOrders(ENUM_POSITION_TYPE posType)
{
   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!IsMinePosition()) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != posType) continue;

      double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      if(profit > 0) g_dashTrade.PositionClose(ticket);
   }
}

void CloseAllOrdersType(ENUM_POSITION_TYPE posType)
{
   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!IsMinePosition()) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != posType) continue;
      g_dashTrade.PositionClose(ticket);
   }
}

void CloseAllOrders()
{
   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!IsMinePosition()) continue;
      g_dashTrade.PositionClose(ticket);
   }
}

//+------------------------------------------------------------------+
//| BUTTON EVENT HANDLERS                                             |
//| Polled from OnTick (throttled 1/sec). MT5 buttons auto-latch      |
//| OBJPROP_STATE=true on click — we reset to false after handling.   |
//+------------------------------------------------------------------+
void CheckButtonClicks()
{
   datetime now = TimeCurrent();
   if(now - g_lastButtonCheck < 1) return;
   g_lastButtonCheck = now;

   // Stats view mode buttons
   if(ObjectGetInteger(0, ObjName("D_BtnToday"), OBJPROP_STATE) == 1)
   {
      g_statsViewMode = 0;
      ObjectSetInteger(0, ObjName("D_BtnToday"), OBJPROP_STATE, 0);
   }
   if(ObjectGetInteger(0, ObjName("D_BtnWeek"), OBJPROP_STATE) == 1)
   {
      g_statsViewMode = 1;
      ObjectSetInteger(0, ObjName("D_BtnWeek"), OBJPROP_STATE, 0);
   }
   if(ObjectGetInteger(0, ObjName("D_BtnMonth"), OBJPROP_STATE) == 1)
   {
      g_statsViewMode = 2;
      ObjectSetInteger(0, ObjName("D_BtnMonth"), OBJPROP_STATE, 0);
   }

   // Close Profit Sell
   if(ObjectGetInteger(0, ObjName("D_BtnProfitSell"), OBJPROP_STATE) == 1)
   {
      CloseProfitOrders(POSITION_TYPE_SELL);
      ObjectSetInteger(0, ObjName("D_BtnProfitSell"), OBJPROP_STATE, 0);
   }

   // Close Profit Buy
   if(ObjectGetInteger(0, ObjName("D_BtnProfitBuy"), OBJPROP_STATE) == 1)
   {
      CloseProfitOrders(POSITION_TYPE_BUY);
      ObjectSetInteger(0, ObjName("D_BtnProfitBuy"), OBJPROP_STATE, 0);
   }

   // Close All Sell
   if(ObjectGetInteger(0, ObjName("D_BtnCloseAllSell"), OBJPROP_STATE) == 1)
   {
      CloseAllOrdersType(POSITION_TYPE_SELL);
      ObjectSetInteger(0, ObjName("D_BtnCloseAllSell"), OBJPROP_STATE, 0);
   }

   // Close All Buy
   if(ObjectGetInteger(0, ObjName("D_BtnCloseAllBuy"), OBJPROP_STATE) == 1)
   {
      CloseAllOrdersType(POSITION_TYPE_BUY);
      ObjectSetInteger(0, ObjName("D_BtnCloseAllBuy"), OBJPROP_STATE, 0);
   }

   // Close All + Stop EA
   if(ObjectGetInteger(0, ObjName("D_BtnCloseAll"), OBJPROP_STATE) == 1)
   {
      CloseAllOrders();
      g_eaStopped = true;
      ObjectSetInteger(0, ObjName("D_BtnCloseAll"), OBJPROP_STATE, 0);
   }

   // Stop/Start EA toggle
   if(ObjectGetInteger(0, ObjName("D_BtnStopEA"), OBJPROP_STATE) == 1)
   {
      g_eaStopped = !g_eaStopped;
      ObjectSetInteger(0, ObjName("D_BtnStopEA"), OBJPROP_STATE, 0);
   }
}

//+------------------------------------------------------------------+
//| CLEANUP DASHBOARD (called from OnDeinit)                          |
//+------------------------------------------------------------------+
void CleanupDashboard()
{
   int total = ObjectsTotal(0, 0, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, PREFIX, 0) == 0) ObjectDelete(0, name);
   }
}

//+------------------------------------------------------------------+
//| PER-TICK DASHBOARD DRIVER                                          |
//| Called from OnTick; throttles inside each helper (dash/AI sim are |
//| 1s-throttled; history scan is diff-based; cleanup is 60s).         |
//+------------------------------------------------------------------+
void Dashboard_OnTick()
{
   UpdateTickSize();
   UpdateMaxDD();
   UpdateAISimulation();
   ResetPnLDayIfNeeded();
   ScanHistoryNewAndUpdatePnLAndMarkers();
   CalculateStatistics();
   DrawProDashboard();
   DrawBottomResultsPanel();
   FinalizeSeriesIfEnded(+1);
   FinalizeSeriesIfEnded(-1);
   CleanupOldMarkers();
   CheckButtonClicks();
}

#endif // __MD_DASHBOARD_MQH__
