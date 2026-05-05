//+------------------------------------------------------------------+
//| ScenarioD.mqh — martingale basket TP management                  |
//| Phase A5.5                                                       |
//|                                                                   |
//| ScenarioD is the martingale / grid layer. The entry-side logic   |
//| (lot multiplier, step gate, min-distance) runs in Signal.mqh's   |
//| HandleSignal (A5.6). This module only exposes the TP-application |
//| helpers that re-level the basket's common TP to BE + bePoints    |
//| whenever a new add lands.                                         |
//+------------------------------------------------------------------+
#ifndef __MD_SCENARIOD_MQH__
#define __MD_SCENARIOD_MQH__

//+------------------------------------------------------------------+
//| Apply a common TP (BE + bePoints) across all series positions.   |
//| Skips pyramid tickets and runners.                                |
//+------------------------------------------------------------------+
void ApplyBasketTPSeries(int dir, string seriesKey)
{
   double be;
   if(!CalcBasketBEWithCostsSeries(dir, seriesKey, be)) return;

   double tp = (dir > 0 ? be + bePoints * _Point : be - bePoints * _Point);
   tp = NormalizePrice(tp);

   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!IsMinePosition()) continue;
      if(IsPyramidTicket(ticket)) continue;
      if(IsRunner()) continue;
      if(!IsSelectedPositionInSeries(seriesKey)) continue;

      long typ = PositionGetInteger(POSITION_TYPE);
      if(dir > 0 && typ != POSITION_TYPE_BUY)  continue;
      if(dir < 0 && typ != POSITION_TYPE_SELL) continue;

      double sl      = PositionGetDouble(POSITION_SL);
      double oldTp   = PositionGetDouble(POSITION_TP);

      // Skip if already within 2-point tolerance of target.
      if(oldTp > 0 && MathAbs(oldTp - tp) < (_Point * 2)) continue;

      ModifyPositionSLTP(ticket, sl, tp);
   }
}

//+------------------------------------------------------------------+
//| Non-series variant (used by the old fast path; kept for          |
//| backwards compat).                                                |
//+------------------------------------------------------------------+
void ApplyBasketTP(int dir)
{
   double be;
   if(!CalcGroupBE(dir, be)) return;

   double tp = (dir > 0 ? be + bePoints * _Point : be - bePoints * _Point);
   tp = NormalizePrice(tp);

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

      double sl    = PositionGetDouble(POSITION_SL);
      double curTP = PositionGetDouble(POSITION_TP);

      if(MathAbs(curTP - tp) > (2 * _Point))
         ModifyPositionSLTP(ticket, sl, tp);
   }
}

#endif // __MD_SCENARIOD_MQH__
