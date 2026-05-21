//+------------------------------------------------------------------+
//| Guards.mqh - entry-side blockers for S1.4 spread-spike and S2.0   |
//| hour-blocklist. Consulted from Signal.mqh's HandleSignal before    |
//| any new grid entry.                                                |
//|                                                                    |
//| Public API:                                                        |
//|   void Guards_Init()                                               |
//|   void Guards_OnTick()         - feeds the spread ring buffer      |
//|   bool Guards_BlocksEntry()    - union of all entry-side blocks    |
//+------------------------------------------------------------------+
#ifndef __MD_GUARDS_MQH__
#define __MD_GUARDS_MQH__

// ----- S1.4 spread-spike ring buffer -----
#define SPREAD_RING_MAX 4096

datetime g_spread_t[SPREAD_RING_MAX];
int      g_spread_pts[SPREAD_RING_MAX];
int      g_spread_n = 0;
int      g_spread_head = 0;

// ----- S2.0 parsed hour-block list -----
bool g_hour_blocked[24];
bool g_hour_block_parsed = false;

void Guards_ParseHourBlockList()
{
   ArrayInitialize(g_hour_blocked, false);
   g_hour_block_parsed = true;
   if(StringLen(HourBlockList) == 0) return;
   string parts[];
   int n = StringSplit(HourBlockList, ',', parts);
   for(int i = 0; i < n; i++)
   {
      string s = parts[i];
      StringTrimLeft(s); StringTrimRight(s);
      int h = (int)StringToInteger(s);
      if(h >= 0 && h <= 23) g_hour_blocked[h] = true;
   }
}

void Guards_Init()
{
   g_spread_n = 0;
   g_spread_head = 0;
   Guards_ParseHourBlockList();
}

//+------------------------------------------------------------------+
//| Push the current spread to the ring + prune old entries.         |
//| Called once per tick from OnTick.                                 |
//+------------------------------------------------------------------+
void Guards_OnTick()
{
   if(!UseSpreadSpikeGuard) return;

   int pts = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(pts <= 0) return;

   datetime now = TimeCurrent();
   // Append (overwrite oldest if buffer full)
   if(g_spread_n < SPREAD_RING_MAX)
   {
      g_spread_t[g_spread_n] = now;
      g_spread_pts[g_spread_n] = pts;
      g_spread_n++;
   }
   else
   {
      // wrap
      g_spread_t[g_spread_head] = now;
      g_spread_pts[g_spread_head] = pts;
      g_spread_head = (g_spread_head + 1) % SPREAD_RING_MAX;
   }
}

int Guards_SpreadMedian()
{
   datetime now = TimeCurrent();
   datetime cutoff = now - (datetime)SpreadSpikeWindowSec;
   int vals[];
   int n = 0;
   ArrayResize(vals, g_spread_n);
   for(int i = 0; i < g_spread_n; i++)
   {
      if(g_spread_t[i] >= cutoff)
      {
         vals[n] = g_spread_pts[i];
         n++;
      }
   }
   if(n < SpreadSpikeMinSamples) return -1;  // not enough data
   ArrayResize(vals, n);
   ArraySort(vals);
   return vals[n / 2];
}

bool Guards_SpreadSpikeBlocks()
{
   if(!UseSpreadSpikeGuard) return false;
   int med = Guards_SpreadMedian();
   if(med <= 0) return false;
   int cur = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double cap = (double)med * SpreadSpikeMultK;
   return ((double)cur > cap);
}

bool Guards_HourBlocked()
{
   if(!g_hour_block_parsed) Guards_ParseHourBlockList();
   if(StringLen(HourBlockList) == 0) return false;
   MqlDateTime mdt;
   TimeToStruct(TimeCurrent(), mdt);
   return g_hour_blocked[mdt.hour];
}

//+------------------------------------------------------------------+
//| Union: returns true when any entry-side gate fires.              |
//| Called from Signal.mqh::HandleSignal before EnsureSeriesActive.  |
//+------------------------------------------------------------------+
bool Guards_BlocksEntry()
{
   if(News_IsBlackoutActive())   return true;
   if(Guards_SpreadSpikeBlocks()) return true;
   if(Guards_HourBlocked())       return true;
   return false;
}

#endif
