//+------------------------------------------------------------------+
//| NewsCalendar.mqh - S1.1 economic-calendar blackout.               |
//|                                                                    |
//| Loader strategy:                                                   |
//|   1. Try MT5's native CalendarValueHistory() for USD/EUR/GBP.     |
//|   2. If 0 events come back (tester sandbox may disable it), fall  |
//|      back to the hardcoded fallback table generated from          |
//|      data/calendar/{2025,2026}_full.csv by                         |
//|      scripts/gen_news_calendar_mqh.py.                            |
//|                                                                    |
//| All times stored as UTC. Compared against TimeCurrent() which on  |
//| imported XAUUSD.duk_* custom symbols is UTC (the importer writes  |
//| Duka tick times verbatim).                                         |
//+------------------------------------------------------------------+
#ifndef __MD_NEWSCALENDAR_MQH__
#define __MD_NEWSCALENDAR_MQH__

#define NEWS_FALLBACK_COUNT 140

struct NewsEvent { datetime t; int tier; string cur; string label; };

NewsEvent g_news_events[];          // dynamic; sized at News_Init
int       g_news_count  = 0;
int       g_news_cursor = 0;       // index of next-pending event
string    g_news_source = "none"; // "mt5" or "fallback"

// ----- helpers -----

int News_ImportanceToTier(int imp)
{
   // ENUM_CALENDAR_EVENT_IMPORTANCE: NONE=0, LOW=1, MODERATE=2, HIGH=3
   if(imp >= 3) return 1;  // HIGH -> tier1
   if(imp == 2) return 2;  // MODERATE -> tier2
   return 3;               // LOW/NONE -> tier3 (we ignore these)
}

void News_AppendEvent(datetime t, int tier, string cur, string label)
{
   int n = ArraySize(g_news_events);
   ArrayResize(g_news_events, n + 1);
   g_news_events[n].t = t;
   g_news_events[n].tier = tier;
   g_news_events[n].cur = cur;
   g_news_events[n].label = label;
}

void News_SortByTime()
{
   int n = ArraySize(g_news_events);
   for(int i = 1; i < n; i++)
   {
      NewsEvent key = g_news_events[i];
      int j = i - 1;
      while(j >= 0 && g_news_events[j].t > key.t)
      {
         g_news_events[j + 1] = g_news_events[j];
         j--;
      }
      g_news_events[j + 1] = key;
   }
}

// ----- native MT5 calendar loader -----

int News_TryLoadFromMT5()
{
   datetime now = TimeCurrent();
   if(now <= 0) return 0;
   datetime fromT = now - (datetime)(365 * 86400);
   datetime toT   = now + (datetime)(365 * 86400);
   string currs[] = {"USD", "EUR", "GBP"};
   int total = 0;
   for(int c = 0; c < ArraySize(currs); c++)
   {
      MqlCalendarValue values[];
      int n = CalendarValueHistory(values, fromT, toT, "", currs[c]);
      if(n <= 0) continue;
      for(int i = 0; i < n; i++)
      {
         MqlCalendarEvent ev;
         if(!CalendarEventById(values[i].event_id, ev)) continue;
         int tier = News_ImportanceToTier((int)ev.importance);
         if(tier > 2) continue;  // skip LOW/NONE
         News_AppendEvent(values[i].time, tier, currs[c], ev.name);
         total++;
      }
   }
   return total;
}

// ----- hardcoded fallback (generated from data/calendar/{2025,2026}_full.csv) -----

void News_LoadFallback()
{
   News_AppendEvent(D'2025.01.10 13:30', 1, "USD", "NFP - Dec 2024");
   News_AppendEvent(D'2025.01.15 13:30', 1, "USD", "CPI YoY - Dec 2024");
   News_AppendEvent(D'2025.01.16 13:30', 2, "USD", "PPI / Retail Sales");
   News_AppendEvent(D'2025.01.29 19:00', 1, "USD", "FOMC Rate Decision");
   News_AppendEvent(D'2025.01.29 19:30', 1, "USD", "FOMC Press Conference");
   News_AppendEvent(D'2025.01.30 13:15', 1, "EUR", "ECB Rate Decision");
   News_AppendEvent(D'2025.01.30 13:30', 1, "USD", "US GDP Q4 Advance");
   News_AppendEvent(D'2025.01.31 13:30', 1, "USD", "PCE Index");
   News_AppendEvent(D'2025.02.06 12:00', 1, "GBP", "BoE Rate Decision");
   News_AppendEvent(D'2025.02.07 13:30', 1, "USD", "NFP - Jan 2025");
   News_AppendEvent(D'2025.02.12 13:30', 1, "USD", "CPI YoY - Jan 2025");
   News_AppendEvent(D'2025.02.13 13:30', 2, "USD", "PPI");
   News_AppendEvent(D'2025.02.14 13:30', 2, "USD", "Retail Sales");
   News_AppendEvent(D'2025.02.19 19:00', 2, "USD", "FOMC Minutes");
   News_AppendEvent(D'2025.02.28 13:30', 1, "USD", "PCE Index");
   News_AppendEvent(D'2025.03.06 13:15', 1, "EUR", "ECB Rate Decision");
   News_AppendEvent(D'2025.03.07 13:30', 1, "USD", "NFP - Feb 2025");
   News_AppendEvent(D'2025.03.12 12:30', 1, "USD", "CPI YoY - Feb 2025");
   News_AppendEvent(D'2025.03.13 12:30', 2, "USD", "PPI");
   News_AppendEvent(D'2025.03.17 12:30', 2, "USD", "Retail Sales");
   News_AppendEvent(D'2025.03.19 18:00', 1, "USD", "FOMC Rate Decision");
   News_AppendEvent(D'2025.03.19 18:30', 1, "USD", "FOMC Press Conference");
   News_AppendEvent(D'2025.03.20 12:00', 1, "GBP", "BoE Rate Decision");
   News_AppendEvent(D'2025.03.27 12:30', 1, "USD", "US GDP Q4 Final");
   News_AppendEvent(D'2025.03.28 12:30', 1, "USD", "PCE Index");
   News_AppendEvent(D'2025.04.04 12:30', 1, "USD", "NFP - Mar 2025");
   News_AppendEvent(D'2025.04.10 12:30', 1, "USD", "CPI YoY - Mar 2025");
   News_AppendEvent(D'2025.04.11 12:30', 2, "USD", "PPI");
   News_AppendEvent(D'2025.04.16 12:30', 2, "USD", "Retail Sales");
   News_AppendEvent(D'2025.04.17 12:15', 1, "EUR", "ECB Rate Decision");
   News_AppendEvent(D'2025.04.30 12:30', 1, "USD", "PCE Index");
   News_AppendEvent(D'2025.04.30 12:30', 1, "USD", "US GDP Q1 Advance");
   News_AppendEvent(D'2025.05.02 12:30', 1, "USD", "NFP - Apr 2025");
   News_AppendEvent(D'2025.05.07 18:00', 1, "USD", "FOMC Rate Decision");
   News_AppendEvent(D'2025.05.07 18:30', 1, "USD", "FOMC Press Conference");
   News_AppendEvent(D'2025.05.08 11:00', 1, "GBP", "BoE Rate Decision");
   News_AppendEvent(D'2025.05.13 12:30', 1, "USD", "CPI YoY - Apr 2025");
   News_AppendEvent(D'2025.05.15 12:30', 2, "USD", "Retail Sales / PPI");
   News_AppendEvent(D'2025.05.30 12:30', 1, "USD", "PCE Index");
   News_AppendEvent(D'2025.06.05 12:15', 1, "EUR", "ECB Rate Decision");
   News_AppendEvent(D'2025.06.06 12:30', 1, "USD", "NFP - May 2025");
   News_AppendEvent(D'2025.06.11 12:30', 1, "USD", "CPI YoY - May 2025");
   News_AppendEvent(D'2025.06.12 12:30', 2, "USD", "PPI");
   News_AppendEvent(D'2025.06.17 12:30', 2, "USD", "Retail Sales");
   News_AppendEvent(D'2025.06.18 18:00', 1, "USD", "FOMC Rate Decision");
   News_AppendEvent(D'2025.06.18 18:30', 1, "USD", "FOMC Press Conference");
   News_AppendEvent(D'2025.06.19 11:00', 1, "GBP", "BoE Rate Decision");
   News_AppendEvent(D'2025.06.27 12:30', 1, "USD", "PCE Index");
   News_AppendEvent(D'2025.07.03 12:30', 1, "USD", "NFP - Jun 2025 (early; Jul 4 holiday)");
   News_AppendEvent(D'2025.07.15 12:30', 1, "USD", "CPI YoY - Jun 2025");
   News_AppendEvent(D'2025.07.16 12:30', 2, "USD", "PPI");
   News_AppendEvent(D'2025.07.17 12:30', 2, "USD", "Retail Sales");
   News_AppendEvent(D'2025.07.24 12:15', 1, "EUR", "ECB Rate Decision");
   News_AppendEvent(D'2025.07.30 12:30', 1, "USD", "US GDP Q2 Advance");
   News_AppendEvent(D'2025.07.30 18:00', 1, "USD", "FOMC Rate Decision");
   News_AppendEvent(D'2025.07.30 18:30', 1, "USD", "FOMC Press Conference");
   News_AppendEvent(D'2025.07.31 12:30', 1, "USD", "PCE Index");
   News_AppendEvent(D'2025.08.01 12:30', 1, "USD", "NFP - Jul 2025");
   News_AppendEvent(D'2025.08.07 11:00', 1, "GBP", "BoE Rate Decision");
   News_AppendEvent(D'2025.08.12 12:30', 1, "USD", "CPI YoY - Jul 2025");
   News_AppendEvent(D'2025.08.14 12:30', 2, "USD", "PPI / Retail Sales");
   News_AppendEvent(D'2025.08.22 14:00', 1, "USD", "Jackson Hole - Powell remarks");
   News_AppendEvent(D'2025.08.29 12:30', 1, "USD", "PCE Index");
   News_AppendEvent(D'2025.09.05 12:30', 1, "USD", "NFP - Aug 2025");
   News_AppendEvent(D'2025.09.11 12:15', 1, "EUR", "ECB Rate Decision");
   News_AppendEvent(D'2025.09.11 12:30', 1, "USD", "CPI YoY - Aug 2025");
   News_AppendEvent(D'2025.09.12 12:30', 2, "USD", "PPI");
   News_AppendEvent(D'2025.09.16 12:30', 2, "USD", "Retail Sales");
   News_AppendEvent(D'2025.09.17 18:00', 1, "USD", "FOMC Rate Decision");
   News_AppendEvent(D'2025.09.17 18:30', 1, "USD", "FOMC Press Conference");
   News_AppendEvent(D'2025.09.18 11:00', 1, "GBP", "BoE Rate Decision");
   News_AppendEvent(D'2025.09.26 12:30', 1, "USD", "PCE Index");
   News_AppendEvent(D'2025.10.03 12:30', 1, "USD", "NFP - Sep 2025");
   News_AppendEvent(D'2025.10.15 12:30', 1, "USD", "CPI YoY - Sep 2025");
   News_AppendEvent(D'2025.10.16 12:30', 2, "USD", "PPI / Retail Sales");
   News_AppendEvent(D'2025.10.29 18:00', 1, "USD", "FOMC Rate Decision");
   News_AppendEvent(D'2025.10.29 18:30', 1, "USD", "FOMC Press Conference");
   News_AppendEvent(D'2025.10.30 12:30', 1, "USD", "US GDP Q3 Advance");
   News_AppendEvent(D'2025.10.30 13:15', 1, "EUR", "ECB Rate Decision");
   News_AppendEvent(D'2025.10.31 12:30', 1, "USD", "PCE Index");
   News_AppendEvent(D'2025.11.06 12:00', 1, "GBP", "BoE Rate Decision");
   News_AppendEvent(D'2025.11.07 13:30', 1, "USD", "NFP - Oct 2025");
   News_AppendEvent(D'2025.11.13 13:30', 1, "USD", "CPI YoY - Oct 2025");
   News_AppendEvent(D'2025.11.14 13:30', 2, "USD", "PPI / Retail Sales");
   News_AppendEvent(D'2025.11.26 13:30', 1, "USD", "PCE Index");
   News_AppendEvent(D'2025.12.05 13:30', 1, "USD", "NFP - Nov 2025");
   News_AppendEvent(D'2025.12.10 13:30', 1, "USD", "CPI YoY - Nov 2025");
   News_AppendEvent(D'2025.12.10 19:00', 1, "USD", "FOMC Rate Decision");
   News_AppendEvent(D'2025.12.10 19:30', 1, "USD", "FOMC Press Conference");
   News_AppendEvent(D'2025.12.11 13:30', 2, "USD", "PPI / Retail Sales");
   News_AppendEvent(D'2025.12.18 12:00', 1, "GBP", "BoE Rate Decision");
   News_AppendEvent(D'2025.12.18 13:15', 1, "EUR", "ECB Rate Decision");
   News_AppendEvent(D'2025.12.19 13:30', 1, "USD", "PCE Index");
   News_AppendEvent(D'2026.01.08 13:30', 1, "USD", "Initial Jobless Claims");
   News_AppendEvent(D'2026.01.09 13:30', 1, "USD", "NFP â€” Dec 2025 data");
   News_AppendEvent(D'2026.01.14 13:30', 1, "USD", "CPI YoY â€” Dec 2025");
   News_AppendEvent(D'2026.01.15 13:30', 1, "USD", "PPI / Retail Sales");
   News_AppendEvent(D'2026.01.21 13:30', 2, "USD", "Philly Fed / Building Permits");
   News_AppendEvent(D'2026.01.22 13:30', 1, "EUR", "ECB Rate Decision");
   News_AppendEvent(D'2026.01.29 13:30', 1, "USD", "US GDP Q4 Advance");
   News_AppendEvent(D'2026.01.29 19:00', 1, "USD", "FOMC Rate Decision");
   News_AppendEvent(D'2026.01.29 19:30', 1, "USD", "FOMC Press Conference");
   News_AppendEvent(D'2026.01.30 13:30', 1, "USD", "PCE Index");
   News_AppendEvent(D'2026.02.04 15:00', 1, "USD", "JOLTS");
   News_AppendEvent(D'2026.02.05 12:00', 1, "GBP", "BoE Rate Decision");
   News_AppendEvent(D'2026.02.05 13:30', 2, "USD", "Trade Balance / Jobless Claims");
   News_AppendEvent(D'2026.02.06 13:30', 1, "USD", "NFP â€” Jan 2026");
   News_AppendEvent(D'2026.02.12 13:30', 1, "USD", "CPI YoY â€” Jan 2026");
   News_AppendEvent(D'2026.02.13 13:30', 1, "USD", "Retail Sales / PPI");
   News_AppendEvent(D'2026.02.19 13:30', 2, "USD", "FOMC Minutes");
   News_AppendEvent(D'2026.02.25 15:00', 2, "USD", "Consumer Confidence");
   News_AppendEvent(D'2026.02.27 13:30', 1, "USD", "PCE Index");
   News_AppendEvent(D'2026.03.05 13:30', 2, "USD", "Jobless Claims");
   News_AppendEvent(D'2026.03.06 13:15', 1, "EUR", "ECB Rate Decision");
   News_AppendEvent(D'2026.03.06 13:30', 1, "USD", "NFP â€” Feb 2026");
   News_AppendEvent(D'2026.03.12 13:30', 1, "USD", "CPI YoY â€” Feb 2026");
   News_AppendEvent(D'2026.03.13 13:30', 2, "USD", "PPI / Retail Sales");
   News_AppendEvent(D'2026.03.17 13:30', 2, "USD", "Housing Starts");
   News_AppendEvent(D'2026.03.19 12:00', 1, "GBP", "BoE Rate Decision");
   News_AppendEvent(D'2026.03.19 18:00', 1, "USD", "FOMC Rate Decision");
   News_AppendEvent(D'2026.03.19 18:30', 1, "USD", "FOMC Press Conference");
   News_AppendEvent(D'2026.03.26 13:30', 1, "USD", "US GDP Q4 Final");
   News_AppendEvent(D'2026.03.28 13:30', 1, "USD", "PCE Index");
   News_AppendEvent(D'2026.04.01 13:30', 2, "USD", "ADP Employment");
   News_AppendEvent(D'2026.04.02 13:30', 2, "USD", "Initial Jobless Claims / ISM Services");
   News_AppendEvent(D'2026.04.03 13:30', 1, "USD", "NFP â€” Mar 2026 data");
   News_AppendEvent(D'2026.04.09 13:30', 1, "USD", "PPI / Initial Jobless Claims");
   News_AppendEvent(D'2026.04.10 13:30', 1, "USD", "CPI YoY â€” Mar 2026");
   News_AppendEvent(D'2026.04.15 13:30', 2, "USD", "Retail Sales");
   News_AppendEvent(D'2026.04.16 11:45', 1, "EUR", "ECB Rate Decision");
   News_AppendEvent(D'2026.04.22 13:30', 2, "USD", "Existing Home Sales");
   News_AppendEvent(D'2026.04.23 13:30', 2, "USD", "Initial Jobless Claims / Durable Goods");
   News_AppendEvent(D'2026.04.29 13:30', 1, "USD", "US GDP Q1 Advance");
   News_AppendEvent(D'2026.04.29 19:00', 1, "USD", "FOMC Rate Decision");
   News_AppendEvent(D'2026.04.29 19:30', 1, "USD", "FOMC Press Conference");
   News_AppendEvent(D'2026.04.30 13:30', 1, "USD", "PCE Index");
   News_AppendEvent(D'2026.05.01 13:30', 1, "USD", "NFP â€” Apr 2026 data");
   News_AppendEvent(D'2026.05.07 11:00', 1, "GBP", "BoE Rate Decision");
   News_AppendEvent(D'2026.05.13 13:30', 1, "USD", "CPI YoY â€” Apr 2026");
   News_AppendEvent(D'2026.05.14 13:30', 1, "USD", "PPI / Retail Sales");
}

void News_Init()
{
   ArrayResize(g_news_events, 0);
   g_news_count  = 0;
   g_news_cursor = 0;

   int n_mt5 = News_TryLoadFromMT5();
   if(n_mt5 > 0)
   {
      g_news_source = "mt5";
      g_news_count  = n_mt5;
   }
   else
   {
      News_LoadFallback();
      g_news_source = "fallback";
      g_news_count  = ArraySize(g_news_events);
   }
   News_SortByTime();
   PrintFormat("[S1.1] NewsCalendar loaded %d events (source=%s)", g_news_count, g_news_source);
}

//+------------------------------------------------------------------+
//| Is event currency relevant to current symbol?                     |
//| XAUUSD reacts to USD; we also include EUR/GBP since they move the |
//| dollar index and gold trades against it.                          |
//+------------------------------------------------------------------+
bool News_RelevantCurrency(string cur)
{
   if(StringFind(_Symbol, "XAU") >= 0) return (cur == "USD" || cur == "EUR" || cur == "GBP");
   if(StringLen(_Symbol) >= 6)
   {
      string left  = StringSubstr(_Symbol, 0, 3);
      string right = StringSubstr(_Symbol, 3, 3);
      return (cur == left || cur == right);
   }
   return (StringFind(_Symbol, cur) >= 0);
}

//+------------------------------------------------------------------+
//| Cursor-advance: skip past events older than the post-window.     |
//+------------------------------------------------------------------+
void News_AdvanceCursor()
{
   datetime cutoff = TimeCurrent() - (datetime)(NewsBlackoutPostMin * 60);
   while(g_news_cursor < g_news_count && g_news_events[g_news_cursor].t < cutoff)
      g_news_cursor++;
}

//+------------------------------------------------------------------+
//| True iff a relevant event of allowed tier is within the blackout |
//| window [evt - pre, evt + post]. Reads inputs UseNewsBlackout,    |
//| NewsBlackoutPreMin, NewsBlackoutPostMin, NewsBlackoutTier2.      |
//+------------------------------------------------------------------+
bool News_IsBlackoutActive()
{
   if(!UseNewsBlackout) return false;
   News_AdvanceCursor();
   datetime now = TimeCurrent();
   for(int i = g_news_cursor; i < g_news_count; i++)
   {
      datetime t = g_news_events[i].t;
      if(t > now + (datetime)(NewsBlackoutPreMin * 60)) break;
      int tier = g_news_events[i].tier;
      bool tierOK = (tier == 1) || (tier == 2 && NewsBlackoutTier2);
      if(!tierOK) continue;
      if(!News_RelevantCurrency(g_news_events[i].cur)) continue;
      if(t > now) return true;                                  // upcoming, within pre-window
      if(now - t <= (datetime)(NewsBlackoutPostMin * 60)) return true;  // recently fired
   }
   return false;
}

#endif
