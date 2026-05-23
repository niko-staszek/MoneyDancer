//+------------------------------------------------------------------+
//| Telemetry.mqh — PL.4 event-driven CSV log for cent forward       |
//|                                                                   |
//| Trimmed from the CashCabaret 48-column schema to a minimal        |
//| event-driven 15-column form. NOT per-tick — only logged when      |
//| something happens that the operator should be able to grep later. |
//|                                                                   |
//| Why event-driven instead of full per-tick: cent forward's primary |
//| forensic question is "WHEN did the rails fire and WHAT state was  |
//| the EA in at the time". Per-tick fills (balance/equity histories) |
//| are already captured by MT5 Account History; trade-level deals    |
//| are captured by MT5 Deals tab. The telemetry CSV adds the slice   |
//| MT5 doesn't capture: rail-trigger events with the rail-relevant   |
//| state at trigger time.                                            |
//|                                                                   |
//| Schema (15 cols, append-only — never rename / remove, only add):  |
//|   ts, event_type, event_data, balance, equity, day_pl, day_pl_pct,|
//|   peak_eq, current_dd_pct, buy_pos, sell_pos, paused,             |
//|   pause_reason, basket_sl_today, comment                          |
//|                                                                   |
//| Files: MoneyDancer_telemetry_<Magic>_<Symbol>_<YYYYMMDD>.csv      |
//| Daily rotation via TelemetryRotateIfNeeded(); auto-rotates on     |
//| first event of a new day-key.                                     |
//|                                                                   |
//| Skipped in tester (MQL_TESTER guard).                             |
//+------------------------------------------------------------------+
#ifndef __MD_TELEMETRY_MQH__
#define __MD_TELEMETRY_MQH__

int      g_tele_file        = INVALID_HANDLE;
int      g_tele_dayKey      = -1;

string TelemetryFileName(datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   string ymd = StringFormat("%04d%02d%02d", dt.year, dt.mon, dt.day);
   return "MoneyDancer_telemetry_" + IntegerToString(Magic) + "_" + _Symbol + "_" + ymd + ".csv";
}

void TelemetryWriteHeader()
{
   if(g_tele_file == INVALID_HANDLE) return;
   FileWrite(g_tele_file,
      "ts", "event_type", "event_data",
      "balance", "equity", "day_pl", "day_pl_pct",
      "peak_eq", "current_dd_pct",
      "buy_pos", "sell_pos",
      "paused", "pause_reason", "basket_sl_today", "comment");
}

bool TelemetryOpenToday()
{
   if(MQLInfoInteger(MQL_TESTER)) return false;
   string fn = TelemetryFileName(TimeCurrent());

   int h = FileOpen(fn, FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_SHARE_READ, ',');
   if(h == INVALID_HANDLE)
   {
      PrintFormat("[PL.4] FileOpen %s failed err=%d", fn, GetLastError());
      return false;
   }

   bool isNew = (FileSize(h) == 0);
   FileSeek(h, 0, SEEK_END);
   g_tele_file   = h;
   g_tele_dayKey = DayKey(TimeCurrent());

   if(isNew) TelemetryWriteHeader();
   return true;
}

void TelemetryClose()
{
   if(g_tele_file != INVALID_HANDLE)
   {
      FileClose(g_tele_file);
      g_tele_file = INVALID_HANDLE;
   }
}

void TelemetryRotateIfNeeded()
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   int dk = DayKey(TimeCurrent());
   if(dk != g_tele_dayKey)
   {
      TelemetryClose();
      TelemetryOpenToday();
   }
}

int CountMinePositions(int dir)
{
   int n = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      if(!IsMinePosition()) continue;
      long typ = PositionGetInteger(POSITION_TYPE);
      if(dir > 0 && typ == POSITION_TYPE_BUY)  n++;
      if(dir < 0 && typ == POSITION_TYPE_SELL) n++;
   }
   return n;
}

void TelemetryLogEvent(string event_type, string event_data = "", string comment = "")
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   TelemetryRotateIfNeeded();
   if(g_tele_file == INVALID_HANDLE)
   {
      if(!TelemetryOpenToday()) return;
   }

   double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity    = AccountInfoDouble(ACCOUNT_EQUITY);
   double dayPl     = (g_dayBaseReady && g_dayBaseBalance > 0) ? (balance - g_dayBaseBalance) : 0.0;
   double dayPlPct  = (g_dayBaseBalance > 0) ? (dayPl / g_dayBaseBalance * 100.0) : 0.0;
   double currDDPct = (g_peakEquityEver > 0) ? ((g_peakEquityEver - equity) / g_peakEquityEver * 100.0) : 0.0;
   int    buyPos    = CountMinePositions(+1);
   int    sellPos   = CountMinePositions(-1);
   bool   paused    = IsAutoPaused();

   FileWrite(g_tele_file,
      TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
      event_type,
      event_data,
      DoubleToString(balance, 2),
      DoubleToString(equity, 2),
      DoubleToString(dayPl, 2),
      DoubleToString(dayPlPct, 3),
      DoubleToString(g_peakEquityEver, 2),
      DoubleToString(currDDPct, 3),
      IntegerToString(buyPos),
      IntegerToString(sellPos),
      paused ? "1" : "0",
      paused ? g_tradePauseReason : "",
      IntegerToString(g_basketSLToday),
      comment);

   FileFlush(g_tele_file);  // crash-safety: flush on every event
}

void TelemetryInit()
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   TelemetryOpenToday();
   TelemetryLogEvent("ea_init", StringFormat("magic=%d symbol=%s", Magic, _Symbol));
}

void TelemetryDeinit(int reason)
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   TelemetryLogEvent("ea_deinit", StringFormat("reason=%d", reason));
   TelemetryClose();
}

#endif // __MD_TELEMETRY_MQH__
