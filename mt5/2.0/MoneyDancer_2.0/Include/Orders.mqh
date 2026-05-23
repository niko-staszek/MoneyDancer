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
//| PL.2 — broker-realism error handling                              |
//|                                                                   |
//| Decodes MT5 trade retcodes into human-readable strings and        |
//| classifies them as RETRYABLE (transient quote issues — worth      |
//| trying again next tick) vs TERMINAL (broker rejects the action — |
//| no point retrying).                                                |
//+------------------------------------------------------------------+
string TradeRetcodeString(uint code)
{
   switch(code)
   {
      case TRADE_RETCODE_DONE:                return "DONE";
      case TRADE_RETCODE_DONE_PARTIAL:        return "DONE_PARTIAL";
      case TRADE_RETCODE_PLACED:              return "PLACED";
      case TRADE_RETCODE_REQUOTE:             return "REQUOTE";
      case TRADE_RETCODE_REJECT:              return "REJECT";
      case TRADE_RETCODE_CANCEL:              return "CANCEL";
      case TRADE_RETCODE_ERROR:               return "ERROR";
      case TRADE_RETCODE_TIMEOUT:             return "TIMEOUT";
      case TRADE_RETCODE_INVALID:             return "INVALID";
      case TRADE_RETCODE_INVALID_VOLUME:      return "INVALID_VOLUME";
      case TRADE_RETCODE_INVALID_PRICE:       return "INVALID_PRICE";
      case TRADE_RETCODE_INVALID_STOPS:       return "INVALID_STOPS";
      case TRADE_RETCODE_TRADE_DISABLED:      return "TRADE_DISABLED";
      case TRADE_RETCODE_MARKET_CLOSED:       return "MARKET_CLOSED";
      case TRADE_RETCODE_NO_MONEY:            return "NO_MONEY";
      case TRADE_RETCODE_PRICE_CHANGED:       return "PRICE_CHANGED";
      case TRADE_RETCODE_PRICE_OFF:           return "PRICE_OFF";
      case TRADE_RETCODE_INVALID_EXPIRATION:  return "INVALID_EXPIRATION";
      case TRADE_RETCODE_ORDER_CHANGED:       return "ORDER_CHANGED";
      case TRADE_RETCODE_TOO_MANY_REQUESTS:   return "TOO_MANY_REQUESTS";
      case TRADE_RETCODE_NO_CHANGES:          return "NO_CHANGES";
      case TRADE_RETCODE_SERVER_DISABLES_AT:  return "SERVER_DISABLES_AT";
      case TRADE_RETCODE_CLIENT_DISABLES_AT:  return "CLIENT_DISABLES_AT";
      case TRADE_RETCODE_LOCKED:              return "LOCKED";
      case TRADE_RETCODE_FROZEN:              return "FROZEN";
      case TRADE_RETCODE_INVALID_FILL:        return "INVALID_FILL";
      case TRADE_RETCODE_CONNECTION:          return "CONNECTION";
      case TRADE_RETCODE_ONLY_REAL:           return "ONLY_REAL";
      case TRADE_RETCODE_LIMIT_ORDERS:        return "LIMIT_ORDERS";
      case TRADE_RETCODE_LIMIT_VOLUME:        return "LIMIT_VOLUME";
      case TRADE_RETCODE_INVALID_ORDER:       return "INVALID_ORDER";
      case TRADE_RETCODE_POSITION_CLOSED:     return "POSITION_CLOSED";
      case TRADE_RETCODE_INVALID_CLOSE_VOLUME:return "INVALID_CLOSE_VOLUME";
      case TRADE_RETCODE_CLOSE_ORDER_EXIST:   return "CLOSE_ORDER_EXIST";
      case TRADE_RETCODE_LIMIT_POSITIONS:     return "LIMIT_POSITIONS";
      case TRADE_RETCODE_REJECT_CANCEL:       return "REJECT_CANCEL";
      case TRADE_RETCODE_LONG_ONLY:           return "LONG_ONLY";
      case TRADE_RETCODE_SHORT_ONLY:          return "SHORT_ONLY";
      case TRADE_RETCODE_CLOSE_ONLY:          return "CLOSE_ONLY";
      case TRADE_RETCODE_FIFO_CLOSE:          return "FIFO_CLOSE";
      default:                                return StringFormat("CODE_%u", code);
   }
}

// Retryable: transient quote issues; the rail's per-tick retry will resolve.
// Terminal: broker rejects the action; no point retrying, surface to operator.
bool IsRetcodeRetryable(uint code)
{
   switch(code)
   {
      case TRADE_RETCODE_REQUOTE:
      case TRADE_RETCODE_PRICE_CHANGED:
      case TRADE_RETCODE_PRICE_OFF:
      case TRADE_RETCODE_TIMEOUT:
      case TRADE_RETCODE_TOO_MANY_REQUESTS:
      case TRADE_RETCODE_CONNECTION:
      case TRADE_RETCODE_NO_CHANGES:        // unchanged value — caller should skip
         return true;
      default:
         return false;
   }
}

// Terminal errors that should pause the EA — broker says this account can't trade.
bool IsRetcodeTerminal(uint code)
{
   switch(code)
   {
      case TRADE_RETCODE_TRADE_DISABLED:
      case TRADE_RETCODE_NO_MONEY:
      case TRADE_RETCODE_SERVER_DISABLES_AT:
      case TRADE_RETCODE_CLIENT_DISABLES_AT:
      case TRADE_RETCODE_LIMIT_POSITIONS:
      case TRADE_RETCODE_LIMIT_VOLUME:
      case TRADE_RETCODE_LIMIT_ORDERS:
         return true;
      default:
         return false;
   }
}

// Log a trade failure with context.  Caller passes operation name and any
// helpful state. Result includes retcode + comment + last_error for
// post-mortem.
void LogTradeFailure(string op, ulong ticket = 0)
{
   uint   rc       = trade.ResultRetcode();
   string rcStr    = TradeRetcodeString(rc);
   string rcComm   = trade.ResultComment();
   int    lastErr  = GetLastError();
   PrintFormat("[PL.2] trade.%s FAIL ticket=%I64u retcode=%u(%s) comment=%s last_err=%d",
               op, ticket, rc, rcStr, rcComm, lastErr);
   if(IsRetcodeTerminal(rc))
      PrintFormat("[PL.2] TERMINAL retcode %s — broker rejects this action. Operator should investigate.", rcStr);
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
   {
      LogTradeFailure("PositionOpen");
      return 0;
   }

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

   if(!trade.PositionModify(ticket, newSL, newTP))
   {
      uint rc = trade.ResultRetcode();
      // NO_CHANGES is benign — caller asked to set the value we already had.
      if(rc != TRADE_RETCODE_NO_CHANGES)
         LogTradeFailure("PositionModify", ticket);
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Close a specific position by ticket.                              |
//+------------------------------------------------------------------+
bool ClosePosition(ulong ticket)
{
   if(!trade.PositionClose(ticket))
   {
      uint rc = trade.ResultRetcode();
      // POSITION_CLOSED and MARKET_CLOSED are expected during certain windows — log at DEBUG level
      // (but still log so we have audit trail).
      LogTradeFailure("PositionClose", ticket);
      return false;
   }
   return true;
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
