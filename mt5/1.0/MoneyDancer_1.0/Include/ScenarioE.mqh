//+------------------------------------------------------------------+
//| ScenarioE.mqh — hedge "runner" positions + siphon logic          |
//| Phase A5.5                                                       |
//|                                                                   |
//| ScenarioE opens an opposite-direction runner when the losing     |
//| basket hits a guard (EquityGuard / BasketGuard / Strong counter- |
//| trend). As the runner gains profit, part of that profit is       |
//| "siphoned" into partial closes of the worst-loser basket         |
//| position, bleeding down exposure without realizing the full loss.|
//|                                                                   |
//| MT5 port notes:                                                   |
//|  - Runners are identified by RUNNER_TAG prefix in POSITION_COMMENT|
//|  - Siphon trigger now runs off MT5 deal history rather than the  |
//|    MT4 per-tick orders-history scan (see                          |
//|    ScenarioE_ScanNewRunnerClosures).                              |
//|  - SendOrder is forward-declared — defined in Signal.mqh (A5.6). |
//+------------------------------------------------------------------+
#ifndef __MD_SCENARIOE_MQH__
#define __MD_SCENARIOE_MQH__

// Forward declaration — defined in Signal.mqh (A5.6)
bool SendOrder(int dir, double lots, bool useTP, int tpPoints, bool isRunner, string commentText);

//+------------------------------------------------------------------+
//| Runner inventory helpers                                          |
//+------------------------------------------------------------------+
bool HasAnyRunnersOpen()
{
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!IsMinePosition()) continue;
      if(IsRunner()) return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Trailing management for runners: BE once +RunnerBE_StartPts;     |
//| trailing stop at +RunnerTrailDistPts behind price.                |
//|                                                                   |
//| Uses trade.PositionModify directly (not ModifyPositionSLTP)       |
//| because the latter refuses to modify runners.                     |
//+------------------------------------------------------------------+
void ManageRunnersTrailing()
{
   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!IsMinePosition()) continue;
      if(!IsRunner()) continue;

      long typ = PositionGetInteger(POSITION_TYPE);
      if(typ != POSITION_TYPE_BUY && typ != POSITION_TYPE_SELL) continue;

      double op  = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl  = PositionGetDouble(POSITION_SL);
      double tp  = PositionGetDouble(POSITION_TP);

      double cur = (typ == POSITION_TYPE_BUY)
                     ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                     : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      int profitPts = (int)(((typ == POSITION_TYPE_BUY) ? (cur - op) : (op - cur)) / _Point);

      // Stage 1: move SL to BE once profit crosses the start threshold.
      if(profitPts >= RunnerBE_StartPts)
      {
         double beSL = NormalizeDouble(op, _Digits);
         if(typ == POSITION_TYPE_BUY)
         {
            if(sl < beSL - 2 * _Point)
               trade.PositionModify(ticket, beSL, tp);
         }
         else
         {
            if(sl > beSL + 2 * _Point || sl == 0)
               trade.PositionModify(ticket, beSL, tp);
         }
      }

      // Stage 2: trail at RunnerTrailDistPts behind price, stepping in RunnerTrailStepPts chunks.
      if(profitPts >= (RunnerBE_StartPts + RunnerTrailDistPts))
      {
         double newSL = (typ == POSITION_TYPE_BUY)
                           ? cur - RunnerTrailDistPts * _Point
                           : cur + RunnerTrailDistPts * _Point;
         newSL = NormalizeDouble(newSL, _Digits);

         if(typ == POSITION_TYPE_BUY)
         {
            if(newSL > sl + RunnerTrailStepPts * _Point)
               trade.PositionModify(ticket, newSL, tp);
         }
         else
         {
            if(sl == 0 || newSL < sl - RunnerTrailStepPts * _Point)
               trade.PositionModify(ticket, newSL, tp);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Loss per lot on a specific position (0 if not losing).            |
//+------------------------------------------------------------------+
double CurrentLossPerLot(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return 0.0;
   double pl = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   if(pl >= 0) return 0.0;
   double lots = PositionGetDouble(POSITION_VOLUME);
   if(lots <= 0) return 0.0;
   return (-pl) / lots;
}

//+------------------------------------------------------------------+
//| Partially close the worst-loser position in the given direction, |
//| using `budgetMoney` as the cash budget (i.e., how much loss to    |
//| offset). Returns true on a successful partial close.              |
//+------------------------------------------------------------------+
bool ReduceWorstLosingPosition(int dir, double budgetMoney)
{
   if(budgetMoney <= 0) return false;

   ulong  worstTicket = 0;
   double worstPL     = 0;

   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!IsMinePosition()) continue;
      if(IsPyramidTicket(ticket)) continue;
      if(IsRunner()) continue;

      long typ = PositionGetInteger(POSITION_TYPE);
      if(dir > 0 && typ != POSITION_TYPE_BUY)  continue;
      if(dir < 0 && typ != POSITION_TYPE_SELL) continue;

      double pl = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      if(pl < worstPL)
      {
         worstPL     = pl;
         worstTicket = ticket;
      }
   }

   if(worstTicket == 0) return false;
   if(!PositionSelectByTicket(worstTicket)) return false;

   double lots = PositionGetDouble(POSITION_VOLUME);
   if(lots <= MinPartialCloseLot) return false;

   double lossPerLot = CurrentLossPerLot(worstTicket);
   if(lossPerLot <= 0) return false;

   double closeLots = budgetMoney / lossPerLot;
   if(closeLots < MinPartialCloseLot) closeLots = MinPartialCloseLot;
   if(closeLots > lots / 2.0) closeLots = lots / 2.0;

   closeLots = ClampLot(closeLots);
   if(closeLots < MinPartialCloseLot) return false;

   return trade.PositionClosePartial(worstTicket, closeLots);
}

//+------------------------------------------------------------------+
//| Decide whether ScenarioE should activate (and why).              |
//+------------------------------------------------------------------+
bool CheckShouldActivateE(int basketDir, string &reason)
{
   if(!ScenarioE) { reason = ""; return false; }

   if(EquityGuardTriggered())
   {
      reason = "EQUITY DD > " + DoubleToString(MaxEquityDD_Pct, 1) + "%";
      return true;
   }

   if(BasketGuardTriggered(basketDir))
   {
      reason = "BASKET DD > " + DoubleToString(MaxBasketDD_Pct, 1) + "%";
      return true;
   }

   if(TrendBlocksD(basketDir))
   {
      reason = "STRONG COUNTER-TREND";
      return true;
   }

   reason = "";
   return false;
}

//+------------------------------------------------------------------+
//| Open a runner opposite to the losing basket. Uses SendOrder      |
//| (forward-declared — defined in Signal.mqh).                       |
//+------------------------------------------------------------------+
void TryOpenRunner(int losingBasketDir, string reason)
{
   if(!ScenarioE) return;

   int hedgeDir = -losingBasketDir;  // runner is OPPOSITE to the losing basket

   double losingLots = SumLotsDir(losingBasketDir, false);
   if(losingLots <= 0) return;

   double runnersLots = SumRunnerLotsDir(hedgeDir);
   double maxAllowed  = losingLots * HedgeRatio;
   if(runnersLots >= maxAllowed) return;

   double remaining = maxAllowed - runnersLots;
   double lot = MathMin(LotsBase, remaining);
   lot = ClampLot(lot);
   if(lot <= 0) return;

   int    sid       = CurrentSeriesId(losingBasketDir);
   string seriesCmt = SeriesKey(losingBasketDir, sid);
   string cmt       = "HEDGE_" + seriesCmt;

   // Runner opens with a realistic hedge TP (BE-start + trail-distance).
   // Trailing SL typically closes first; TP acts as audit-visible target.
   int runnerTPPts = RunnerBE_StartPts + RunnerTrailDistPts;
   bool opened = SendOrder(hedgeDir, lot, true, runnerTPPts, true, cmt);

   if(opened)
   {
      g_scenarioEActive  = true;
      g_hedgeBasketDir   = losingBasketDir;
      g_hedgeReason      = reason;
      if(g_scenarioEStartTime == 0) g_scenarioEStartTime = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Refresh scenario E status + dashboard counters.                  |
//+------------------------------------------------------------------+
void UpdateScenarioEState()
{
   g_activeRunnersCount = 0;
   g_hedgeLotsTotal     = 0;

   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!IsMinePosition()) continue;
      if(!IsRunner()) continue;

      g_activeRunnersCount++;
      g_hedgeLotsTotal += PositionGetDouble(POSITION_VOLUME);
   }

   double buyLots  = SumLotsDir(+1, false);
   double sellLots = SumLotsDir(-1, false);

   if(g_activeRunnersCount > 0)
   {
      g_scenarioEActive = true;

      // Runner direction is OPPOSITE to the hedged basket.
      for(int j = total - 1; j >= 0; j--)
      {
         ulong ticket = PositionGetTicket(j);
         if(ticket == 0) continue;
         if(!IsMinePosition()) continue;
         if(!IsRunner()) continue;

         long typ = PositionGetInteger(POSITION_TYPE);
         int runnerDir     = (typ == POSITION_TYPE_BUY ? +1 : -1);
         g_hedgeBasketDir  = -runnerDir;
         break;
      }

      g_basketLotsTotal = (g_hedgeBasketDir > 0 ? buyLots : sellLots);
      g_scenarioStatus  = "E";
   }
   else
   {
      if(buyLots > 0 || sellLots > 0) g_scenarioStatus = "D";
      else                            g_scenarioStatus = "IDLE";

      if(g_scenarioEActive && g_activeRunnersCount == 0)
      {
         g_scenarioEActive    = false;
         g_hedgeBasketDir     = 0;
         g_hedgeReason        = "";
         g_scenarioEStartTime = 0;
      }
   }
}

//+------------------------------------------------------------------+
//| Scan for newly-closed runner deals and siphon their profit into  |
//| partial closes on the losing basket. Replaces the MT4 per-tick   |
//| scan embedded in ScanHistoryNewAndUpdatePnLAndMarkers.            |
//+------------------------------------------------------------------+
void ScenarioE_ScanNewRunnerClosures()
{
   if(!ScenarioE) return;

   // Load the past 24h of deal history (cheap; MT5 caches internally).
   datetime from = TimeCurrent() - 86400;
   HistorySelect(from, TimeCurrent());
   int totalDeals = HistoryDealsTotal();

   if(totalDeals <= g_lastDealsCount)
   {
      g_lastDealsCount = totalDeals;  // keep in sync when count shrinks (new session)
      return;
   }

   for(int i = g_lastDealsCount; i < totalDeals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;

      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL)  != _Symbol) continue;
      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != (long)Magic) continue;

      // Only react to CLOSING deals (DEAL_ENTRY_OUT).
      long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT) continue;

      string cmt = HistoryDealGetString(dealTicket, DEAL_COMMENT);
      if(StringFind(cmt, RUNNER_TAG, 0) < 0) continue;

      double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                    + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
                    + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
      if(profit <= 0) continue;

      // DEAL_TYPE for a closing deal is OPPOSITE of the position type.
      //   closing a BUY position → DEAL_TYPE_SELL → runner was +1
      //   closing a SELL position → DEAL_TYPE_BUY  → runner was -1
      long dealType = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
      int runnerDir       = (dealType == DEAL_TYPE_SELL ? +1 : -1);
      int losingBasketDir = -runnerDir;

      ReduceWorstLosingPosition(losingBasketDir, profit * SiphonPct);
   }

   g_lastDealsCount = totalDeals;
}

#endif // __MD_SCENARIOE_MQH__
