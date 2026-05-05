//+------------------------------------------------------------------+
//| Utils.mqh — small helpers (price, lot, time, color, position)    |
//| Phase A3: port helpers needed across modules.                    |
//| Semantic adaptations from MT4 are documented inline below.       |
//+------------------------------------------------------------------+
#ifndef __MD_UTILS_MQH__
#define __MD_UTILS_MQH__

//==================== PRICE / LOT / SYMBOL HELPERS ====================

// MT4: MarketInfo(Symbol(), MODE_SPREAD)
int SpreadPoints() { return (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD); }

// MT4: Digits global -> MT5: _Digits predefined
// MT4: Point global  -> MT5: _Point predefined
double RoundToStep(double price, double step)
{
   if(step <= 0) return NormalizeDouble(price, _Digits);
   double k = MathRound(price / step);
   return NormalizeDouble(k * step, _Digits);
}

double ClampLot(double lot)
{
   double minLot    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLotSym = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step      = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(lot < minLot) lot = minLot;
   if(lot > maxLotSym) lot = maxLotSym;
   if(maxLot > 0.0 && lot > maxLot) lot = maxLot;

   if(step > 0.0) lot = MathFloor(lot / step) * step;
   lot = NormalizeDouble(lot, 2);
   if(lot < minLot) lot = minLot;
   return lot;
}

//==================== POSITION OWNERSHIP HELPERS ====================
// These assume the caller has already done PositionSelectByTicket(ticket)
// or is iterating PositionsTotal() + PositionGetTicket(i).

bool IsMinePosition()
{
   if(PositionGetString(POSITION_SYMBOL) != _Symbol) return false;
   if(PositionGetInteger(POSITION_MAGIC) != (long)Magic) return false;
   return true;
}

bool IsRunner()
{
   return (StringFind(PositionGetString(POSITION_COMMENT), RUNNER_TAG, 0) >= 0);
}

//==================== TIME HELPERS ====================
// MT4 had convenience wrappers (TimeHour, TimeMinute, TimeYear, etc.). These
// are deprecated in MT5 — use MqlDateTime + TimeToStruct() instead.

int MinutesOfDay(datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
}

int SecondsOfDay(datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 3600 + dt.min * 60 + dt.sec;
}

int DayKey(datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 1000 + dt.day_of_year;
}

int WeekKey(datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + (dt.day_of_year / 7);
}

int MonthKey(datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + dt.mon;
}

int DayOfWeek(datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.day_of_week;
}

string TwoDigit(int v)
{
   if(v < 0) v = 0;
   if(v < 10) return "0" + IntegerToString(v);
   return IntegerToString(v);
}

// MT4: StrToTime -> MT5: StringToTime
datetime TodayAt(int hour, int minute)
{
   datetime now = TimeCurrent();
   string s = TimeToString(now, TIME_DATE) + " " + TwoDigit(hour) + ":" + TwoDigit(minute);
   return StringToTime(s);
}

bool InLast24h(datetime t)
{
   if(t <= 0) return false;
   return (TimeCurrent() - t) <= MARKERS_WINDOW_SEC;
}

//==================== TRADING-HOURS WINDOW ====================

bool IsInTimeWindow(int nowMin, int sh, int sm, int eh, int em)
{
   int start = sh * 60 + sm;
   int end   = eh * 60 + em;

   // 00:00 - 00:00 => 24h
   if(start == 0 && end == 0) return true;

   // same time but not midnight => disabled
   if(start == end) return false;

   // normal or overnight
   if(start < end) return (nowMin >= start && nowMin <= end);
   return (nowMin >= start || nowMin <= end);
}

bool InTradingSession(datetime t)
{
   if(!UseTradingHours) return true;

   int dow = DayOfWeek(t); // 0=Sun, 1=Mon ... 5=Fri, 6=Sat
   if(dow == 0 || dow == 6) return false;

   int nowMin = MinutesOfDay(t);

   bool dayOn = true;
   int s1h=0, s1m=0, e1h=0, e1m=0, s2h=0, s2m=0, e2h=0, e2m=0;

   if(dow == 1)      { dayOn = MondayTrading;    s1h=MonStart1_Hour; s1m=MonStart1_Minute; e1h=MonEnd1_Hour; e1m=MonEnd1_Minute; s2h=MonStart2_Hour; s2m=MonStart2_Minute; e2h=MonEnd2_Hour; e2m=MonEnd2_Minute; }
   else if(dow == 2) { dayOn = TuesdayTrading;   s1h=TueStart1_Hour; s1m=TueStart1_Minute; e1h=TueEnd1_Hour; e1m=TueEnd1_Minute; s2h=TueStart2_Hour; s2m=TueStart2_Minute; e2h=TueEnd2_Hour; e2m=TueEnd2_Minute; }
   else if(dow == 3) { dayOn = WednesdayTrading; s1h=WedStart1_Hour; s1m=WedStart1_Minute; e1h=WedEnd1_Hour; e1m=WedEnd1_Minute; s2h=WedStart2_Hour; s2m=WedStart2_Minute; e2h=WedEnd2_Hour; e2m=WedEnd2_Minute; }
   else if(dow == 4) { dayOn = ThursdayTrading;  s1h=ThuStart1_Hour; s1m=ThuStart1_Minute; e1h=ThuEnd1_Hour; e1m=ThuEnd1_Minute; s2h=ThuStart2_Hour; s2m=ThuStart2_Minute; e2h=ThuEnd2_Hour; e2m=ThuEnd2_Minute; }
   else if(dow == 5) { dayOn = FridayTrading;    s1h=FriStart1_Hour; s1m=FriStart1_Minute; e1h=FriEnd1_Hour; e1m=FriEnd1_Minute; s2h=FriStart2_Hour; s2m=FriStart2_Minute; e2h=FriEnd2_Hour; e2m=FriEnd2_Minute; }

   if(!dayOn) return false;

   if(IsInTimeWindow(nowMin, s1h, s1m, e1h, e1m)) return true;
   if(IsInTimeWindow(nowMin, s2h, s2m, e2h, e2m)) return true;
   return false;
}

//==================== CHART OBJECT / NAMING HELPERS ====================

string ObjName(string suffix)
{
   return PREFIX + IntegerToString(Magic) + "_" + suffix;
}

string TicketKey(ulong ticket)
{
   return IntegerToString((long)ticket);
}

//==================== COLOR HELPERS ====================

int ColorR(color c) { return (int)(c & 0xFF); }
int ColorG(color c) { return (int)((c >> 8) & 0xFF); }
int ColorB(color c) { return (int)((c >> 16) & 0xFF); }

bool IsDark(color c)
{
   int r = ColorR(c), g = ColorG(c), b = ColorB(c);
   double lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;
   return (lum < 110.0);
}

#endif // __MD_UTILS_MQH__
