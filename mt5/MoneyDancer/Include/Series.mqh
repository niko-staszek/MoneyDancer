//+------------------------------------------------------------------+
//| Series.mqh — buy/sell series ID tracking (basket identity)       |
//| Phase A5.2                                                       |
//|                                                                   |
//| A "series" is one generation of a basket. Every time the basket  |
//| empties out and re-activates, the series counter increments, so   |
//| separate generations don't collide in break-even calculations.    |
//|                                                                   |
//| Each position's comment starts with SeriesKey(dir, id), e.g.      |
//| "TBb7" for buy series 7. Extra suffix after the id (e.g.          |
//| "TBb7|D=3") marks martingale adds.                                |
//+------------------------------------------------------------------+
#ifndef __MD_SERIES_MQH__
#define __MD_SERIES_MQH__

//+------------------------------------------------------------------+
//| Basic helpers                                                     |
//+------------------------------------------------------------------+
string SeriesPrefix(int dir)             { return (dir > 0 ? "TBb" : "TBs"); }
string SeriesKey(int dir, int id)        { return SeriesPrefix(dir) + IntegerToString(id); }
int    CurrentSeriesId(int dir)          { return (dir > 0 ? g_buySeriesId : g_sellSeriesId); }
bool   SeriesActive(int dir)             { return (dir > 0 ? g_buySeriesActive : g_sellSeriesActive); }
void   SetSeriesActive(int dir, bool a)
{
   if(dir > 0) g_buySeriesActive  = a;
   else        g_sellSeriesActive = a;
}

//+------------------------------------------------------------------+
//| Parse series id from a position comment (returns -1 if absent).  |
//+------------------------------------------------------------------+
int ExtractSeriesIdFromComment(string cmt, int dir)
{
   string pref = SeriesPrefix(dir);
   int p = StringFind(cmt, pref, 0);
   if(p < 0) return -1;

   int s = p + StringLen(pref);
   string num = "";
   for(int k = s; k < StringLen(cmt); k++)
   {
      string ch = StringSubstr(cmt, k, 1);
      ushort cc = StringGetCharacter(ch, 0);
      if(cc >= 48 && cc <= 57) num += ch;   // 0..9
      else break;
   }
   if(StringLen(num) <= 0) return -1;
   return (int)StringToInteger(num);
}

//+------------------------------------------------------------------+
//| Scan open positions; set active flags + advance series counters  |
//| to the max id seen in comments. Restart-safe on EA reload.       |
//+------------------------------------------------------------------+
void SyncSeriesIdsFromOpenOrders()
{
   int  maxBuy  = -1;
   int  maxSell = -1;
   bool anyBuy  = false;
   bool anySell = false;

   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!IsMinePosition()) continue;
      if(IsPyramidTicket(ticket)) continue;

      long typ = PositionGetInteger(POSITION_TYPE);
      if(typ != POSITION_TYPE_BUY && typ != POSITION_TYPE_SELL) continue;

      int    dir = (typ == POSITION_TYPE_BUY ? +1 : -1);
      string cmt = PositionGetString(POSITION_COMMENT);
      int    id  = ExtractSeriesIdFromComment(cmt, dir);

      if(dir > 0) anyBuy  = true; else anySell = true;
      if(id >= 0)
      {
         if(dir > 0 && id > maxBuy)  maxBuy  = id;
         if(dir < 0 && id > maxSell) maxSell = id;
      }
   }

   if(maxBuy  >= 0) g_buySeriesId  = maxBuy;
   if(maxSell >= 0) g_sellSeriesId = maxSell;

   g_buySeriesActive  = anyBuy;
   g_sellSeriesActive = anySell;
}

//+------------------------------------------------------------------+
//| Ensure a series is active for this direction. If it wasn't,      |
//| increment the counter and mark active.                            |
//+------------------------------------------------------------------+
void EnsureSeriesActive(int dir)
{
   if(dir > 0)
   {
      if(!g_buySeriesActive) { g_buySeriesId++;  g_buySeriesActive  = true; }
   }
   else
   {
      if(!g_sellSeriesActive) { g_sellSeriesId++; g_sellSeriesActive = true; }
   }
}

//+------------------------------------------------------------------+
//| Does the currently-selected position belong to this series?      |
//+------------------------------------------------------------------+
bool IsSelectedPositionInSeries(string seriesKey)
{
   if(seriesKey == "" || StringLen(seriesKey) == 0) return true;
   return (StringFind(PositionGetString(POSITION_COMMENT), seriesKey, 0) >= 0);
}

//+------------------------------------------------------------------+
//| Counter: positions in a direction, excluding pyramid tickets.    |
//| Optionally exclude runners.                                       |
//+------------------------------------------------------------------+
int CountOrdersDir(int dir, bool includeRunners)
{
   int c = 0;
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!IsMinePosition()) continue;
      if(IsPyramidTicket(ticket)) continue;
      if(!includeRunners && IsRunner()) continue;

      long typ = PositionGetInteger(POSITION_TYPE);
      if(dir > 0 && typ == POSITION_TYPE_BUY)  c++;
      if(dir < 0 && typ == POSITION_TYPE_SELL) c++;
   }
   return c;
}

//+------------------------------------------------------------------+
//| Series-scoped counter.                                            |
//+------------------------------------------------------------------+
int CountSeriesOrdersDir(int dir, string seriesKey, bool includeRunners)
{
   int c = 0;
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!IsMinePosition()) continue;
      if(IsPyramidTicket(ticket)) continue;
      if(!IsSelectedPositionInSeries(seriesKey)) continue;
      if(!includeRunners && IsRunner()) continue;

      long typ = PositionGetInteger(POSITION_TYPE);
      if(dir > 0 && typ == POSITION_TYPE_BUY)  c++;
      if(dir < 0 && typ == POSITION_TYPE_SELL) c++;
   }
   return c;
}

//+------------------------------------------------------------------+
//| Count of martingale adds in a series (comments containing "|D=").|
//+------------------------------------------------------------------+
int CountSeriesDAdds(int dir, string seriesKey)
{
   int c = 0;
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!IsMinePosition()) continue;
      if(IsPyramidTicket(ticket)) continue;
      if(!IsSelectedPositionInSeries(seriesKey)) continue;

      long typ = PositionGetInteger(POSITION_TYPE);
      if(dir > 0 && typ != POSITION_TYPE_BUY)  continue;
      if(dir < 0 && typ != POSITION_TYPE_SELL) continue;

      if(StringFind(PositionGetString(POSITION_COMMENT), "|D=", 0) >= 0) c++;
   }
   return c;
}

#endif // __MD_SERIES_MQH__
