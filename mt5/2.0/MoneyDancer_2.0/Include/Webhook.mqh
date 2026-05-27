//+------------------------------------------------------------------+
//| Webhook.mqh — PL.5 daily EOD summary push (Discord/Telegram)      |
//|                                                                   |
//| Posts a daily end-of-day summary to a Discord or Telegram webhook |
//| at server-time WebhookEodHour:WebhookEodMinute. Gated by          |
//| WebhookEnabled input; default OFF.                                 |
//|                                                                   |
//| MT5 requires the webhook host to be whitelisted in                |
//| Tools > Options > Expert Advisors > "Allow WebRequest for listed  |
//| URL" before WebRequest() works. Document this in the input help.  |
//|                                                                   |
//| Format auto-detected from URL:                                     |
//|   - contains "telegram" → uses {"text":"..."} POST                |
//|   - else → Discord-format {"content":"..."} POST                  |
//|                                                                   |
//| Skipped in tester (WebRequest blocked in MQL_TESTER mode anyway). |
//+------------------------------------------------------------------+
#ifndef __MD_WEBHOOK_MQH__
#define __MD_WEBHOOK_MQH__

// Tracks last day we pushed so we only fire once per day.
int g_webhookLastPushDayKey = -1;

bool IsTelegramUrl(string url)
{
   return StringFind(url, "telegram") >= 0 || StringFind(url, "api.telegram") >= 0;
}

// Escape minimal JSON-unsafe characters for embedding in a JSON string.
string JsonEscape(string s)
{
   string out = s;
   StringReplace(out, "\\", "\\\\");
   StringReplace(out, "\"", "\\\"");
   StringReplace(out, "\n", "\\n");
   StringReplace(out, "\r", "");
   StringReplace(out, "\t", " ");
   return out;
}

// Build the human-readable EOD summary string.
string BuildEodSummary()
{
   double balance     = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity      = AccountInfoDouble(ACCOUNT_EQUITY);
   double marginFree  = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double floatPL     = equity - balance;
   double dayPL       = (g_dayBaseReady && g_dayBaseBalance > 0)
                            ? (balance - g_dayBaseBalance) : 0.0;
   double dayPLPct    = (g_dayBaseBalance > 0) ? (dayPL / g_dayBaseBalance * 100.0) : 0.0;
   double peakEq      = g_peakEquityEver;
   double currentDD   = (peakEq > 0) ? ((peakEq - equity) / peakEq * 100.0) : 0.0;
   double maxDD       = g_maxDDEver;
   bool   paused      = IsAutoPaused();
   string pauseReason = paused ? g_tradePauseReason : "no";
   int    openPos     = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong t = PositionGetTicket(i);
      if(t != 0 && IsMinePosition()) openPos++;
   }

   string ts = TimeToString(TimeCurrent(), TIME_DATE);
   string body = StringFormat(
      "**MoneyDancer EOD %s**\\n"
      "Account: balance=$%.2f equity=$%.2f free=$%.2f\\n"
      "Day P/L: $%.2f (%.2f%% of baseline $%.2f)\\n"
      "Floating: $%.2f | Open positions: %d\\n"
      "All-time peak: $%.2f | Current DD: %.2f%% | Max DD: %.2f%%\\n"
      "Basket-SL today: %d | Paused: %s\\n"
      "Series: BUY=%s SELL=%s",
      ts, balance, equity, marginFree,
      dayPL, dayPLPct, g_dayBaseBalance,
      floatPL, openPos,
      peakEq, currentDD, maxDD,
      g_basketSLToday, pauseReason,
      g_buySeriesActive ? "active" : "off",
      g_sellSeriesActive ? "active" : "off"
   );
   return body;
}

// POST the summary to the configured webhook URL.
// Returns true on HTTP 2xx, false on any failure.
bool WebhookPostEod()
{
   if(!WebhookEnabled || StringLen(WebhookUrl) == 0) return false;
   if(MQLInfoInteger(MQL_TESTER)) return false;

   string summary = BuildEodSummary();
   string field   = IsTelegramUrl(WebhookUrl) ? "text" : "content";
   string body    = "{\"" + field + "\":\"" + JsonEscape(summary) + "\"}";

   char post[];
   StringToCharArray(body, post, 0, StringLen(body), CP_UTF8);

   char     result[];
   string   resultHeaders;
   string   headers = "Content-Type: application/json\r\n";

   int rc = WebRequest("POST", WebhookUrl, headers, 5000, post, result, resultHeaders);
   if(rc < 0)
   {
      int err = GetLastError();
      PrintFormat("[PL.5] WebRequest failed err=%d (URL %s not whitelisted? Tools > Options > Expert Advisors)", err, WebhookUrl);
      return false;
   }
   if(rc >= 200 && rc < 300)
   {
      PrintFormat("[PL.5] EOD pushed OK (http %d)", rc);
      return true;
   }
   PrintFormat("[PL.5] webhook returned http %d (body=%s)", rc, CharArrayToString(result, 0, ArraySize(result), CP_UTF8));
   return false;
}

// Called from OnTimer (60s) — fires once per day at WebhookEodHour:WebhookEodMinute.
void WebhookCheckAndFire()
{
   if(!WebhookEnabled) return;
   if(MQLInfoInteger(MQL_TESTER)) return;

   datetime now = TimeCurrent();
   MqlDateTime mdt;
   TimeToStruct(now, mdt);

   // Only fire after the EOD cutoff time.
   // CR-M11 note: if EA attaches AFTER the cutoff time on day-of-attach
   // (e.g., user starts EA at 23:00 with WebhookEodHour=22:30), this
   // condition is true immediately and the first OnTimer call (60s later)
   // pushes the EOD summary right away. That's intentional — operator
   // gets a startup snapshot via the same channel.
   bool past_cutoff = (mdt.hour > WebhookEodHour) ||
                      (mdt.hour == WebhookEodHour && mdt.min >= WebhookEodMinute);
   if(!past_cutoff) return;

   // Once per day
   int dk = DayKey(now);
   if(g_webhookLastPushDayKey == dk) return;

   if(WebhookPostEod())
      g_webhookLastPushDayKey = dk;
}

#endif // __MD_WEBHOOK_MQH__
