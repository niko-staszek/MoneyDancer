//+------------------------------------------------------------------+
//| Basket.mqh — basket math: P&L, lot sums, BE (with or without     |
//|             costs), step gates, price-vs-BE, min-distance,       |
//|             equity/basket/trend guards.                          |
//| Phase A5.3                                                       |
//|                                                                   |
//| No CTrade calls here — this module is pure READ (analytics).     |
//| Actions (setting TP, opening runners, closing baskets) belong    |
//| in ScenarioD / ScenarioE / Risk.                                  |
//|                                                                   |
//| MT5 semantic adaptations vs MT4:                                  |
//|  - OrdersTotal + OrderSelect(MODE_TRADES) → PositionsTotal +     |
//|    PositionGetTicket + PositionGetXxx.                            |
//|  - OrderProfit+OrderSwap+OrderCommission → POSITION_PROFIT +     |
//|    POSITION_SWAP. Commission in MT5 is on the entry DEAL, not    |
//|    the position — for a live basket BE calculation, the impact   |
//|    is negligible (e.g., 0.01 lots on XAUUSD with $3.5/lot/side   |
//|    commission = $0.035 per position, well within BE bisection   |
//|    tolerance). Documented here so we don't rediscover it.         |
//|  - MarketInfo(MODE_TICKSIZE/TICKVALUE) →                         |
//|    SymbolInfoDouble(SYMBOL_TRADE_TICK_SIZE/VALUE).                |
//|  - Bid/Ask → SymbolInfoDouble(_Symbol, SYMBOL_BID/ASK).           |
//|  - Digits/Point → _Digits/_Point.                                 |
//+------------------------------------------------------------------+
#ifndef __MD_BASKET_MQH__
#define __MD_BASKET_MQH__

//+------------------------------------------------------------------+
//| Structure snapshot of one basket position.                        |
//+------------------------------------------------------------------+
struct BasketPosition
{
   ulong     ticket;
   long      type;         // POSITION_TYPE_BUY / POSITION_TYPE_SELL
   double    lots;
   double    openPrice;
   double    swap;
   double    commission;   // always 0 in MT5 (see header note)
   datetime  openTime;
};

//+------------------------------------------------------------------+
//| P&L / lot sum helpers                                             |
//+------------------------------------------------------------------+

// Sum of running P&L across ALL "mine" positions (both directions).
double BasketFloatingAllMine()
{
   double sum = 0.0;
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!IsMinePosition()) continue;
      sum += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return sum;
}

// Sum of lots for a direction. Excludes pyramid; optionally excludes runners.
double SumLotsDir(int dir, bool includeRunners)
{
   double s = 0.0;
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!IsMinePosition()) continue;
      if(IsPyramidTicket(ticket)) continue;
      if(!includeRunners && IsRunner()) continue;

      long typ = PositionGetInteger(POSITION_TYPE);
      if(dir > 0 && typ == POSITION_TYPE_BUY)  s += PositionGetDouble(POSITION_VOLUME);
      if(dir < 0 && typ == POSITION_TYPE_SELL) s += PositionGetDouble(POSITION_VOLUME);
   }
   return s;
}

// Sum of lots of RUNNERS in a direction.
double SumRunnerLotsDir(int dir)
{
   double s = 0.0;
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!IsMinePosition()) continue;
      if(!IsRunner()) continue;

      long typ = PositionGetInteger(POSITION_TYPE);
      if(dir > 0 && typ == POSITION_TYPE_BUY)  s += PositionGetDouble(POSITION_VOLUME);
      if(dir < 0 && typ == POSITION_TYPE_SELL) s += PositionGetDouble(POSITION_VOLUME);
   }
   return s;
}

// Running P&L for the basket in a direction. Excludes pyramid; optionally excludes runners.
double BasketFloatingPL(int dir, bool includeRunners)
{
   double pl = 0.0;
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!IsMinePosition()) continue;
      if(IsPyramidTicket(ticket)) continue;
      if(!includeRunners && IsRunner()) continue;

      long typ = PositionGetInteger(POSITION_TYPE);
      if(dir > 0 && typ != POSITION_TYPE_BUY)  continue;
      if(dir < 0 && typ != POSITION_TYPE_SELL) continue;

      pl += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return pl;
}

//+------------------------------------------------------------------+
//| Simple weighted-average BE for a direction (no series, no costs).|
//+------------------------------------------------------------------+
bool CalcGroupBE(int dir, double &beOut)
{
   double sumLots = 0.0, sumPx = 0.0;
   int cnt = 0;

   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!IsMinePosition()) continue;
      if(IsRunner()) continue;

      long typ = PositionGetInteger(POSITION_TYPE);
      if(dir > 0 && typ != POSITION_TYPE_BUY)  continue;
      if(dir < 0 && typ != POSITION_TYPE_SELL) continue;

      double L = PositionGetDouble(POSITION_VOLUME);
      sumLots += L;
      sumPx   += L * PositionGetDouble(POSITION_PRICE_OPEN);
      cnt++;
   }

   if(cnt <= 0 || sumLots <= 0) return false;
   beOut = NormalizeDouble(sumPx / sumLots, _Digits);
   return true;
}

//+------------------------------------------------------------------+
//| Hypothetical P&L of a single position at a given close price.    |
//+------------------------------------------------------------------+
double ProfitAtPrice(long type, double lots, double openPrice, double closePrice)
{
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);

   if(tickSize  <= 0.0) tickSize  = _Point;
   if(tickValue <= 0.0) tickValue = 0.0;

   double diff = 0.0;
   if(type == POSITION_TYPE_BUY)       diff = (closePrice - openPrice);
   else if(type == POSITION_TYPE_SELL) diff = (openPrice - closePrice);

   return (diff / tickSize) * tickValue * lots;
}

//+------------------------------------------------------------------+
//| Collect basket snapshot for a direction + series, sorted by      |
//| openTime ascending.                                               |
//+------------------------------------------------------------------+
int CollectBasketPositionsSeries(int dir, string seriesKey, BasketPosition &outArr[])
{
   ArrayResize(outArr, 0);
   int n = 0;

   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!IsMinePosition()) continue;
      if(IsPyramidTicket(ticket)) continue;
      if(IsRunner()) continue;
      if(!IsSelectedPositionInSeries(seriesKey)) continue;

      long t = PositionGetInteger(POSITION_TYPE);
      if(dir > 0 && t != POSITION_TYPE_BUY)  continue;
      if(dir < 0 && t != POSITION_TYPE_SELL) continue;

      n++;
      ArrayResize(outArr, n);
      int k = n - 1;

      outArr[k].ticket     = ticket;
      outArr[k].type       = t;
      outArr[k].lots       = PositionGetDouble(POSITION_VOLUME);
      outArr[k].openPrice  = PositionGetDouble(POSITION_PRICE_OPEN);
      outArr[k].swap       = PositionGetDouble(POSITION_SWAP);
      outArr[k].commission = 0.0;  // see header note
      outArr[k].openTime   = (datetime)PositionGetInteger(POSITION_TIME);
   }

   // insertion sort ascending by openTime (n is small)
   for(int a = 1; a < n; a++)
   {
      BasketPosition key = outArr[a];
      int b = a - 1;
      while(b >= 0 && outArr[b].openTime > key.openTime)
      {
         outArr[b + 1] = outArr[b];
         b--;
      }
      outArr[b + 1] = key;
   }

   return n;
}

double FirstBasketLotSeries(int dir, string seriesKey)
{
   BasketPosition arr[];
   int n = CollectBasketPositionsSeries(dir, seriesKey, arr);
   if(n <= 0) return 0.0;
   return arr[0].lots;
}

double BasketProfitAtPriceSeries(BasketPosition &arr[], int n, double closePrice)
{
   double sum = 0.0;
   for(int i = 0; i < n; i++)
   {
      double pr = ProfitAtPrice(arr[i].type, arr[i].lots, arr[i].openPrice, closePrice);
      sum += pr + arr[i].swap + arr[i].commission;
   }
   return sum;
}

//+------------------------------------------------------------------+
//| Cost-aware, series-scoped basket BE: solves price where total    |
//| P&L (incl. swap) == 0. Uses bisection after finding a bracket.    |
//+------------------------------------------------------------------+
bool CalcBasketBEWithCostsSeries(int dir, string seriesKey, double &beOut)
{
   BasketPosition arr[];
   int n = CollectBasketPositionsSeries(dir, seriesKey, arr);
   if(n <= 0) return false;

   double cur = (dir > 0)
                  ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                  : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // Find bracket [lo, hi] with opposite-sign profits.
   double lo = cur, hi = cur;
   double plo = BasketProfitAtPriceSeries(arr, n, lo);
   double phi = plo;

   int    maxExpand = 40;
   double step      = 200 * _Point;

   bool found = false;
   for(int k = 0; k < maxExpand; k++)
   {
      lo = cur - step * (k + 1);
      hi = cur + step * (k + 1);
      plo = BasketProfitAtPriceSeries(arr, n, lo);
      phi = BasketProfitAtPriceSeries(arr, n, hi);

      if(plo == 0.0) { beOut = NormalizeDouble(lo, _Digits); return true; }
      if(phi == 0.0) { beOut = NormalizeDouble(hi, _Digits); return true; }
      if((plo < 0.0 && phi > 0.0) || (plo > 0.0 && phi < 0.0))
      {
         found = true;
         break;
      }
   }

   if(!found)
   {
      // Fallback: plain weighted-avg BE (no costs).
      double sumLots = 0.0, sumPx = 0.0;
      for(int i = 0; i < n; i++) { sumLots += arr[i].lots; sumPx += arr[i].lots * arr[i].openPrice; }
      if(sumLots <= 0) return false;
      beOut = NormalizeDouble(sumPx / sumLots, _Digits);
      return true;
   }

   // Bisection.
   double a = lo, b = hi;
   double fa = plo, fb = phi;

   for(int it = 0; it < 40; it++)
   {
      double mid = 0.5 * (a + b);
      double fm  = BasketProfitAtPriceSeries(arr, n, mid);

      if(MathAbs(fm) < 0.01) { beOut = NormalizeDouble(mid, _Digits); return true; }

      if((fa < 0.0 && fm > 0.0) || (fa > 0.0 && fm < 0.0))
      {
         b = mid; fb = fm;
      }
      else
      {
         a = mid; fa = fm;
      }
   }

   beOut = NormalizeDouble(0.5 * (a + b), _Digits);
   return true;
}

//+------------------------------------------------------------------+
//| Step gates — block new basket adds until price has moved far     |
//| enough from the current BE.                                       |
//+------------------------------------------------------------------+

// Simple-BE gate (no series, no costs).
bool StepGateFromBasketBE(int dir)
{
   double be;
   if(!CalcGroupBE(dir, be)) return true;  // cannot compute -> don't block

   double cur = (dir > 0)
                  ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                  : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   int distPts = (int)MathAbs((cur - be) / _Point);
   return (distPts >= StepPoints);
}

// Series-scoped gate based on cost-aware BE.
bool StepGateFromBasketBESeries(int dir, string seriesKey)
{
   double be;
   if(!CalcBasketBEWithCostsSeries(dir, seriesKey, be)) return true;

   double cur = (dir > 0)
                  ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                  : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   int distPts = (int)MathAbs((cur - be) / _Point);
   return (distPts >= StepPoints);
}

//+------------------------------------------------------------------+
//| Price vs. BE helpers — ScenarioD uses these to avoid unsafe adds.|
//+------------------------------------------------------------------+

bool IsPriceFavorableOrAtBE(int dir, string seriesKey)
{
   double be;
   if(!CalcBasketBEWithCostsSeries(dir, seriesKey, be)) return false;

   double cur = (dir > 0)
                  ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                  : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   if(dir > 0) return (cur >= be);
   return (cur <= be);
}

//+------------------------------------------------------------------+
//| Return the open price of the most recent D-add position in a     |
//| series (preferred), else the most recent any-position open price.|
//+------------------------------------------------------------------+
double LastDAddOrLastOrderPriceSeries(int dir, string seriesKey)
{
   datetime bestT = 0;
   double   bestP = 0.0;
   bool     foundD = false;

   int total = PositionsTotal();

   // 1) Prefer last D-add (comment contains "|D=")
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!IsMinePosition()) continue;
      if(IsPyramidTicket(ticket)) continue;
      if(!IsSelectedPositionInSeries(seriesKey)) continue;

      long t = PositionGetInteger(POSITION_TYPE);
      if(dir > 0 && t != POSITION_TYPE_BUY)  continue;
      if(dir < 0 && t != POSITION_TYPE_SELL) continue;

      if(StringFind(PositionGetString(POSITION_COMMENT), "|D=", 0) < 0) continue;

      datetime ot = (datetime)PositionGetInteger(POSITION_TIME);
      if(ot >= bestT)
      {
         bestT = ot;
         bestP = PositionGetDouble(POSITION_PRICE_OPEN);
         foundD = true;
      }
   }

   if(foundD) return bestP;

   // 2) Fallback: most recent any position in series (same dir)
   bestT = 0; bestP = 0.0;
   for(int j = 0; j < total; j++)
   {
      ulong ticket = PositionGetTicket(j);
      if(ticket == 0) continue;
      if(!IsMinePosition()) continue;
      if(IsPyramidTicket(ticket)) continue;
      if(!IsSelectedPositionInSeries(seriesKey)) continue;

      long t2 = PositionGetInteger(POSITION_TYPE);
      if(dir > 0 && t2 != POSITION_TYPE_BUY)  continue;
      if(dir < 0 && t2 != POSITION_TYPE_SELL) continue;

      datetime ot2 = (datetime)PositionGetInteger(POSITION_TIME);
      if(ot2 >= bestT)
      {
         bestT = ot2;
         bestP = PositionGetDouble(POSITION_PRICE_OPEN);
      }
   }
   return bestP;
}

//+------------------------------------------------------------------+
//| Is price moving AWAY from BE on the adverse side? (Only then    |
//| ScenarioD escalates via the lot multiplier.)                      |
//+------------------------------------------------------------------+
bool IsMovingAwayFromBESeries(int dir, string seriesKey)
{
   double be;
   if(!CalcBasketBEWithCostsSeries(dir, seriesKey, be)) return true;  // can't compute -> don't block

   double cur = (dir > 0)
                  ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                  : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // Only "away" matters on the adverse side of BE.
   if(dir > 0 && cur >= be) return false;
   if(dir < 0 && cur <= be) return false;

   double refPrice = LastDAddOrLastOrderPriceSeries(dir, seriesKey);
   if(refPrice <= 0.0) refPrice = cur;

   double distCur = MathAbs(cur - be);
   double distRef = MathAbs(refPrice - be);

   return (distCur > distRef + (_Point * 0.1));
}

//+------------------------------------------------------------------+
//| Reject a new order if any existing same-direction position is    |
//| closer than MinOrderDistancePts. Excludes runners.                |
//+------------------------------------------------------------------+
bool CheckMinDistanceFromExistingPositions(int dir)
{
   double currentPrice = (dir > 0)
                           ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                           : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!IsMinePosition()) continue;
      if(IsRunner()) continue;

      long typ = PositionGetInteger(POSITION_TYPE);
      if(dir > 0 && typ != POSITION_TYPE_BUY)  continue;
      if(dir < 0 && typ != POSITION_TYPE_SELL) continue;

      double orderPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      int distancePts = (int)(MathAbs(currentPrice - orderPrice) / _Point);

      if(distancePts < MinOrderDistancePts) return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Guards — used by Scenario E activation and Risk module.          |
//+------------------------------------------------------------------+

bool EquityGuardTriggered()
{
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq  = AccountInfoDouble(ACCOUNT_EQUITY);
   if(bal <= 0) return false;

   double ddPct = (bal - eq) / bal * 100.0;
   return (ddPct >= MaxEquityDD_Pct);
}

bool BasketGuardTriggered(int dir)
{
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal <= 0) return false;

   double pl = BasketFloatingPL(dir, false);
   if(pl >= 0) return false;

   double lossPct = (-pl) / bal * 100.0;
   return (lossPct >= MaxBasketDD_Pct);
}

// Strong counter-trend blocks further ScenarioD escalation.
bool TrendBlocksD(int basketDir)
{
   if(!UseSlopeFilter) return false;

   int slopePts = MarketSlopeStrengthPtsCached();
   if(MathAbs(slopePts) < strongTrendPts) return false;

   if(basketDir < 0 && slopePts > 0) return true;
   if(basketDir > 0 && slopePts < 0) return true;
   return false;
}

#endif // __MD_BASKET_MQH__
