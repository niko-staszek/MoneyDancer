//+------------------------------------------------------------------+
//| Pyramid.mqh — pyramid bookkeeping + management                   |
//| Phase A5.2                                                       |
//|                                                                   |
//| Rules (preserved from MT4):                                       |
//|  - Pyramid is always single-direction (no hedging inside).        |
//|  - Trigger = TP distance level (TP_Points) from the position's    |
//|    open price. Next pyramid add is allowed once price crosses     |
//|    the last add's trigger.                                        |
//|  - BUILDING (slope agrees with direction): all positions TP=0     |
//|    so the run stays open.                                         |
//|  - COASTING (slope fades): set common TP = trigger of last add,   |
//|    locking in the run.                                            |
//|  - After each new add, propagate SL = weighted-avg BE of          |
//|    (last + prev) across ALL pyramid positions.                    |
//|                                                                   |
//| MT5 adaptations: tickets are ulong; OrderSelect→PositionSelect;   |
//| Digits/Point → _Digits/_Point; StringConcatenate→+.               |
//+------------------------------------------------------------------+
#ifndef __MD_PYRAMID_MQH__
#define __MD_PYRAMID_MQH__

// Forward declaration — defined in Series.mqh (A5.3). Used by PyramidManage
// when the pyramid feature is turned off mid-run to re-scan open-position
// comments for series IDs (restart-safe series recovery).
void SyncSeriesIdsFromOpenOrders();

//+------------------------------------------------------------------+
//| Filename builder                                                  |
//+------------------------------------------------------------------+
string PyramidFileName()
{
   return("MoneyDancer_pyramid_" + IntegerToString(Magic) + "_" + _Symbol + ".csv");
}

//+------------------------------------------------------------------+
//| Array ops                                                         |
//+------------------------------------------------------------------+
void PyrClear()
{
   ArrayResize(g_pyrTickets, 0);
   ArrayResize(g_pyrTrigger, 0);
   ArrayResize(g_pyrTP, 0);
   ArrayResize(g_pyrSL, 0);
   ArrayResize(g_pyrIndex, 0);
}

int PyrFindTicket(ulong ticket)
{
   for(int i = 0; i < ArraySize(g_pyrTickets); i++)
      if(g_pyrTickets[i] == ticket) return i;
   return -1;
}

bool IsPyramidTicket(ulong ticket)
{
   return (PyrFindTicket(ticket) >= 0);
}

void PyrRemoveAt(int idx)
{
   int n = ArraySize(g_pyrTickets);
   if(idx < 0 || idx >= n) return;
   if(idx != n - 1)
   {
      g_pyrTickets[idx] = g_pyrTickets[n - 1];
      g_pyrTrigger[idx] = g_pyrTrigger[n - 1];
      g_pyrTP[idx]      = g_pyrTP[n - 1];
      g_pyrSL[idx]      = g_pyrSL[n - 1];
      g_pyrIndex[idx]   = g_pyrIndex[n - 1];
   }
   ArrayResize(g_pyrTickets, n - 1);
   ArrayResize(g_pyrTrigger, n - 1);
   ArrayResize(g_pyrTP, n - 1);
   ArrayResize(g_pyrSL, n - 1);
   ArrayResize(g_pyrIndex, n - 1);
}

void PyrAddOrUpdate(ulong ticket, double trigger, double tp, double sl, int index)
{
   int idx = PyrFindTicket(ticket);
   if(idx < 0)
   {
      int n = ArraySize(g_pyrTickets);
      ArrayResize(g_pyrTickets, n + 1);
      ArrayResize(g_pyrTrigger, n + 1);
      ArrayResize(g_pyrTP,      n + 1);
      ArrayResize(g_pyrSL,      n + 1);
      ArrayResize(g_pyrIndex,   n + 1);
      g_pyrTickets[n] = ticket;
      g_pyrTrigger[n] = trigger;
      g_pyrTP[n]      = tp;
      g_pyrSL[n]      = sl;
      g_pyrIndex[n]   = index;
   }
   else
   {
      g_pyrTrigger[idx] = trigger;
      g_pyrTP[idx]      = tp;
      g_pyrSL[idx]      = sl;
      g_pyrIndex[idx]   = index;
   }
}

int PyrCount() { return ArraySize(g_pyrTickets); }

// Returns array idx of the element with the highest index (i.e. the last
// pyramid add by order). -1 if empty.
int PyrLastIdxByIndex()
{
   int n = PyrCount();
   if(n <= 0) return -1;
   int best = 0;
   for(int i = 1; i < n; i++)
      if(g_pyrIndex[i] > g_pyrIndex[best]) best = i;
   return best;
}

// Array idx of the element with the second-highest index (the "previous"
// add relative to `lastArrayIdx`). -1 if there is no prev.
int PyrPrevIdxByIndex(int lastArrayIdx)
{
   int n = PyrCount();
   if(n < 2 || lastArrayIdx < 0) return -1;
   int lastIndex = g_pyrIndex[lastArrayIdx];
   int best = -1;
   for(int i = 0; i < n; i++)
   {
      if(i == lastArrayIdx) continue;
      if(g_pyrIndex[i] == lastIndex - 1) return i;
      if(g_pyrIndex[i] < lastIndex)
      {
         if(best < 0 || g_pyrIndex[i] > g_pyrIndex[best]) best = i;
      }
   }
   return best;
}

int PyrNextIndex()
{
   int n = PyrCount();
   int mx = 0;
   for(int i = 0; i < n; i++) if(g_pyrIndex[i] > mx) mx = g_pyrIndex[i];
   return mx + 1;
}

//+------------------------------------------------------------------+
//| Is this pyramid ticket still a live "mine" trading position?     |
//| Runner positions are excluded (pyramid never includes hedges).   |
//+------------------------------------------------------------------+
bool PyrTicketStillActive(ulong ticket)
{
   if(ticket == 0) return false;
   if(!PositionSelectByTicket(ticket)) return false;
   if(!IsMinePosition()) return false;

   long typ = PositionGetInteger(POSITION_TYPE);
   if(typ != POSITION_TYPE_BUY && typ != POSITION_TYPE_SELL) return false;
   if(IsRunner()) return false;

   return true;
}

//+------------------------------------------------------------------+
//| CSV I/O                                                           |
//+------------------------------------------------------------------+
void LoadPyramidFromFile()
{
   PyrClear();
   string fn = PyramidFileName();

   int h = FileOpen(fn, FILE_CSV | FILE_READ | FILE_ANSI);
   if(h == INVALID_HANDLE) return;

   while(!FileIsEnding(h))
   {
      string sTicket = FileReadString(h);
      if(FileIsEnding(h) && (sTicket == "")) break;

      ulong  ticket  = (ulong)StringToInteger(sTicket);
      double trigger = FileReadNumber(h);
      double tp      = FileReadNumber(h);
      double sl      = FileReadNumber(h);
      int    index   = (int)FileReadNumber(h);

      if(ticket > 0) PyrAddOrUpdate(ticket, trigger, tp, sl, index);
   }
   FileClose(h);
}

void SavePyramidToFile()
{
   string fn = PyramidFileName();
   int h = FileOpen(fn, FILE_CSV | FILE_WRITE | FILE_ANSI);
   if(h == INVALID_HANDLE) return;

   // ticket,trigger,tp,sl,index
   for(int i = 0; i < PyrCount(); i++)
   {
      FileWrite(h,
                (long)g_pyrTickets[i],
                DoubleToString(g_pyrTrigger[i], _Digits),
                DoubleToString(g_pyrTP[i],      _Digits),
                DoubleToString(g_pyrSL[i],      _Digits),
                g_pyrIndex[i]);
   }
   FileClose(h);
}

//+------------------------------------------------------------------+
//| Sync memory with terminal: drop closed/invalid, refresh TP/SL.   |
//+------------------------------------------------------------------+
void SyncPyramidWithTerminal()
{
   for(int i = PyrCount() - 1; i >= 0; i--)
   {
      ulong t = g_pyrTickets[i];
      if(!PyrTicketStillActive(t))
      {
         PyrRemoveAt(i);
         continue;
      }
      // PyrTicketStillActive() already selected this position.
      PyrAddOrUpdate(t, g_pyrTrigger[i],
                     PositionGetDouble(POSITION_TP),
                     PositionGetDouble(POSITION_SL),
                     g_pyrIndex[i]);
   }
   g_pyrLastSync = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Apply BE SL to the (last + prev) pair and propagate to all.      |
//| BE is lots-weighted average of the two most-recent adds.          |
//+------------------------------------------------------------------+
void PyramidApplyBE()
{
   if(PyrCount() < 2) return;
   int lastA = PyrLastIdxByIndex();
   int prevA = PyrPrevIdxByIndex(lastA);
   if(lastA < 0 || prevA < 0) return;

   ulong t1 = g_pyrTickets[prevA];
   ulong t2 = g_pyrTickets[lastA];
   if(!PositionSelectByTicket(t1)) return;
   double p1 = PositionGetDouble(POSITION_PRICE_OPEN);
   double l1 = PositionGetDouble(POSITION_VOLUME);
   long   typ = PositionGetInteger(POSITION_TYPE);
   if(!PositionSelectByTicket(t2)) return;
   double p2 = PositionGetDouble(POSITION_PRICE_OPEN);
   double l2 = PositionGetDouble(POSITION_VOLUME);

   double sumLots = l1 + l2;
   if(sumLots <= 0) return;

   double be = (l1 * p1 + l2 * p2) / sumLots;
   if(PyramBEBufPts > 0)
      be += (typ == POSITION_TYPE_BUY ? PyramBEBufPts * _Point : -PyramBEBufPts * _Point);
   be = NormalizePrice(be);

   // Set SL to BE for every pyramid position (TP preserved).
   for(int i = 0; i < PyrCount(); i++)
   {
      ulong t = g_pyrTickets[i];
      double curTP = 0;
      if(PositionSelectByTicket(t))
         curTP = PositionGetDouble(POSITION_TP);
      ModifyPositionSLTP(t, be, curTP);
      // refresh stored TP/SL from terminal
      if(PositionSelectByTicket(t))
         PyrAddOrUpdate(t, g_pyrTrigger[i],
                        PositionGetDouble(POSITION_TP),
                        PositionGetDouble(POSITION_SL),
                        g_pyrIndex[i]);
   }
}

void PyramidSetTPForAll(double tp)
{
   for(int i = 0; i < PyrCount(); i++)
   {
      ulong t = g_pyrTickets[i];
      double sl = 0;
      if(PositionSelectByTicket(t)) sl = PositionGetDouble(POSITION_SL);
      ModifyPositionSLTP(t, sl, tp);
      if(PositionSelectByTicket(t))
         PyrAddOrUpdate(t, g_pyrTrigger[i],
                        PositionGetDouble(POSITION_TP),
                        PositionGetDouble(POSITION_SL),
                        g_pyrIndex[i]);
   }
}

// Pyramid BUILDING keeps TP=0 (MT4 original). Pyramid is scalper-only per
// PLAN §19; scalper is prop-OFF so compliance window doesn't apply.
void PyramidSetTPZeroForAll()
{
   for(int i = 0; i < PyrCount(); i++)
   {
      ulong t = g_pyrTickets[i];
      double sl = 0;
      if(PositionSelectByTicket(t)) sl = PositionGetDouble(POSITION_SL);
      ModifyPositionSLTP(t, sl, 0);
      if(PositionSelectByTicket(t))
         PyrAddOrUpdate(t, g_pyrTrigger[i],
                        PositionGetDouble(POSITION_TP),
                        PositionGetDouble(POSITION_SL),
                        g_pyrIndex[i]);
   }
}

//+------------------------------------------------------------------+
//| Called on tick: manage TP mode (building/coasting) + BE.         |
//+------------------------------------------------------------------+
void PyramidManage()
{
   if(PyramRange <= 0)
   {
      // Pyramid OFF: release positions back to basic TP and clear memory.
      for(int i = PyrCount() - 1; i >= 0; i--)
      {
         ulong t = g_pyrTickets[i];
         if(PositionSelectByTicket(t))
         {
            long   typ = PositionGetInteger(POSITION_TYPE);
            int    dir = (typ == POSITION_TYPE_BUY ? +1 : -1);
            double op  = PositionGetDouble(POSITION_PRICE_OPEN);
            double tp  = (dir > 0 ? op + TP_Points * _Point : op - TP_Points * _Point);
            double sl  = PositionGetDouble(POSITION_SL);
            ModifyPositionSLTP(t, sl, tp);
         }
         PyrRemoveAt(i);
      }
      SavePyramidToFile();

      // Rebuild active series ids from currently open positions (restart-safe)
      SyncSeriesIdsFromOpenOrders();
      return;
   }

   if(PyrCount() <= 0) return;

   // Determine direction from first ticket in the pyramid.
   if(!PositionSelectByTicket(g_pyrTickets[0])) return;
   long firstTyp = PositionGetInteger(POSITION_TYPE);
   int  dir      = (firstTyp == POSITION_TYPE_BUY ? +1 : -1);
   bool slopeOK  = PyramSlopeOKForDir(dir);

   if(PyrCount() == 1)
   {
      if(slopeOK)
      {
         PyramidSetTPZeroForAll();  // BUILDING (single)
      }
      else
      {
         // Release the single position back to basic TP.
         ulong t = g_pyrTickets[0];
         if(PositionSelectByTicket(t))
         {
            double op = PositionGetDouble(POSITION_PRICE_OPEN);
            double tp = (dir > 0 ? op + TP_Points * _Point : op - TP_Points * _Point);
            double sl = PositionGetDouble(POSITION_SL);
            ModifyPositionSLTP(t, sl, tp);
         }
         PyrClear();
         SavePyramidToFile();
      }
      return;
   }

   // PyrCount() > 1
   if(slopeOK)
   {
      PyramidSetTPZeroForAll();         // BUILDING
   }
   else
   {
      // COASTING: set TP of all = trigger of last add.
      int lastA = PyrLastIdxByIndex();
      if(lastA >= 0)
      {
         double commonTP = g_pyrTrigger[lastA];
         PyramidSetTPForAll(commonTP);
      }
   }

   PyramidApplyBE();  // always maintain BE from last+prev
}

//+------------------------------------------------------------------+
//| Decide at open-time whether the current order should be routed  |
//| as a pyramid add. Called by SendOrder (A5.6).                    |
//+------------------------------------------------------------------+
bool PyramidWantsOrder(int dir)
{
   if(PyramRange <= 0) return false;
   if(!PyramSlopeOKForDir(dir)) return false;

   if(PyrCount() > 0)
   {
      if(!PositionSelectByTicket(g_pyrTickets[0])) return false;
      long ft = PositionGetInteger(POSITION_TYPE);
      int existingDir = (ft == POSITION_TYPE_BUY ? +1 : -1);
      if(existingDir != dir) return false;

      int lastA = PyrLastIdxByIndex();
      if(lastA < 0) return false;
      double lastTrigger = g_pyrTrigger[lastA];

      // tolerance: 2 points
      double tol = 2 * _Point;
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      if(dir > 0)
      {
         if(bid + tol < lastTrigger) return false;
      }
      else
      {
         if(ask - tol > lastTrigger) return false;
      }
      return true;
   }

   // first pyramid order
   return true;
}

//+------------------------------------------------------------------+
//| Called right after a pyramid-routed position is opened.          |
//| Registers the ticket + sets TP=0 (BUILDING-phase default) + runs |
//| PyramidApplyBE so SL moves to the weighted BE.                   |
//+------------------------------------------------------------------+
void PyramidOnNewPosition(ulong ticket)
{
   if(ticket == 0) return;
   if(!PositionSelectByTicket(ticket)) return;
   if(!IsMinePosition()) return;
   if(IsRunner()) return;

   long typ = PositionGetInteger(POSITION_TYPE);
   if(typ != POSITION_TYPE_BUY && typ != POSITION_TYPE_SELL) return;
   int dir = (typ == POSITION_TYPE_BUY ? +1 : -1);

   int    idx     = PyrNextIndex();
   double op      = PositionGetDouble(POSITION_PRICE_OPEN);
   double trigger = (dir > 0 ? op + TP_Points * _Point : op - TP_Points * _Point);
   trigger = NormalizePrice(trigger);

   PyrAddOrUpdate(ticket, trigger, 0, PositionGetDouble(POSITION_SL), idx);

   // Ensure TP=0 on the freshly-opened pyramid position (BUILDING default).
   ModifyPositionSLTP(ticket, PositionGetDouble(POSITION_SL), 0);

   PyramidApplyBE();
   SavePyramidToFile();
}

#endif // __MD_PYRAMID_MQH__
