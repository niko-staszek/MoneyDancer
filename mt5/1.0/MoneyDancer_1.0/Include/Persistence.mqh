//+------------------------------------------------------------------+
//| Persistence.mqh — PosMem tracking (save/load/sync)                |
//| Phase A3: port from MT4 PosMem* block.                           |
//|                                                                   |
//| MT5 semantic adaptations vs MT4:                                  |
//|  - Position tickets are ulong (not int)                           |
//|  - OrderSelect(..., SELECT_BY_TICKET) replaced by                 |
//|    PositionSelectByTicket — cleanly returns false for closed      |
//|    positions (no "history pool returns closed tickets" trap).     |
//|    The MT4 OrderCloseTime()>0 guard is therefore REMOVED here.    |
//|  - Iteration uses PositionsTotal() + PositionGetTicket(i).        |
//|  - Files live in MQL5\Files\ (MT5 equivalent of MT4\Files\).      |
//+------------------------------------------------------------------+
#ifndef __MD_PERSISTENCE_MQH__
#define __MD_PERSISTENCE_MQH__

//+------------------------------------------------------------------+
//| Filename builder for the positions CSV                            |
//| Note: MT4 StringConcatenate() returned the string. MT5 writes     |
//| into a reference first argument and returns the length — so we    |
//| use '+' concatenation here instead.                                |
//+------------------------------------------------------------------+
string PositionsFileName()
{
   return("MoneyDancer_positions_" + IntegerToString(Magic) + "_" + _Symbol + ".csv");
}

//+------------------------------------------------------------------+
//| In-memory array ops                                               |
//+------------------------------------------------------------------+
void PosMemClear()
{
   ArrayResize(g_posTickets, 0);
   ArrayResize(g_posTP, 0);
   ArrayResize(g_posSL, 0);
}

int PosMemFindIndex(ulong ticket)
{
   for(int i = 0; i < ArraySize(g_posTickets); i++)
      if(g_posTickets[i] == ticket) return i;
   return -1;
}

void PosMemRemoveIndex(int idx)
{
   int n = ArraySize(g_posTickets);
   if(idx < 0 || idx >= n) return;
   // swap with last for speed
   if(idx != n - 1)
   {
      g_posTickets[idx] = g_posTickets[n - 1];
      g_posTP[idx]      = g_posTP[n - 1];
      g_posSL[idx]      = g_posSL[n - 1];
   }
   ArrayResize(g_posTickets, n - 1);
   ArrayResize(g_posTP,      n - 1);
   ArrayResize(g_posSL,      n - 1);
}

void PosMemAddOrUpdate(ulong ticket, double tp, double sl)
{
   int idx = PosMemFindIndex(ticket);
   if(idx < 0)
   {
      int n = ArraySize(g_posTickets);
      ArrayResize(g_posTickets, n + 1);
      ArrayResize(g_posTP,      n + 1);
      ArrayResize(g_posSL,      n + 1);
      g_posTickets[n] = ticket;
      g_posTP[n]      = tp;
      g_posSL[n]      = sl;
   }
   else
   {
      g_posTP[idx] = tp;
      g_posSL[idx] = sl;
   }
}

//+------------------------------------------------------------------+
//| Is this ticket still an open "mine" trading position?             |
//+------------------------------------------------------------------+
bool PosTicketStillActive(ulong ticket)
{
   if(ticket == 0) return false;
   if(!PositionSelectByTicket(ticket)) return false;
   if(!IsMinePosition()) return false;

   long typ = PositionGetInteger(POSITION_TYPE);
   if(typ != POSITION_TYPE_BUY && typ != POSITION_TYPE_SELL) return false;

   return true;
}

//+------------------------------------------------------------------+
//| CSV I/O                                                           |
//+------------------------------------------------------------------+
void LoadPositionsFromFile()
{
   PosMemClear();
   string fn = PositionsFileName();

   int h = FileOpen(fn, FILE_CSV | FILE_READ | FILE_ANSI);
   if(h == INVALID_HANDLE) return;

   while(!FileIsEnding(h))
   {
      string sTicket = FileReadString(h);
      if(FileIsEnding(h) && (sTicket == "")) break;

      ulong  ticket = (ulong)StringToInteger(sTicket);
      double tp     = FileReadNumber(h);
      double sl     = FileReadNumber(h);

      if(ticket > 0) PosMemAddOrUpdate(ticket, tp, sl);
   }
   FileClose(h);
}

void SavePositionsToFile()
{
   string fn = PositionsFileName();
   int h = FileOpen(fn, FILE_CSV | FILE_WRITE | FILE_ANSI);
   if(h == INVALID_HANDLE) return;

   // Format: ticket,tp,sl (one line = one position)
   for(int i = 0; i < ArraySize(g_posTickets); i++)
      FileWrite(h, (long)g_posTickets[i],
                   DoubleToString(g_posTP[i], _Digits),
                   DoubleToString(g_posSL[i], _Digits));
   FileClose(h);
}

//+------------------------------------------------------------------+
//| Sync memory with terminal:                                        |
//|  - remove tickets from memory that are no longer active           |
//|  - refresh TP/SL for active ones                                  |
//|  - optionally add all current EA positions even if not in the file|
//+------------------------------------------------------------------+
void SyncPositionsWithTerminal(bool addAllCurrent)
{
   // Remove inactive + refresh TP/SL
   for(int i = ArraySize(g_posTickets) - 1; i >= 0; i--)
   {
      ulong t = g_posTickets[i];
      if(!PosTicketStillActive(t))
      {
         PosMemRemoveIndex(i);
         continue;
      }
      // PosTicketStillActive() left the selection on this ticket
      PosMemAddOrUpdate(t,
                        PositionGetDouble(POSITION_TP),
                        PositionGetDouble(POSITION_SL));
   }

   if(addAllCurrent)
   {
      int total = PositionsTotal();
      for(int j = total - 1; j >= 0; j--)
      {
         ulong ticket = PositionGetTicket(j);
         if(ticket == 0) continue;
         // PositionGetTicket already selected this position
         if(!IsMinePosition()) continue;

         long typ = PositionGetInteger(POSITION_TYPE);
         if(typ != POSITION_TYPE_BUY && typ != POSITION_TYPE_SELL) continue;

         PosMemAddOrUpdate(ticket,
                           PositionGetDouble(POSITION_TP),
                           PositionGetDouble(POSITION_SL));
      }
   }

   g_posLastSync = TimeCurrent();
}

#endif // __MD_PERSISTENCE_MQH__
