//+------------------------------------------------------------------+
//| Orders.mqh — trade primitives built on CTrade                    |
//| Phase A4: thin wrappers around CTrade.                           |
//|                                                                   |
//| High-level SendOrder (with pyramid routing, markers, timing) is  |
//| built in A5 on top of these primitives.                          |
//|                                                                   |
//| MT5 semantic adaptations vs MT4:                                  |
//|  - OrderSend() → trade.PositionOpen()                             |
//|  - OrderModify() → trade.PositionModify()                         |
//|  - OrderClose() → trade.PositionClose()                           |
//|  - Iteration: OrdersTotal+OrderSelect(MODE_TRADES) → PositionsTotal+PositionGetTicket
//|  - OrderProfit+OrderSwap+OrderCommission → POSITION_PROFIT+POSITION_SWAP  |
//|    (commission lives on DEALS, not positions; for an open position    |
//|    the marked-to-market profit is already net of spread, and commission|
//|    is charged on close — PROFIT+SWAP is the correct "running P&L")    |
//|  - MODE_STOPLEVEL → SYMBOL_TRADE_STOPS_LEVEL                      |
//+------------------------------------------------------------------+
#ifndef __MD_ORDERS_MQH__
#define __MD_ORDERS_MQH__

//+------------------------------------------------------------------+
//| Global CTrade instance — used by all modules.                    |
//| Initialized once in OrdersInit() (called from OnInit).           |
//+------------------------------------------------------------------+
CTrade trade;

void OrdersInit()
{
   trade.SetExpertMagicNumber((ulong)Magic);
   trade.SetDeviationInPoints((ulong)Slippage);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetAsyncMode(false);
   trade.LogLevel(LOG_LEVEL_ERRORS);  // quiet normal operation, log only errors
}

//+------------------------------------------------------------------+
//| Price / volume normalization helpers                              |
//+------------------------------------------------------------------+
double NormalizePrice(double p) { return NormalizeDouble(p, _Digits); }

//+------------------------------------------------------------------+
//| Open a position. Returns the position ticket (ulong) on success, |
//| 0 on failure. Caller is responsible for pyramid routing,         |
//| markers, and timing globals — this is a thin primitive.          |
//+------------------------------------------------------------------+
ulong OpenPosition(int dir, double lots, double sl, double tp, string comment)
{
   ENUM_ORDER_TYPE order_type;
   double price;
   if(dir > 0)
   {
      order_type = ORDER_TYPE_BUY;
      price      = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   }
   else
   {
      order_type = ORDER_TYPE_SELL;
      price      = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   }

   if(sl > 0) sl = NormalizePrice(sl);
   if(tp > 0) tp = NormalizePrice(tp);

   if(!trade.PositionOpen(_Symbol, order_type, lots, price, sl, tp, comment))
      return 0;

   // Resolve the new position's ticket. For hedging-mode instant-execution
   // brokers, ResultOrder() equals the position ticket. If not, fall back
   // to the deal lookup.
   ulong order_ticket = trade.ResultOrder();
   if(order_ticket > 0 && PositionSelectByTicket(order_ticket))
      return order_ticket;

   ulong deal_ticket = trade.ResultDeal();
   if(deal_ticket > 0 && HistoryDealSelect(deal_ticket))
      return (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);

   return 0;
}

//+------------------------------------------------------------------+
//| Modify SL/TP on a position, respecting the symbol's stop level.  |
//| Returns true when the modification was applied (or was unneeded).|
//+------------------------------------------------------------------+
bool ModifyPositionSLTP(ulong ticket, double newSL, double newTP)
{
   if(!PositionSelectByTicket(ticket)) return false;
   if(!IsMinePosition()) return false;
   if(IsRunner()) return false;

   long typ = PositionGetInteger(POSITION_TYPE);
   if(typ != POSITION_TYPE_BUY && typ != POSITION_TYPE_SELL) return false;

   double curSL = PositionGetDouble(POSITION_SL);
   double curTP = PositionGetDouble(POSITION_TP);

   // Stop-level guard — MT5 equivalent of MT4 MODE_STOPLEVEL
   int    stopLvlPts = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double cur        = (typ == POSITION_TYPE_BUY)
                         ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   if(newSL > 0)
   {
      if(typ == POSITION_TYPE_BUY)
      {
         double minSL = cur - stopLvlPts * _Point;
         if(newSL > minSL) newSL = minSL;
      }
      else
      {
         double maxSL = cur + stopLvlPts * _Point;
         if(newSL < maxSL) newSL = maxSL;
      }
      newSL = NormalizePrice(newSL);
   }
   if(newTP > 0)
   {
      if(typ == POSITION_TYPE_BUY)
      {
         double minTP = cur + stopLvlPts * _Point;
         if(newTP < minTP) newTP = minTP;
      }
      else
      {
         double maxTP = cur - stopLvlPts * _Point;
         if(newTP > maxTP) newTP = maxTP;
      }
      newTP = NormalizePrice(newTP);
   }

   // Skip modify if not meaningfully different (< 2 points delta on either side)
   bool need = false;
   if((newSL == 0 && curSL != 0) || (newSL > 0 && MathAbs(curSL - newSL) > (2 * _Point))) need = true;
   if((newTP == 0 && curTP != 0) || (newTP > 0 && MathAbs(curTP - newTP) > (2 * _Point))) need = true;
   if(!need) return true;

   return trade.PositionModify(ticket, newSL, newTP);
}

//+------------------------------------------------------------------+
//| Close a specific position by ticket.                              |
//+------------------------------------------------------------------+
bool ClosePosition(ulong ticket)
{
   return trade.PositionClose(ticket);
}

//+------------------------------------------------------------------+
//| Close all "mine" positions (both directions).                    |
//| Returns count of successfully closed positions.                   |
//+------------------------------------------------------------------+
int CloseAllPositions()
{
   int closed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!IsMinePosition()) continue;

      long typ = PositionGetInteger(POSITION_TYPE);
      if(typ != POSITION_TYPE_BUY && typ != POSITION_TYPE_SELL) continue;

      if(trade.PositionClose(ticket)) closed++;
   }
   return closed;
}

//+------------------------------------------------------------------+
//| Close all "mine" positions matching the given type               |
//| (POSITION_TYPE_BUY or POSITION_TYPE_SELL).                        |
//+------------------------------------------------------------------+
int CloseAllPositionsType(ENUM_POSITION_TYPE posType)
{
   int closed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!IsMinePosition()) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != posType) continue;

      if(trade.PositionClose(ticket)) closed++;
   }
   return closed;
}

//+------------------------------------------------------------------+
//| Close only profitable positions of the given type.               |
//| Profit = POSITION_PROFIT + POSITION_SWAP (commission is on       |
//| deals, not live positions — see header comment).                  |
//+------------------------------------------------------------------+
int CloseProfitPositions(ENUM_POSITION_TYPE posType)
{
   int closed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!IsMinePosition()) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != posType) continue;

      double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      if(profit <= 0) continue;

      if(trade.PositionClose(ticket)) closed++;
   }
   return closed;
}

#endif // __MD_ORDERS_MQH__
