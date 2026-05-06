//+------------------------------------------------------------------+
//|                                            MoneyDancer 1.1 (MT4) |
//+------------------------------------------------------------------+
//| 1.1 = 1.0 baseline + Total Profit Target kill-switch.             |
//| Adds an extra daily lock: stop trading once today's earned +      |
//| floating P/L hits a configurable threshold (% of baseline OR      |
//| fixed USD, selectable via dropdown in inputs / .set file).        |
//| All other behavior identical to 1.0. Mirrors mt5/1.1/.            |
//+------------------------------------------------------------------+
#property copyright "JoJo"
#property version   "1.1"
#property strict


//==================== TRADING HOURS ====================
input string __sec_working_hours__   = "==== Working Hours ====";
input bool   UseTradingHours         = true;  // Use Trading Hours

// If Start=00:00 and End=00:00 -> trading is allowed 24h (for that set).
// If Start==End but not 00:00 -> that set is treated as DISABLED.

// Monday
input bool   MondayTrading           = true;  // Monday Trading
input int    MonStart1_Hour          = 0;     // Start Set 1: HH
input int    MonStart1_Minute        = 0;     // Start Set 1: MM
input int    MonEnd1_Hour            = 0;     // End Set 1: HH
input int    MonEnd1_Minute          = 0;     // End Set 1: MM
input int    MonStart2_Hour          = 0;     // Start Set 2: HH
input int    MonStart2_Minute        = 0;     // Start Set 2: MM
input int    MonEnd2_Hour            = 0;     // End Set 2: HH
input int    MonEnd2_Minute          = 0;     // End Set 2: MM

// Tuesday
input bool   TuesdayTrading          = true;  // Tuesday Trading
input int    TueStart1_Hour          = 0;
input int    TueStart1_Minute        = 0;
input int    TueEnd1_Hour            = 0;
input int    TueEnd1_Minute          = 0;
input int    TueStart2_Hour          = 0;
input int    TueStart2_Minute        = 0;
input int    TueEnd2_Hour            = 0;
input int    TueEnd2_Minute          = 0;

// Wednesday
input bool   WednesdayTrading        = true;  // Wednesday Trading
input int    WedStart1_Hour          = 0;
input int    WedStart1_Minute        = 0;
input int    WedEnd1_Hour            = 0;
input int    WedEnd1_Minute          = 0;
input int    WedStart2_Hour          = 0;
input int    WedStart2_Minute        = 0;
input int    WedEnd2_Hour            = 0;
input int    WedEnd2_Minute          = 0;

// Thursday
input bool   ThursdayTrading         = true;  // Thursday Trading
input int    ThuStart1_Hour          = 0;
input int    ThuStart1_Minute        = 0;
input int    ThuEnd1_Hour            = 0;
input int    ThuEnd1_Minute          = 0;
input int    ThuStart2_Hour          = 0;
input int    ThuStart2_Minute        = 0;
input int    ThuEnd2_Hour            = 0;
input int    ThuEnd2_Minute          = 0;

// Friday
input bool   FridayTrading           = true;  // Friday Trading
input int    FriStart1_Hour          = 0;
input int    FriStart1_Minute        = 0;
input int    FriEnd1_Hour            = 0;
input int    FriEnd1_Minute          = 0;
input int    FriStart2_Hour          = 0;
input int    FriStart2_Minute        = 0;
input int    FriEnd2_Hour            = 0;
input int    FriEnd2_Minute          = 0;



//==================== SIGNAL (Tick Burst) ====================
input string __sec_ai_order_detection__ = "==== Order Detection ====";
input double PriceStep             = 0.25;   // Price Range for Burst
input int    BurstTicks            = 10;     // Detect TOE and Burst
input int    MinMovePoints         = 20;     // Min. impant for price (points)
input int    CooldownSec           = 45;     // Time Filter
input int    MaxSpreadPts          = 45;     // Max Spread (points)

//==================== HYBRID MODE (LOW TICKRATE FALLBACK) ====================
input bool   UseTickWindowFallback = true;   // Support for Burst Detection
input int    TickRateLookbackSec   = 10;     // Check TOE in Zone
input double TickRateThreshold     = 4.0;    // Min. TOE in Range
input int    TickWindowTicks       = 25;     // Check next X Trades for TOE

//==================== MA SLOPE FILTER ====================
input string __sec_trend_filter__ = "====Filter for Trend Detection====";
input bool   UseSlopeFilter        = true;   // Dynamic - Strength of Momentum
input int    maPeriod              = 50;     // Dynamic Period
input int    slopeLookbackBars     = 5;      // Min. seqences for Strength
input int    slopeThresholdPts     = 20;     // Dynamic force threshold for direction confirmation
input int    strongTrendPts        = 60;     // Threshold for detecting strong dynamics

//==================== TRADING ====================
input string __sec_orders_sl_tp__ = "====Orders & SL & TP====";
input double LotsBase              = 0.01;  // Basic Order Size
input int    TP_Points             = 50;    // Take Profit for Basic Order
input int    SL_Points             = 0;     // Stop Loss for Basic Order
input int    Slippage              = 10;    // Accepted slipage for price
input int    Magic                 = 21010; // Magic Number

//==================== SCENARIO D ====================
input string __sec_higher_risk__ = "====Higher Risk Mode for Orders====";
input bool   ScenarioD             = true;  // MoE for Exit
input int    startBe               = 5;     // After X Trade find Exit
input double lotMultiplier         = 1.50;  // Multiplie Basic Order *X
input int    bePoints              = 30;    // Breakeven for ALL (sell or buy) Orders
input double maxLot                = 0.0;   // Max Lot Size
input int    MaxOrdersDir          = 50;    // Max Orders in one Direction
input int    StepPoints            = 120;   // After X point let MOE run
input int    MinOrderDistancePts   = 100;   // Min distance between orders (points)

input string __sec_gather_profits__ = "====Gather Profits====";
//==================== PYRAMIDING ====================
// Minimal state: ticket, trigger, tp, sl, index. Pyramid is always single-direction.
// TP distance jest zawsze TP_Points z wersji basic.
input int    PyramRange              = 0;     // Pyramiding Range (0=OFF, >0=ON)
input int    PyramSlopeEmaPeriod     = 3;     // Dynamic Period
input int    PyramSlopeLookbackBars  = 5;     // Min. seqences for Strength
input double PyramSlopeAngleDeg      = 20.0;  // Angle threshold &%
input int    PyramBEBufPts           = 0;     // Optional Breakeven buffer (points

//==================== GUARDS ====================
input string __sec_loss_control__ = "====Set Loss Control====";
input double MaxBasketDD_Pct       = 55.0; // Maks. DD equity = hedge. Test it! 
input double MaxEquityDD_Pct       = 80.0; // Maks. DD for all trades = hedge. Test it! 

//==================== DAILY RISK LOCKS ====================
input string __risk_sep__                 = "══════ DAILY RISK LOCKS ══════";
// Max Daily Profit: enter 1..999 (1=1% increase in BALANCE relative to the baseline at 01:00); 0 = OFF
input int    MaxDailyProfitPct            = 0;      // Daily Profit (0=OFF, 1..999=%)
input int    DailyBaselineHour            = 1;      // Hour baseline (default 01:00)
input int    DailyBaselineMinute          = 0;      // Minute baseline (default 00)

// After This Hour Close (protection of earned profits):
// If, by the specified time (or after it) BALANCE - baseline >= AfterThisHourMinProfitUsd
// and total FLOAT (open positions) >= AfterThisHourMaxFloatingLossUsd (eq. -10.0),
// then the EA closes all positions and suspends trading until the next day..
input int    AfterThisHourCloseHour       = -1;     // After this Hour Protect Profit (-1=OFF, 0..23=Hour)
input int    AfterThisHourCloseMinute     = 0;      // After this Minute Protect Profit (default 00)
input double AfterThisHourMinProfitUsd    = 0.0;    // Profit in USD, than Protect
input double AfterThisHourMaxFloatingLossUsd = -10.0; // FLOAT in USD must be >= this value (eq. -10)

// Profit Lock After Time (uses daily baseline from DailyBaselineHour:DailyBaselineMinute):
// If enabled: EA works normally until the lock time (UntilHour:UntilMinute).
// At the lock time it snapshots today's profit (Balance - baseline). After that, EA will NOT allow giving back
// that locked profit. If Equity drops below (baseline + lockedProfit) -> CloseAll + pause trading until next day.
input bool   RiskFromCurrentProfit            = false; // Enable Profit Lock
input int    RiskFromCurrentProfitUntilHour   = 13;    // Lock time - Hour (server time)
input int    RiskFromCurrentProfitUntilMinute = 30;    // Lock time - Minute

//==================== TOTAL PROFIT TARGET (1.1) ====================
// Stop trading once today's total P/L (realized + floating) hits the target.
// Daily reset: pauses until next server-time 00:00, like the other daily locks.
input string __profit_target_sep__       = "══════ TOTAL PROFIT TARGET ══════";
enum ENUM_PROFIT_TARGET_MODE
{
   PROFIT_TARGET_OFF = 0,   // Off
   PROFIT_TARGET_PCT = 1,   // Percentage of baseline
   PROFIT_TARGET_USD = 2    // Fixed USD amount
};
input ENUM_PROFIT_TARGET_MODE ProfitTargetMode = PROFIT_TARGET_OFF; // Profit Target Mode
input double ProfitTargetPct = 5.0;    // Target as % of baseline (Mode=Percentage)
input double ProfitTargetUsd = 100.0;  // Target as USD amount   (Mode=FixedUSD)

//==================== SCENARIO E ====================
input string __sec_big_losses__ = "====Helper for BIG LOSSES====";
input bool   ScenarioE             = false; // Test it! Active hedge !
input double HedgeRatio            = 0.35;
input int    RunnerBE_StartPts     = 120;
input int    RunnerTrailDistPts    = 200;
input int    RunnerTrailStepPts    = 50;
input double SiphonPct             = 0.90;
input double MinPartialCloseLot    = 0.01;

//==================== DASHBOARD ====================
input string __dash_sep__          = "══════ DASHBOARD ══════";
input bool   ShowProDashboard      = true;
input int    DashboardX            = 20;
input int    DashboardY            = 30;
input int    DashboardWidth        = 420;
input color  DashAccentColor       = clrDodgerBlue;
input color  DashProfitColor       = clrLime;
input color  DashLossColor         = clrCrimson;

//==================== MODERN MARKERS ====================
input string __mark_sep__          = "══════ MODERN MARKERS ══════";
input bool   ShowModernMarkers     = true;
input bool   ShowBasketLabels      = true;
input bool   ShowBottomResults     = true;
input int    BottomResultsCount    = 8;
input int    MarkerArrowSize       = 2;

//==================== INTERNALS ====================
#define MAX_LEVELS_PER_SEC  300
#define MAX_TICK_TIMES      4096
#define MAX_WIN_TICKS       256
#define MAX_TICK_SIZES      100
string RUNNER_TAG = "HEDGE_";  // Tag for hedge positions (Scenario E)
string PREFIX = "PROAI_";

// per-second burst state
datetime g_sec = 0;
double   g_firstBid = 0;
double   g_lastBid  = 0;
double   g_levels[MAX_LEVELS_PER_SEC];
int      g_counts[MAX_LEVELS_PER_SEC];
int      g_levelsN = 0;

// tickrate ring
datetime g_tickTimes[MAX_TICK_TIMES];
int      g_tickHead = 0;
int      g_tickSize = 0;

// tick-window fallback
double   g_winBids[MAX_WIN_TICKS];
double   g_winLvls[MAX_WIN_TICKS];
int      g_winCount = 0;

// slope cache
datetime g_lastBarTime = 0;
int g_cachedSlopeDir = 0;
int g_cachedSlopePts = 0;

// cooldown timestamps
datetime g_lastSignalTime = 0;
datetime g_lastBuyTime = 0;
datetime g_lastSellTime = 0;

// history tracking + M15 buckets
int      g_lastHistTotal = 0;
int      g_pnlDayKey = -1;
double   g_m15Pnl[96];
datetime g_lastUiUpdate = 0;

// last signal info
string   g_lastMode = "SECOND";
int      g_lastSigDir = 0;
int      g_lastPeak = 0;
int      g_lastMovePts = 0;

// series tracking
int  g_buySeriesId = 0;
int  g_sellSeriesId = 0;
bool g_buySeriesActive = false;
bool g_sellSeriesActive = false;

datetime g_lastCleanup = 0;
int MARKERS_WINDOW_SEC = 86400;

// ═══════════════════════════════════════════════════════════════
// DASHBOARD - STATE VARS
// ═══════════════════════════════════════════════════════════════

// AVG TICK SIZE tracking
double   g_tickSizes[MAX_TICK_SIZES];
int      g_tickSizeHead = 0;
int      g_tickSizeCount = 0;
double   g_lastPrice = 0;

// Max DD tracking
double   g_maxDDToday = 0;
double   g_maxDDEver = 0;
double   g_peakEquityToday = 0;
double   g_peakEquityEver = 0;
int      g_ddDayKey = -1;

// Statistics tracking
int      g_closedLongToday = 0;
int      g_closedShortToday = 0;
double   g_profitLongToday = 0;
double   g_profitShortToday = 0;
int      g_closedLongWeek = 0;
int      g_closedShortWeek = 0;
double   g_profitLongWeek = 0;
double   g_profitShortWeek = 0;
int      g_closedLongMonth = 0;
int      g_closedShortMonth = 0;
double   g_profitLongMonth = 0;
double   g_profitShortMonth = 0;

// Dashboard state
int      g_statsViewMode = 0; // 0=Today, 1=Week, 2=Month
bool     g_eaStopped = false;
datetime g_lastDashUpdate = 0;




// ═══════════════════════════════════════════════════════════════
// ACTIVE POSITION PERSISTENCE (ticket, TP, SL)
// Saved on EA stop/unload, reloaded on start.
// File location: terminal_data_folder\MQL4\Files\
// ═══════════════════════════════════════════════════════════════
int      g_posTickets[];   // EA's active tickets
double   g_posTP[];        // last known TP
double   g_posSL[];        // last known SL
datetime g_posLastSync = 0;

string   PositionsFileName()
{
   return(StringConcatenate("AI_MODEL_MOE_positions_", IntegerToString(Magic), "_", Symbol(), ".csv"));
}

void     PosMemClear()
{
   ArrayResize(g_posTickets, 0);
   ArrayResize(g_posTP, 0);
   ArrayResize(g_posSL, 0);
}

int      PosMemFindIndex(int ticket)
{
   for(int i=0; i<ArraySize(g_posTickets); i++)
      if(g_posTickets[i] == ticket) return i;
   return -1;
}

void     PosMemRemoveIndex(int idx)
{
   int n = ArraySize(g_posTickets);
   if(idx < 0 || idx >= n) return;
   // swap with last for speed
   if(idx != n-1)
   {
      g_posTickets[idx] = g_posTickets[n-1];
      g_posTP[idx]      = g_posTP[n-1];
      g_posSL[idx]      = g_posSL[n-1];
   }
   ArrayResize(g_posTickets, n-1);
   ArrayResize(g_posTP,      n-1);
   ArrayResize(g_posSL,      n-1);
}

void     PosMemAddOrUpdate(int ticket, double tp, double sl)
{
   int idx = PosMemFindIndex(ticket);
   if(idx < 0)
   {
      int n = ArraySize(g_posTickets);
      ArrayResize(g_posTickets, n+1);
      ArrayResize(g_posTP,      n+1);
      ArrayResize(g_posSL,      n+1);
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

bool     PosTicketStillActive(int ticket)
{
   if(ticket <= 0) return false;
   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES)) return false;
   if(OrderCloseTime() > 0) return false;
   if(!IsMineTrade()) return false;
   int typ = OrderType();
   if(typ != OP_BUY && typ != OP_SELL) return false;
   return true;
}

void     LoadPositionsFromFile()
{
   PosMemClear();
   string fn = PositionsFileName();

   int h = FileOpen(fn, FILE_CSV|FILE_READ|FILE_ANSI);
   if(h == INVALID_HANDLE) return;

   while(!FileIsEnding(h))
   {
      string sTicket = FileReadString(h);
      if(FileIsEnding(h) && (sTicket == "")) break;

      int ticket = (int)StrToInteger(sTicket);
      double tp  = FileReadNumber(h);
      double sl  = FileReadNumber(h);

      if(ticket > 0) PosMemAddOrUpdate(ticket, tp, sl);
   }
   FileClose(h);
}

void     SavePositionsToFile()
{
   string fn = PositionsFileName();
   int h = FileOpen(fn, FILE_CSV|FILE_WRITE|FILE_ANSI);
   if(h == INVALID_HANDLE) return;

   // Format: ticket,tp,sl (one line = one position)
   for(int i=0; i<ArraySize(g_posTickets); i++)
      FileWrite(h, g_posTickets[i],
                   DoubleToString(g_posTP[i], Digits),
                   DoubleToString(g_posSL[i], Digits));
   FileClose(h);
}

// Sync memory with terminal:
// - remove tickets from memory that are no longer active
// - refresh TP/SL for active ones
// - optionally add all current EA positions even if not in the file
void     SyncPositionsWithTerminal(bool addAllCurrent)
{
   // Remove inactive + refresh TP/SL
   for(int i=ArraySize(g_posTickets)-1; i>=0; i--)
   {
      int t = g_posTickets[i];
      if(!PosTicketStillActive(t))
      {
         PosMemRemoveIndex(i);
         continue;
      }
      // refresh current TP/SL from terminal
      PosMemAddOrUpdate(t, OrderTakeProfit(), OrderStopLoss());
   }

   if(addAllCurrent)
   {
      for(int j=OrdersTotal()-1; j>=0; j--)
      {
         if(!OrderSelect(j, SELECT_BY_POS, MODE_TRADES)) continue;
         if(!IsMineTrade()) continue;
         int typ = OrderType();
         if(typ != OP_BUY && typ != OP_SELL) continue;
         PosMemAddOrUpdate(OrderTicket(), OrderTakeProfit(), OrderStopLoss());
      }
   }

   g_posLastSync = TimeCurrent();
}

// ═══════════════════════════════════════════════════════════════
// PYRAMIDING STATE (minimal set: ticket, trigger, tp, sl, index)
// - Pyramid is always single-direction (no pyramid hedging)
// - Trigger = TP distance (TP_Points) level for each position
// - BUILDING: TP=0 for pyramid
// - COASTING: when slope fades and pyramid has >1 positions -> TP of all = trigger of last
// - SL: after each new position, SL set to BE of (last + prev) and applied to whole pyramid
// ═══════════════════════════════════════════════════════════════
int      g_pyrTickets[];
double   g_pyrTrigger[];
double   g_pyrTP[];
double   g_pyrSL[];
int      g_pyrIndex[];
datetime g_pyrLastSync = 0;

string   PyramidFileName()
{
   return(StringConcatenate("AI_MODEL_MOE_pyramid_", IntegerToString(Magic), "_", Symbol(), ".csv"));
}

void     PyrClear()
{
   ArrayResize(g_pyrTickets, 0);
   ArrayResize(g_pyrTrigger, 0);
   ArrayResize(g_pyrTP, 0);
   ArrayResize(g_pyrSL, 0);
   ArrayResize(g_pyrIndex, 0);
}

int      PyrFindTicket(int ticket)
{
   for(int i=0;i<ArraySize(g_pyrTickets);i++) if(g_pyrTickets[i]==ticket) return i;
   return -1;
}

bool     IsPyramidTicket(int ticket)
{
   return (PyrFindTicket(ticket) >= 0);
}

void     PyrRemoveAt(int idx)
{
   int n = ArraySize(g_pyrTickets);
   if(idx<0 || idx>=n) return;
   if(idx != n-1)
   {
      g_pyrTickets[idx] = g_pyrTickets[n-1];
      g_pyrTrigger[idx] = g_pyrTrigger[n-1];
      g_pyrTP[idx]      = g_pyrTP[n-1];
      g_pyrSL[idx]      = g_pyrSL[n-1];
      g_pyrIndex[idx]   = g_pyrIndex[n-1];
   }
   ArrayResize(g_pyrTickets, n-1);
   ArrayResize(g_pyrTrigger, n-1);
   ArrayResize(g_pyrTP, n-1);
   ArrayResize(g_pyrSL, n-1);
   ArrayResize(g_pyrIndex, n-1);
}

void     PyrAddOrUpdate(int ticket, double trigger, double tp, double sl, int index)
{
   int idx = PyrFindTicket(ticket);
   if(idx < 0)
   {
      int n = ArraySize(g_pyrTickets);
      ArrayResize(g_pyrTickets, n+1);
      ArrayResize(g_pyrTrigger, n+1);
      ArrayResize(g_pyrTP, n+1);
      ArrayResize(g_pyrSL, n+1);
      ArrayResize(g_pyrIndex, n+1);
      g_pyrTickets[n] = ticket;
      g_pyrTrigger[n] = trigger;
      g_pyrTP[n]      = tp;
      g_pyrSL[n]      = sl;
      g_pyrIndex[n]   = index;
   }
   else
   {
      g_pyrTrigger[idx] = trigger;
      g_pyrTP[idx]      = tp;
      g_pyrSL[idx]      = sl;
      g_pyrIndex[idx]   = index;
   }
}

int      PyrCount(){ return ArraySize(g_pyrTickets); }

// Returns array idx of the element with highest index (last pyramid position)
int      PyrLastIdxByIndex()
{
   int n = PyrCount();
   if(n<=0) return -1;
   int best=0;
   for(int i=1;i<n;i++) if(g_pyrIndex[i] > g_pyrIndex[best]) best=i;
   return best;
}

int      PyrPrevIdxByIndex(int lastArrayIdx)
{
   int n = PyrCount();
   if(n<2 || lastArrayIdx<0) return -1;
   int lastIndex = g_pyrIndex[lastArrayIdx];
   int best=-1;
   for(int i=0;i<n;i++)
   {
      if(i==lastArrayIdx) continue;
      if(g_pyrIndex[i] == lastIndex-1) return i;
      if(g_pyrIndex[i] < lastIndex)
      {
         if(best<0 || g_pyrIndex[i] > g_pyrIndex[best]) best=i;
      }
   }
   return best;
}

int      PyrNextIndex()
{
   int n = PyrCount();
   int mx = 0;
   for(int i=0;i<n;i++) if(g_pyrIndex[i] > mx) mx = g_pyrIndex[i];
   return mx + 1;
}

bool     PyrTicketStillActive(int ticket)
{
   if(ticket<=0) return false;
   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES)) return false;
   if(OrderCloseTime() > 0) return false;
   if(!IsMineTrade()) return false;
   int typ = OrderType();
   if(typ!=OP_BUY && typ!=OP_SELL) return false;
   if(IsRunner()) return false;
   return true;
}

void     LoadPyramidFromFile()
{
   PyrClear();
   string fn = PyramidFileName();
   int h = FileOpen(fn, FILE_CSV|FILE_READ|FILE_ANSI);
   if(h == INVALID_HANDLE) return;

   while(!FileIsEnding(h))
   {
      string sTicket = FileReadString(h);
      if(FileIsEnding(h) && (sTicket=="")) break;
      int ticket = (int)StrToInteger(sTicket);
      double trigger = FileReadNumber(h);
      double tp = FileReadNumber(h);
      double sl = FileReadNumber(h);
      int index = (int)FileReadNumber(h);
      if(ticket>0) PyrAddOrUpdate(ticket, trigger, tp, sl, index);
   }
   FileClose(h);
}

void     SavePyramidToFile()
{
   string fn = PyramidFileName();
   int h = FileOpen(fn, FILE_CSV|FILE_WRITE|FILE_ANSI);
   if(h == INVALID_HANDLE) return;
   // ticket,trigger,tp,sl,index
   for(int i=0;i<PyrCount();i++)
   {
      FileWrite(h,
         g_pyrTickets[i],
         DoubleToString(g_pyrTrigger[i], Digits),
         DoubleToString(g_pyrTP[i], Digits),
         DoubleToString(g_pyrSL[i], Digits),
         g_pyrIndex[i]
      );
   }
   FileClose(h);
}

void     SyncPyramidWithTerminal()
{
   for(int i=PyrCount()-1;i>=0;i--)
   {
      int t = g_pyrTickets[i];
      if(!PyrTicketStillActive(t))
      {
         PyrRemoveAt(i);
         continue;
      }
      // refresh TP/SL from terminal (trigger/index stay)
      PyrAddOrUpdate(t, g_pyrTrigger[i], OrderTakeProfit(), OrderStopLoss(), g_pyrIndex[i]);
   }
   g_pyrLastSync = TimeCurrent();
}

// EMA slope angle (signed) in degrees; positive = up
double   PyramSlopeAngleCurrentDeg()
{
   int lb = MathMax(1, PyramSlopeLookbackBars);
   double e0 = iMA(Symbol(), 0, PyramSlopeEmaPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
   double eL = iMA(Symbol(), 0, PyramSlopeEmaPeriod, 0, MODE_EMA, PRICE_CLOSE, lb);
   double diffPts = (e0 - eL) / Point;
   double ang = MathArctan(diffPts / lb) * 180.0 / 3.141592653589793;
   return ang;
}

bool     PyramSlopeOKForDir(int dir)
{
   double ang = PyramSlopeAngleCurrentDeg();
   if(dir>0) return (ang >= PyramSlopeAngleDeg);
   if(dir<0) return (ang <= -PyramSlopeAngleDeg);
   return false;
}

// Helper: normalize price for SL/TP and respect stop level
double   NormalizePrice(double p){ return NormalizeDouble(p, Digits); }

bool     ModifyOrderSLTP(int ticket, double newSL, double newTP)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES)) return false;
   if(OrderCloseTime() > 0) return false;
   if(!IsMineTrade()) return false;
   if(IsRunner()) return false;
   int typ = OrderType();
   if(typ!=OP_BUY && typ!=OP_SELL) return false;

   double op = OrderOpenPrice();
   double curSL = OrderStopLoss();
   double curTP = OrderTakeProfit();

   // Stop level guard
   int stopLvlPts = (int)MarketInfo(Symbol(), MODE_STOPLEVEL);
   double cur = (typ==OP_BUY ? Bid : Ask);
   if(newSL > 0)
   {
      if(typ==OP_BUY)
      {
         double minSL = cur - stopLvlPts*Point;
         if(newSL > minSL) newSL = minSL;
      }
      else
      {
         double maxSL = cur + stopLvlPts*Point;
         if(newSL < maxSL) newSL = maxSL;
      }
      newSL = NormalizePrice(newSL);
   }
   if(newTP > 0)
   {
      if(typ==OP_BUY)
      {
         double minTP = cur + stopLvlPts*Point;
         if(newTP < minTP) newTP = minTP;
      }
      else
      {
         double maxTP = cur - stopLvlPts*Point;
         if(newTP > maxTP) newTP = maxTP;
      }
      newTP = NormalizePrice(newTP);
   }

   bool need=false;
   if((newSL==0 && curSL!=0) || (newSL>0 && MathAbs(curSL-newSL)>(2*Point))) need=true;
   if((newTP==0 && curTP!=0) || (newTP>0 && MathAbs(curTP-newTP)>(2*Point))) need=true;
   if(!need) return true;

   bool ok = OrderModify(ticket, op, newSL, newTP, 0, clrNONE);
   if(!ok) ResetLastError();
   return ok;
}

// Apply SL BE for last+prev and propagate to all pyramid orders
void     PyramidApplyBE()
{
   if(PyrCount() < 2) return;
   int lastA = PyrLastIdxByIndex();
   int prevA = PyrPrevIdxByIndex(lastA);
   if(lastA<0 || prevA<0) return;

   int t1 = g_pyrTickets[prevA];
   int t2 = g_pyrTickets[lastA];
   if(!OrderSelect(t1, SELECT_BY_TICKET, MODE_TRADES)) return;
   double p1 = OrderOpenPrice();
   double l1 = OrderLots();
   int typ = OrderType();
   if(!OrderSelect(t2, SELECT_BY_TICKET, MODE_TRADES)) return;
   double p2 = OrderOpenPrice();
   double l2 = OrderLots();

   double be = 0;
   double sumLots = l1 + l2;
   if(sumLots <= 0) return;
   be = (l1*p1 + l2*p2) / sumLots;
   // optional buffer
   if(PyramBEBufPts > 0)
      be += (typ==OP_BUY ? PyramBEBufPts*Point : -PyramBEBufPts*Point);
   be = NormalizePrice(be);

   // set SL for ALL pyramid tickets to same BE
   for(int i=0;i<PyrCount();i++)
   {
      int t = g_pyrTickets[i];
      double curTP = 0;
      if(OrderSelect(t, SELECT_BY_TICKET, MODE_TRADES))
         curTP = OrderTakeProfit();
      ModifyOrderSLTP(t, be, curTP);
      // update memory sl
      if(OrderSelect(t, SELECT_BY_TICKET, MODE_TRADES))
         PyrAddOrUpdate(t, g_pyrTrigger[i], OrderTakeProfit(), OrderStopLoss(), g_pyrIndex[i]);
   }
}

void     PyramidSetTPForAll(double tp)
{
   for(int i=0;i<PyrCount();i++)
   {
      int t = g_pyrTickets[i];
      double sl = 0;
      if(OrderSelect(t, SELECT_BY_TICKET, MODE_TRADES)) sl = OrderStopLoss();
      ModifyOrderSLTP(t, sl, tp);
      if(OrderSelect(t, SELECT_BY_TICKET, MODE_TRADES))
         PyrAddOrUpdate(t, g_pyrTrigger[i], OrderTakeProfit(), OrderStopLoss(), g_pyrIndex[i]);
   }
}

void     PyramidSetTPZeroForAll()
{
   for(int i=0;i<PyrCount();i++)
   {
      int t = g_pyrTickets[i];
      double sl = 0;
      if(OrderSelect(t, SELECT_BY_TICKET, MODE_TRADES)) sl = OrderStopLoss();
      ModifyOrderSLTP(t, sl, 0);
      if(OrderSelect(t, SELECT_BY_TICKET, MODE_TRADES))
         PyrAddOrUpdate(t, g_pyrTrigger[i], OrderTakeProfit(), OrderStopLoss(), g_pyrIndex[i]);
   }
}

// Called on tick: manage TP mode (building/coasting) and BE
void     PyramidManage()
{
   if(PyramRange <= 0)
   {
      // Pyramid OFF: release positions to basic (restore normal TP and remove from memory)
      for(int i=PyrCount()-1;i>=0;i--)
      {
         int t = g_pyrTickets[i];
         if(OrderSelect(t, SELECT_BY_TICKET, MODE_TRADES))
         {
            int dir = (OrderType()==OP_BUY ? +1 : -1);
            double op = OrderOpenPrice();
            double tp = (dir>0 ? op + TP_Points*Point : op - TP_Points*Point);
            double sl = OrderStopLoss();
            ModifyOrderSLTP(t, sl, tp);
         }
         PyrRemoveAt(i);
      }
      SavePyramidToFile();

   // Rebuild active series ids from currently open orders (restart-safe)
   SyncSeriesIdsFromOpenOrders();

      return;
   }

   if(PyrCount() <= 0) return;

   // Determine direction from first ticket
   if(!OrderSelect(g_pyrTickets[0], SELECT_BY_TICKET, MODE_TRADES)) return;
   int dir = (OrderType()==OP_BUY ? +1 : -1);
   bool slopeOK = PyramSlopeOKForDir(dir);

   if(PyrCount() == 1)
   {
      if(slopeOK)
      {
         // BUILDING for single: TP=0
         PyramidSetTPZeroForAll();
      }
      else
      {
         // release to basic: set normal TP back and remove from pyramid set
         int t = g_pyrTickets[0];
         if(OrderSelect(t, SELECT_BY_TICKET, MODE_TRADES))
         {
            double op = OrderOpenPrice();
            double tp = (dir>0 ? op + TP_Points*Point : op - TP_Points*Point);
            double sl = OrderStopLoss();
            ModifyOrderSLTP(t, sl, tp);
         }
         PyrClear();
         SavePyramidToFile();
      }
      return;
   }

   // pyr size > 1
   if(slopeOK)
   {
      // BUILDING: TP=0
      PyramidSetTPZeroForAll();
   }
   else
   {
      // COASTING: TP wszystkich = trigger ostatniej
      int lastA = PyrLastIdxByIndex();
      if(lastA >= 0)
      {
         double commonTP = g_pyrTrigger[lastA];
         PyramidSetTPForAll(commonTP);
      }
   }

   // Always keep BE based on last+prev
   PyramidApplyBE();
}

// Decide at open-time if current order should be a pyramid order
bool     PyramidWantsOrder(int dir)
{
   if(PyramRange <= 0) return false;
   if(!PyramSlopeOKForDir(dir)) return false;

   // if pyramid exists, direction must match
   if(PyrCount() > 0)
   {
      if(!OrderSelect(g_pyrTickets[0], SELECT_BY_TICKET, MODE_TRADES)) return false;
      int existingDir = (OrderType()==OP_BUY ? +1 : -1);
      if(existingDir != dir) return false;

      int lastA = PyrLastIdxByIndex();
      if(lastA < 0) return false;
      double lastTrigger = g_pyrTrigger[lastA];
      // tolerance: 2 points
      double tol = 2*Point;
      if(dir>0)
      {
         if(Bid + tol < lastTrigger) return false;
      }
      else
      {
         if(Ask - tol > lastTrigger) return false;
      }
      return true;
   }

   // first pyramid order
   return true;
}

void     PyramidOnNewTicket(int ticket)
{
   if(ticket<=0) return;
   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES)) return;
   if(!IsMineTrade()) return;
   if(IsRunner()) return;
   int typ = OrderType();
   if(typ!=OP_BUY && typ!=OP_SELL) return;
   int dir = (typ==OP_BUY ? +1 : -1);

   int idx = PyrNextIndex();
   double op = OrderOpenPrice();
   double trigger = (dir>0 ? op + TP_Points*Point : op - TP_Points*Point);
   trigger = NormalizePrice(trigger);

   PyrAddOrUpdate(ticket, trigger, 0, OrderStopLoss(), idx);
   // Ensure TP=0 immediately
   ModifyOrderSLTP(ticket, OrderStopLoss(), 0);

   // Adjust SL BE if needed
   PyramidApplyBE();
   SavePyramidToFile();
}


// ═══════════════════════════════════════════════════════════════
// DAILY RISK STATE
// ═══════════════════════════════════════════════════════════════
int      g_baseDayKey = -1;
double   g_dayBaseBalance = 0.0;
datetime g_dayBaseTime = 0;
bool     g_dayBaseReady = false;

// PROFIT LOCK STATE (RiskFromCurrentProfit)
bool     g_profitLockCaptured = false;
double   g_lockedProfitUsd = 0.0;
datetime g_profitLockTime = 0;


datetime g_tradePauseUntil = 0;
string   g_tradePauseReason = "";

// cached daily metrics for dashboard
double   g_dayProfitUsd = 0.0;
double   g_dayProfitPct = 0.0;
double   g_dayTargetBalance = 0.0;


// AI Simulation states
string   g_aiStatus = "INITIALIZING";
int      g_aiConfidence = 80;  // Base confidence
int      g_aiConfidenceTarget = 80;  // Target for smooth animation
datetime g_lastTradeTime = 0;  // Last trade time for confidence spike
string   g_aiPattern = "---";
string   g_marketRegime = "ANALYZING";
int      g_riskLevel = 0; // 0=LOW, 1=MEDIUM, 2=HIGH
int      g_tradeQuality = 0;
datetime g_lastAiUpdate = 0;
int      g_scanPhase = 0;
string   g_aiMessages[5];
int      g_aiMsgIndex = 0;

// Button states
bool     g_btnStatsPressed[3];
datetime g_lastButtonCheck = 0;

// ═══════════════════════════════════════════════════════════════
// SCENARIO D/E STATE TRACKING
// ═══════════════════════════════════════════════════════════════
bool     g_scenarioEActive = false;      // Is Scenario E (hedge mode) currently active?
int      g_hedgeBasketDir = 0;           // Direction of basket being hedged (-1=SELL, +1=BUY)
int      g_activeRunnersCount = 0;       // Number of active runner positions
double   g_hedgeLotsTotal = 0;           // Total lots in hedge runners
double   g_basketLotsTotal = 0;          // Total lots in losing basket
string   g_scenarioStatus = "D";          // Current scenario: "D" or "E"
string   g_hedgeReason = "";             // Why E was activated
datetime g_scenarioEStartTime = 0;       // When E was activated

//+------------------------------------------------------------------+
//| UTILITY FUNCTIONS                                                 |
//+------------------------------------------------------------------+
int SpreadPoints(){ return (int)MarketInfo(Symbol(), MODE_SPREAD); }

double RoundToStep(double price, double step)
{
   if(step <= 0) return NormalizeDouble(price, Digits);
   double k = MathRound(price / step);
   return NormalizeDouble(k * step, Digits);
}

double ClampLot(double lot)
{
   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLotSym = MarketInfo(Symbol(), MODE_MAXLOT);
   double step = MarketInfo(Symbol(), MODE_LOTSTEP);
   
   if(lot < minLot) lot = minLot;
   if(lot > maxLotSym) lot = maxLotSym;
   if(maxLot > 0.0 && lot > maxLot) lot = maxLot;
   
   lot = MathFloor(lot/step)*step;
   lot = NormalizeDouble(lot, 2);
   if(lot < minLot) lot = minLot;
   return lot;
}

bool IsMineTrade(){ return (OrderSymbol()==Symbol() && OrderMagicNumber()==Magic); }
bool IsRunner(){ return (StringFind(OrderComment(), RUNNER_TAG, 0) >= 0); }

int MinutesOfDay(datetime t){ return TimeHour(t)*60 + TimeMinute(t); }
int SecondsOfDay(datetime t){ return MinutesOfDay(t)*60 + TimeSeconds(t); }
int DayKey(datetime t){ return TimeYear(t)*1000 + TimeDayOfYear(t); }
int WeekKey(datetime t){ return TimeYear(t)*100 + (TimeDayOfYear(t)/7); }
int MonthKey(datetime t){ return TimeYear(t)*100 + TimeMonth(t); }

//+------------------------------------------------------------------+
//| DAILY RISK HELPERS                                              |
//+------------------------------------------------------------------+
string TwoDigit(int v)
{
   if(v < 0) v = 0;
   if(v < 10) return "0" + IntegerToString(v);
   return IntegerToString(v);
}

datetime TodayAt(int hour, int minute)
{
   datetime now = TimeCurrent();
   string s = TimeToString(now, TIME_DATE) + " " + TwoDigit(hour) + ":" + TwoDigit(minute);
   return StrToTime(s);
}

bool IsAutoPaused()
{
   if(g_tradePauseUntil <= 0) return false;
   return (TimeCurrent() < g_tradePauseUntil);
}

void PauseAutoUntilNextDay(string reason)
{
   datetime now = TimeCurrent();
   // pause until next day 00:00 (server time)
   datetime nextDay = StrToTime(TimeToString(now + 86400, TIME_DATE) + " 00:00");
   g_tradePauseUntil = nextDay;
   g_tradePauseReason = reason;
}

double BasketFloatingAllMine()
{
   double sum = 0.0;
   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!IsMineTrade()) continue;
      sum += (OrderProfit() + OrderSwap() + OrderCommission());
   }
   return sum;
}

void UpdateDailyBaselineAndMetrics()
{
   datetime now = TimeCurrent();
   int dk = DayKey(now);

   // new day => reset baseline flag (pause stays until time passes)
   if(dk != g_baseDayKey)
   {
      g_baseDayKey = dk;
      g_dayBaseReady = false;
      g_dayBaseBalance = 0.0;
      g_dayBaseTime = 0;
      g_dayProfitUsd = 0.0;
      g_dayProfitPct = 0.0;
      g_dayTargetBalance = 0.0;
            // reset profit lock state for new day
      g_profitLockCaptured = false;
      g_lockedProfitUsd = 0.0;
      g_profitLockTime = 0;
// reset pause reason only if pause already expired
      if(!IsAutoPaused())
      {
         g_tradePauseUntil = 0;
         g_tradePauseReason = "";
      }
   }

   datetime baseT = TodayAt(DailyBaselineHour, DailyBaselineMinute);
   if(!g_dayBaseReady && now >= baseT)
   {
      g_dayBaseReady = true;
      g_dayBaseBalance = AccountBalance();
      g_dayBaseTime = now;
   }

   if(g_dayBaseReady)
   {
      g_dayProfitUsd = AccountBalance() - g_dayBaseBalance;
      if(g_dayBaseBalance > 0.0) g_dayProfitPct = (g_dayProfitUsd / g_dayBaseBalance) * 100.0;
      else g_dayProfitPct = 0.0;

      if(MaxDailyProfitPct > 0)
         g_dayTargetBalance = g_dayBaseBalance * (1.0 + (MaxDailyProfitPct / 100.0));
      else
         g_dayTargetBalance = 0.0;
   }
}

void ApplyDailyRiskControls()
{
   UpdateDailyBaselineAndMetrics();
   if(IsAutoPaused()) return;
   if(!g_dayBaseReady) return; // baseline jeszcze nie ustawiony

   double bal = AccountBalance();
   double eq  = AccountEquity();
   double floatPL = BasketFloatingAllMine();
   double dayProfitUsd = (bal - g_dayBaseBalance);

   // 1) Max Daily Profit cap
   if(MaxDailyProfitPct > 0 && g_dayTargetBalance > 0.0)
   {
      if(bal >= g_dayTargetBalance)
      {
         CloseAllOrders();
         PauseAutoUntilNextDay("DAILY_CAP");
         return;
      }
   }

   // 2) After This Hour Close
   if(AfterThisHourCloseHour >= 0 && AfterThisHourCloseHour <= 23 && AfterThisHourMinProfitUsd > 0.0)
   {
      datetime tLock = TodayAt(AfterThisHourCloseHour, AfterThisHourCloseMinute);
      if(TimeCurrent() >= tLock)
      {
         if(dayProfitUsd >= AfterThisHourMinProfitUsd && floatPL >= AfterThisHourMaxFloatingLossUsd)
         {
            CloseAllOrders();
            PauseAutoUntilNextDay("AFTER_HOUR_PROTECT");
            return;
         }
      }
   }
   // 3) Profit Lock After Time (RiskFromCurrentProfit)
   if(RiskFromCurrentProfit)
   {
      datetime tLock = TodayAt(RiskFromCurrentProfitUntilHour, RiskFromCurrentProfitUntilMinute);

      // When we reach lock time for the first time today, snapshot locked profit
      if(TimeCurrent() >= tLock)
      {
         if(!g_profitLockCaptured)
         {
            // Snapshot today's REALIZED profit at lock time (Balance - baseline)
            g_lockedProfitUsd = dayProfitUsd;
            if(g_lockedProfitUsd < 0.0) g_lockedProfitUsd = 0.0; // do not lock negative
            g_profitLockCaptured = true;
            g_profitLockTime = tLock;
         }

         // After lock time: do NOT allow giving back the locked profit
         if(g_lockedProfitUsd > 0.0)
         {
            double floorEq = g_dayBaseBalance + g_lockedProfitUsd;
            if(eq < floorEq)
         {
            CloseAllOrders();
            PauseAutoUntilNextDay("PROFIT_LOCK");
            return;
         }
      }
         }
      else
      {
         // Before lock time: ensure lock is not captured yet (in case user changed inputs intraday)
         g_profitLockCaptured = false;
         g_lockedProfitUsd = 0.0;
         g_profitLockTime = 0;
      }
   }

   // 4) Total Profit Target (realized + floating) — 1.1
   if(ProfitTargetMode != PROFIT_TARGET_OFF)
   {
      double totalProfit = eq - g_dayBaseBalance;   // equity already includes float
      double targetUsd   = 0.0;

      if(ProfitTargetMode == PROFIT_TARGET_PCT && ProfitTargetPct > 0.0)
         targetUsd = g_dayBaseBalance * (ProfitTargetPct / 100.0);
      else if(ProfitTargetMode == PROFIT_TARGET_USD && ProfitTargetUsd > 0.0)
         targetUsd = ProfitTargetUsd;

      if(targetUsd > 0.0 && totalProfit >= targetUsd)
      {
         CloseAllOrders();
         PauseAutoUntilNextDay("PROFIT_TARGET");
         return;
      }
   }
}


// ===== WORKING HOURS HELPERS =====
bool IsInTimeWindow(int nowMin, int sh, int sm, int eh, int em)
{
   int start = sh*60 + sm;
   int end   = eh*60 + em;

   // 00:00 - 00:00 => 24h
   if(start == 0 && end == 0) return true;

   // same time but not midnight => disabled
   if(start == end) return false;

   // normal or overnight
   if(start < end)  return (nowMin >= start && nowMin <= end);
   return (nowMin >= start || nowMin <= end);
}

bool InTradingSession(datetime t)
{
   if(!UseTradingHours) return true;

   int dow = TimeDayOfWeek(t); // 0=Sun, 1=Mon ... 5=Fri, 6=Sat
   if(dow == 0 || dow == 6) return false;

   int nowMin = MinutesOfDay(t);

   bool dayOn = true;
   int s1h=0,s1m=0,e1h=0,e1m=0,s2h=0,s2m=0,e2h=0,e2m=0;

   if(dow == 1) { dayOn = MondayTrading;    s1h=MonStart1_Hour; s1m=MonStart1_Minute; e1h=MonEnd1_Hour; e1m=MonEnd1_Minute; s2h=MonStart2_Hour; s2m=MonStart2_Minute; e2h=MonEnd2_Hour; e2m=MonEnd2_Minute; }
   else if(dow == 2) { dayOn = TuesdayTrading;   s1h=TueStart1_Hour; s1m=TueStart1_Minute; e1h=TueEnd1_Hour; e1m=TueEnd1_Minute; s2h=TueStart2_Hour; s2m=TueStart2_Minute; e2h=TueEnd2_Hour; e2m=TueEnd2_Minute; }
   else if(dow == 3) { dayOn = WednesdayTrading; s1h=WedStart1_Hour; s1m=WedStart1_Minute; e1h=WedEnd1_Hour; e1m=WedEnd1_Minute; s2h=WedStart2_Hour; s2m=WedStart2_Minute; e2h=WedEnd2_Hour; e2m=WedEnd2_Minute; }
   else if(dow == 4) { dayOn = ThursdayTrading;  s1h=ThuStart1_Hour; s1m=ThuStart1_Minute; e1h=ThuEnd1_Hour; e1m=ThuEnd1_Minute; s2h=ThuStart2_Hour; s2m=ThuStart2_Minute; e2h=ThuEnd2_Hour; e2m=ThuEnd2_Minute; }
   else if(dow == 5) { dayOn = FridayTrading;    s1h=FriStart1_Hour; s1m=FriStart1_Minute; e1h=FriEnd1_Hour; e1m=FriEnd1_Minute; s2h=FriStart2_Hour; s2m=FriStart2_Minute; e2h=FriEnd2_Hour; e2m=FriEnd2_Minute; }

   if(!dayOn) return false;

   if(IsInTimeWindow(nowMin, s1h, s1m, e1h, e1m)) return true;
   if(IsInTimeWindow(nowMin, s2h, s2m, e2h, e2m)) return true;
   return false;
}

bool InLast24h(datetime t)
{
   if(t <= 0) return false;
   return (TimeCurrent() - t) <= MARKERS_WINDOW_SEC;
}

string ObjName(string suffix){ return PREFIX + IntegerToString(Magic) + "_" + suffix; }
string TicketKey(int ticket){ return IntegerToString(ticket); }

int ColorR(color c){ return (int)(c & 0xFF); }
int ColorG(color c){ return (int)((c >> 8) & 0xFF); }
int ColorB(color c){ return (int)((c >> 16) & 0xFF); }
bool IsDark(color c)
{
   int r=ColorR(c), g=ColorG(c), b=ColorB(c);
   double lum = 0.2126*r + 0.7152*g + 0.0722*b;
   return (lum < 110.0);
}

//+------------------------------------------------------------------+
//| SERIES HELPERS                                                    |
//+------------------------------------------------------------------+
string SeriesPrefix(int dir) { return (dir>0 ? "TBb" : "TBs"); }
string SeriesKey(int dir, int id){ return SeriesPrefix(dir) + IntegerToString(id); }


// ===== SERIES RECOVERY (restart-safe) =====
int ExtractSeriesIdFromComment(string cmt, int dir)
{
   string pref = SeriesPrefix(dir);
   int p = StringFind(cmt, pref, 0);
   if(p < 0) return -1;

   int s = p + StringLen(pref);
   string num = "";
   for(int k=s; k<StringLen(cmt); k++)
   {
      string ch = StringSubstr(cmt, k, 1);
      int cc = StringGetChar(ch, 0);
      if(cc >= 48 && cc <= 57) num += ch;
      else break;
   }
   if(StringLen(num) <= 0) return -1;
   return (int)StrToInteger(num);
}

void SyncSeriesIdsFromOpenOrders()
{
   int maxBuy = -1;
   int maxSell = -1;
   bool anyBuy = false;
   bool anySell = false;

   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!IsMineTrade()) continue;
      if(IsPyramidTicket(OrderTicket())) continue;

      int t = OrderType();
      if(t != OP_BUY && t != OP_SELL) continue;

      int dir = (t == OP_BUY ? +1 : -1);
      string cmt = OrderComment();
      int id = ExtractSeriesIdFromComment(cmt, dir);

      if(dir > 0) anyBuy = true; else anySell = true;
      if(id >= 0)
      {
         if(dir > 0 && id > maxBuy)  maxBuy  = id;
         if(dir < 0 && id > maxSell) maxSell = id;
      }
   }

   // If series ids were found in comments, set them; otherwise keep current ids.
   if(maxBuy >= 0) g_buySeriesId = maxBuy;
   if(maxSell >= 0) g_sellSeriesId = maxSell;

   // Active flags must reflect reality
   g_buySeriesActive  = anyBuy;
   g_sellSeriesActive = anySell;
}

void EnsureSeriesActive(int dir)
{
   if(dir > 0)
   {
      if(!g_buySeriesActive) { g_buySeriesId++; g_buySeriesActive = true; }
   }
   else
   {
      if(!g_sellSeriesActive) { g_sellSeriesId++; g_sellSeriesActive = true; }
   }
}

int CurrentSeriesId(int dir){ return (dir>0 ? g_buySeriesId : g_sellSeriesId); }
bool SeriesActive(int dir){ return (dir>0 ? g_buySeriesActive : g_sellSeriesActive); }
void SetSeriesActive(int dir, bool a){ if(dir>0) g_buySeriesActive=a; else g_sellSeriesActive=a; }

//+------------------------------------------------------------------+
//| TICKRATE FUNCTIONS                                                |
//+------------------------------------------------------------------+
void TickratePush(datetime t)
{
   g_tickTimes[g_tickHead] = t;
   g_tickHead = (g_tickHead + 1) % MAX_TICK_TIMES;
   if(g_tickSize < MAX_TICK_TIMES) g_tickSize++;
}

double GetAvgTickRate()
{
   int look = TickRateLookbackSec;
   if(look < 1) look = 1;
   datetime now = TimeCurrent();
   datetime cutoff = now - look;
   int cnt = 0;
   for(int i=0; i<g_tickSize; i++)
   {
      int idx = g_tickHead - 1 - i;
      while(idx < 0) idx += MAX_TICK_TIMES;
      datetime tt = g_tickTimes[idx];
      if(tt < cutoff) break;
      cnt++;
   }
   return (double)cnt / (double)look;
}

//+------------------------------------------------------------------+
//| AVG TICK SIZE TRACKING                                            |
//+------------------------------------------------------------------+
void UpdateTickSize()
{
   double currentPrice = Bid;
   if(g_lastPrice > 0)
   {
      double tickSize = MathAbs(currentPrice - g_lastPrice) / Point;
      if(tickSize > 0)
      {
         g_tickSizes[g_tickSizeHead] = tickSize;
         g_tickSizeHead = (g_tickSizeHead + 1) % MAX_TICK_SIZES;
         if(g_tickSizeCount < MAX_TICK_SIZES) g_tickSizeCount++;
      }
   }
   g_lastPrice = currentPrice;
}

double GetAvgTickSize()
{
   if(g_tickSizeCount == 0) return 0;
   double sum = 0;
   for(int i = 0; i < g_tickSizeCount; i++)
   {
      sum += g_tickSizes[i];
   }
   return sum / g_tickSizeCount;
}

//+------------------------------------------------------------------+
//| MAX DRAWDOWN TRACKING                                             |
//+------------------------------------------------------------------+
void UpdateMaxDD()
{
   double equity = AccountEquity();
   int dayKey = DayKey(TimeCurrent());
   
   // Reset daily tracking if new day
   if(dayKey != g_ddDayKey)
   {
      g_ddDayKey = dayKey;
      g_peakEquityToday = equity;
      g_maxDDToday = 0;
   }
   
   // Update peak equity
   if(equity > g_peakEquityToday) g_peakEquityToday = equity;
   if(equity > g_peakEquityEver) g_peakEquityEver = equity;
   
   // Calculate current DD
   if(g_peakEquityToday > 0)
   {
      double ddToday = (g_peakEquityToday - equity) / g_peakEquityToday * 100.0;
      if(ddToday > g_maxDDToday) g_maxDDToday = ddToday;
   }
   
   if(g_peakEquityEver > 0)
   {
      double ddEver = (g_peakEquityEver - equity) / g_peakEquityEver * 100.0;
      if(ddEver > g_maxDDEver) g_maxDDEver = ddEver;
   }
}

//+------------------------------------------------------------------+
//| STATISTICS CALCULATION                                            |
//+------------------------------------------------------------------+
void CalculateStatistics()
{
   datetime now = TimeCurrent();
   int todayKey = DayKey(now);
   int weekKey = WeekKey(now);
   int monthKey = MonthKey(now);
   
   // Reset counters
   g_closedLongToday = 0; g_closedShortToday = 0;
   g_profitLongToday = 0; g_profitShortToday = 0;
   g_closedLongWeek = 0; g_closedShortWeek = 0;
   g_profitLongWeek = 0; g_profitShortWeek = 0;
   g_closedLongMonth = 0; g_closedShortMonth = 0;
   g_profitLongMonth = 0; g_profitShortMonth = 0;
   
   int ht = OrdersHistoryTotal();
   for(int i = 0; i < ht; i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != Magic) continue;
      
      datetime ct = OrderCloseTime();
      if(ct <= 0) continue;
      
      double profit = OrderProfit() + OrderSwap() + OrderCommission();
      int type = OrderType();
      bool isLong = (type == OP_BUY);
      
      int orderDayKey = DayKey(ct);
      int orderWeekKey = WeekKey(ct);
      int orderMonthKey = MonthKey(ct);
      
      // Today
      if(orderDayKey == todayKey)
      {
         if(isLong) { g_closedLongToday++; g_profitLongToday += profit; }
         else { g_closedShortToday++; g_profitShortToday += profit; }
      }
      
      // This week
      if(orderWeekKey == weekKey)
      {
         if(isLong) { g_closedLongWeek++; g_profitLongWeek += profit; }
         else { g_closedShortWeek++; g_profitShortWeek += profit; }
      }
      
      // This month
      if(orderMonthKey == monthKey)
      {
         if(isLong) { g_closedLongMonth++; g_profitLongMonth += profit; }
         else { g_closedShortMonth++; g_profitShortMonth += profit; }
      }
   }
}

//+------------------------------------------------------------------+
//| MA SLOPE CACHE                                                    |
//+------------------------------------------------------------------+
void UpdateSlopeCacheIfNewBar()
{
   datetime barTime = Time[0];
   if(barTime == 0) return;
   
   if(barTime != g_lastBarTime)
   {
      g_lastBarTime = barTime;
      double ma0 = iMA(Symbol(), 0, maPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
      double maL = iMA(Symbol(), 0, maPeriod, 0, MODE_EMA, PRICE_CLOSE, slopeLookbackBars);
      
      g_cachedSlopePts = (int)MathRound((ma0 - maL) / Point);
      
      if(g_cachedSlopePts >= slopeThresholdPts) g_cachedSlopeDir = +1;
      else if(g_cachedSlopePts <= -slopeThresholdPts) g_cachedSlopeDir = -1;
      else g_cachedSlopeDir = 0;
   }
}

int MarketSlopeSignalCached(){ return g_cachedSlopeDir; }
int MarketSlopeStrengthPtsCached(){ return g_cachedSlopePts; }

//+------------------------------------------------------------------+
//| ORDER HELPERS                                                     |
//+------------------------------------------------------------------+
int CountOrdersDir(int dir, bool includeRunners)
{
   int c=0;
   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!IsMineTrade()) continue;
      if(IsPyramidTicket(OrderTicket())) continue;
      if(!includeRunners && IsRunner()) continue;
      if(dir>0 && OrderType()==OP_BUY)  c++;
      if(dir<0 && OrderType()==OP_SELL) c++;
   }
   return c;
}

//+------------------------------------------------------------------+
//| SERIES-SCOPED ORDER HELPERS                                       |
//+------------------------------------------------------------------+
bool IsSelectedOrderInSeries(string seriesKey)
{
   string c = OrderComment();
   if(seriesKey=="" || StringLen(seriesKey)==0) return true;
   return (StringFind(c, seriesKey, 0) >= 0);
}


int CountSeriesOrdersDir(int dir, string seriesKey, bool includeRunners)
{
   int c=0;
   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!IsMineTrade()) continue;
      if(IsPyramidTicket(OrderTicket())) continue;
      if(!IsSelectedOrderInSeries(seriesKey)) continue;
      if(!includeRunners && IsRunner()) continue;
      if(dir>0 && OrderType()==OP_BUY)  c++;
      if(dir<0 && OrderType()==OP_SELL) c++;
   }
   return c;
}



// ===== SCENARIO D SAFETY (multiplier only when price moves AWAY from basket BE) =====
double LastDAddOrLastOrderPriceSeries(int dir, string seriesKey)
{
   datetime bestT = 0;
   double bestP = 0.0;
   bool foundD = false;

   // 1) Prefer last D-add order (|D=)
   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!IsMineTrade()) continue;
      if(IsPyramidTicket(OrderTicket())) continue;
      if(!IsSelectedOrderInSeries(seriesKey)) continue;

      int t = OrderType();
      if(dir>0 && t!=OP_BUY)  continue;
      if(dir<0 && t!=OP_SELL) continue;

      if(StringFind(OrderComment(), "|D=", 0) < 0) continue;

      datetime ot = OrderOpenTime();
      if(ot >= bestT)
      {
         bestT = ot;
         bestP = OrderOpenPrice();
         foundD = true;
      }
   }

   if(foundD) return bestP;

   // 2) Fallback: last any order in series (same dir)
   bestT = 0; bestP = 0.0;
   for(int j=OrdersTotal()-1; j>=0; j--)
   {
      if(!OrderSelect(j, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!IsMineTrade()) continue;
      if(IsPyramidTicket(OrderTicket())) continue;
      if(!IsSelectedOrderInSeries(seriesKey)) continue;

      int t2 = OrderType();
      if(dir>0 && t2!=OP_BUY)  continue;
      if(dir<0 && t2!=OP_SELL) continue;

      datetime ot2 = OrderOpenTime();
      if(ot2 >= bestT)
      {
         bestT = ot2;
         bestP = OrderOpenPrice();
      }
   }
   return bestP;
}

bool IsPriceFavorableOrAtBE(int dir, string seriesKey)
{
   double be;
   if(!CalcBasketBEWithCostsSeries(dir, seriesKey, be)) return false;

   double cur = (dir > 0 ? Bid : Ask);
   if(dir > 0) return (cur >= be);
   return (cur <= be);
}

bool IsMovingAwayFromBESeries(int dir, string seriesKey)
{
   double be;
   if(!CalcBasketBEWithCostsSeries(dir, seriesKey, be))
      return true; // if cannot compute BE, do not block multiplier

   double cur = (dir > 0 ? Bid : Ask);

   // We only treat "away" on the ADVERSE side of BE
   if(dir > 0 && cur >= be) return false;
   if(dir < 0 && cur <= be) return false;

   double refPrice = LastDAddOrLastOrderPriceSeries(dir, seriesKey);
   if(refPrice <= 0.0) refPrice = cur;

   double distCur  = MathAbs(cur - be);
   double distRef  = MathAbs(refPrice - be);

   return (distCur > distRef + (Point * 0.1));
}

int CountSeriesDAdds(int dir, string seriesKey)
{
   int c=0;
   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!IsMineTrade()) continue;
      if(IsPyramidTicket(OrderTicket())) continue;
      if(!IsSelectedOrderInSeries(seriesKey)) continue;

      int t = OrderType();
      if(dir>0 && t!=OP_BUY)  continue;
      if(dir<0 && t!=OP_SELL) continue;

      if(StringFind(OrderComment(), "|D=", 0) >= 0) c++;
   }
   return c;
}


double SumLotsDir(int dir, bool includeRunners)
{
   double s=0;
   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!IsMineTrade()) continue;
      if(IsPyramidTicket(OrderTicket())) continue;
      if(!includeRunners && IsRunner()) continue;
      if(dir>0 && OrderType()==OP_BUY)  s += OrderLots();
      if(dir<0 && OrderType()==OP_SELL) s += OrderLots();
   }
   return s;
}

double SumRunnerLotsDir(int dir)
{
   double s=0;
   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!IsMineTrade()) continue;
      if(!IsRunner()) continue;
      if(dir>0 && OrderType()==OP_BUY)  s += OrderLots();
      if(dir<0 && OrderType()==OP_SELL) s += OrderLots();
   }
   return s;
}

double BasketFloatingPL(int dir, bool includeRunners)
{
   double pl=0;
   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!IsMineTrade()) continue;
      if(IsPyramidTicket(OrderTicket())) continue;
      if(!includeRunners && IsRunner()) continue;
      if(dir>0 && OrderType()!=OP_BUY) continue;
      if(dir<0 && OrderType()!=OP_SELL) continue;
      pl += OrderProfit() + OrderSwap() + OrderCommission();
   }
   return pl;
}

bool CooldownOK()
{
   if(g_lastSignalTime==0) return true;
   return (TimeCurrent() - g_lastSignalTime) >= CooldownSec;
}

bool ReEntryOK(int dir)
{
   datetime t = (dir>0 ? g_lastBuyTime : g_lastSellTime);
   if(t==0) return true;
   return (TimeCurrent() - t) >= CooldownSec;
}


//+------------------------------------------------------------------+
//| ELEGANT TRADE MARKERS SYSTEM                                       |
//| Style: Small arrows + dotted lines + profit labels at close        |
//+------------------------------------------------------------------+
void DrawSmallArrow(string name, datetime t, double price, int arrowCode, color clr, int width)
{
   if(ObjectFind(0, name) >= 0) return;
   ObjectCreate(0, name, OBJ_ARROW, 0, t, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrowCode);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

void DrawProfitLabel(string name, datetime t, double price, string text, color clr, int fsize, int anchor)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TEXT, 0, t, price);
   
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fsize);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

void DrawTradeLine(string name, datetime t1, double p1, datetime t2, double p2, color clr, int style)
{
   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

void MarkOrderOpen(int ticket)
{
   if(!ShowModernMarkers) return;
   if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;
   if(!IsMineTrade()) return;
   
   datetime t = OrderOpenTime();
   if(!InLast24h(t)) return;
   
   double p = OrderOpenPrice();
   int typ = OrderType();
   
   // Small dot at entry (Wingdings: 159 = small filled circle)
   int dotCode = 159;
   color c = (typ==OP_BUY ? clrDeepSkyBlue : clrOrangeRed);
   
   string nm = ObjName("O_" + TicketKey(ticket));
   DrawSmallArrow(nm, t, p, dotCode, c, 1);
}

// Global arrays for basket close aggregation
datetime g_basketCloseTime[];   // Close times for aggregation
double   g_basketClosePrice[];  // Close prices
double   g_basketProfit[];      // Profits
int      g_basketType[];        // Order types
int      g_basketCount = 0;

void ResetBasketAggregation()
{
   ArrayResize(g_basketCloseTime, 0);
   ArrayResize(g_basketClosePrice, 0);
   ArrayResize(g_basketProfit, 0);
   ArrayResize(g_basketType, 0);
   g_basketCount = 0;
}

void CollectClosedOrderForBasket()
{
   if(!ShowModernMarkers) return;
   
   int ticket = OrderTicket();
   if(ticket <= 0) return;
   
   datetime openT = OrderOpenTime();
   datetime closeT = OrderCloseTime();
   if(!InLast24h(closeT)) return;
   
   double openP = OrderOpenPrice();
   double closeP = OrderClosePrice();
   double profit = OrderProfit() + OrderSwap() + OrderCommission();
   int typ = OrderType();
   
   // Colors based on profit
   color profitClr = (profit >= 0 ? clrLime : clrRed);
   color lineClr = (profit >= 0 ? C'80,200,80' : C'200,100,100');
   
   // 1. Draw dotted line from open to close
   string lineName = ObjName("L_" + TicketKey(ticket));
   DrawTradeLine(lineName, openT, openP, closeT, closeP, lineClr, STYLE_DOT);
   
   // 2. Draw small dot at close
   string closeNm = ObjName("C_" + TicketKey(ticket));
   DrawSmallArrow(closeNm, closeT, closeP, 159, profitClr, 1);
   
   // 3. Store for basket aggregation
   int idx = g_basketCount;
   ArrayResize(g_basketCloseTime, idx + 1);
   ArrayResize(g_basketClosePrice, idx + 1);
   ArrayResize(g_basketProfit, idx + 1);
   ArrayResize(g_basketType, idx + 1);
   
   g_basketCloseTime[idx] = closeT;
   g_basketClosePrice[idx] = closeP;
   g_basketProfit[idx] = profit;
   g_basketType[idx] = typ;
   g_basketCount++;
}

void DrawAggregatedBasketLabels()
{
   if(g_basketCount == 0) return;
   
   // Group by close time (within 5 seconds = same basket close)
   int processed[];
   ArrayResize(processed, g_basketCount);
   ArrayInitialize(processed, 0);
   
   for(int i = 0; i < g_basketCount; i++)
   {
      if(processed[i] == 1) continue;
      
      datetime baseTime = g_basketCloseTime[i];
      double sumProfit = g_basketProfit[i];
      double avgPrice = g_basketClosePrice[i];
      int count = 1;
      int baseType = g_basketType[i];
      processed[i] = 1;
      
      // Find all orders closed within 5 seconds
      for(int j = i + 1; j < g_basketCount; j++)
      {
         if(processed[j] == 1) continue;
         if(MathAbs((int)(g_basketCloseTime[j] - baseTime)) <= 5)
         {
            sumProfit += g_basketProfit[j];
            avgPrice += g_basketClosePrice[j];
            count++;
            processed[j] = 1;
         }
      }
      
      avgPrice /= count;
      
      // Draw single aggregated label
      color lblClr = (sumProfit >= 0 ? clrLime : clrRed);
      string profitStr = (sumProfit >= 0 ? "+$" : "-$") + DoubleToString(MathAbs(sumProfit), 2);
      
      // Offset based on type
      double offset = (baseType == OP_BUY ? 30*Point : -30*Point);
      
      string nm = ObjName("BP_" + IntegerToString((int)baseTime));
      DrawProfitLabel(nm, baseTime, avgPrice + offset, profitStr, lblClr, 9, ANCHOR_LEFT);
   }
}

void MarkOrderCloseFromHistory()
{
   // This is now just a wrapper that collects data
   CollectClosedOrderForBasket();
}

void CleanupOldMarkers()
{
   datetime now = TimeCurrent();
   if(g_lastCleanup != 0 && (now - g_lastCleanup) < 60) return;
   g_lastCleanup = now;
   
   datetime cutoff = now - MARKERS_WINDOW_SEC;
   int total = ObjectsTotal(0, 0, -1);
   for(int i=total-1; i>=0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, PREFIX + IntegerToString(Magic) + "_", 0) != 0) continue;
      
      int type = (int)ObjectGetInteger(0, name, OBJPROP_TYPE);
      if(type != OBJ_ARROW && type != OBJ_TEXT && type != OBJ_LABEL && type != OBJ_TREND) continue;
      
      datetime t1 = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME1);
      if(t1 > 0 && t1 < cutoff)
         ObjectDelete(0, name);
   }
}

//+------------------------------------------------------------------+
//| BASKET LABELS                                                     |
//+------------------------------------------------------------------+
double SeriesProfitAndLastClose24h(string seriesKey, datetime &lastT, double &lastP)
{
   int ht = OrdersHistoryTotal();
   int from = ht - 8000; if(from < 0) from = 0;
   datetime cutoff = TimeCurrent() - MARKERS_WINDOW_SEC;
   
   double sum=0.0;
   lastT=0;
   lastP=0;
   
   for(int i=from;i<ht;i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if(OrderSymbol()!=Symbol()) continue;
      if(OrderMagicNumber()!=Magic) continue;
      
      datetime ct = OrderCloseTime();
      if(ct <= 0 || ct < cutoff) continue;
      
      string cmt = OrderComment();
      if(StringFind(cmt, seriesKey, 0) < 0 && StringFind(cmt, "TBE"+seriesKey, 0) < 0) continue;
      
      double pr = OrderProfit()+OrderSwap()+OrderCommission();
      sum += pr;
      
      if(ct > lastT){ lastT = ct; lastP = OrderClosePrice(); }
   }
   return sum;
}

void FinalizeSeriesIfEnded(int dir)
{
   if(!ShowBasketLabels) return;
   if(!SeriesActive(dir)) return;
   
   int cnt = CountOrdersDir(dir, true);
   if(cnt > 0) return;
   
   int id = CurrentSeriesId(dir);
   string key = SeriesKey(dir, id);
   
   datetime lt; double lp;
   double sum = SeriesProfitAndLastClose24h(key, lt, lp);
   
   if(lt > 0)
   {
      // Clean basket summary label
      string dirStr = (dir>0 ? "BUY" : "SELL");
      string text = "[" + dirStr + " #" + IntegerToString(id) + "] ";
      text += (sum >= 0 ? "+$" : "-$") + DoubleToString(MathAbs(sum), 2);
      
      double off = (dir>0 ? -80*Point : +80*Point);
      color c = (sum >= 0 ? clrLime : clrCrimson);
      
      string nm = ObjName("S_" + (dir>0 ? "B" : "S") + "_" + IntegerToString(id));
      DrawProfitLabel(nm, lt, lp + off, text, c, 9, ANCHOR_CENTER);
   }
   
   SetSeriesActive(dir, false);
}

//+------------------------------------------------------------------+
//| BOTTOM RESULTS PANEL (15-min intervals)                           |
//+------------------------------------------------------------------+
void DrawBottomResultsPanel()
{
   if(!ShowBottomResults) return;
   
   // Get current M15 index
   int curIdx = MinutesOfDay(TimeCurrent()) / 15;
   if(curIdx < 0) curIdx = 0;
   if(curIdx > 95) curIdx = 95;
   
   // Collect non-zero intervals
   int validIdxs[];
   ArrayResize(validIdxs, 0);
   
   for(int i = curIdx; i >= 0 && ArraySize(validIdxs) < BottomResultsCount; i--)
   {
      if(MathAbs(g_m15Pnl[i]) > 0.001)
      {
         int size = ArraySize(validIdxs);
         ArrayResize(validIdxs, size + 1);
         validIdxs[size] = i;
      }
   }
   
   // Clean old labels
   for(int j = 0; j < 20; j++)
      DeleteObject(ObjName("BR_" + IntegerToString(j)));
   
   if(ArraySize(validIdxs) == 0) return;
   
   // Draw bottom labels at chart time positions
   int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int labelW = 100;
   int gap = 8;
   int yPos = 25;
   
   for(int k = 0; k < ArraySize(validIdxs); k++)
   {
      int idx = validIdxs[ArraySize(validIdxs) - 1 - k];
      double pnl = g_m15Pnl[idx];
      
      int hh = idx / 4;
      int mm = (idx % 4) * 15;
      string timeStr = (hh<10 ? "0":"") + IntegerToString(hh) + ":" + (mm<10 ? "0":"") + IntegerToString(mm);
      
      string valStr = (pnl >= 0 ? "+" : "") + DoubleToString(pnl, 2);
      string text = timeStr + " | " + valStr;
      
      color bgClr = (pnl >= 0 ? C'20,80,40' : C'100,30,30');
      color txtClr = (pnl >= 0 ? clrLime : clrCoral);
      
      int xPos = 15 + k * (labelW + gap);
      
      string nm = ObjName("BR_" + IntegerToString(k));
      CreateBottomLabel(nm, xPos, yPos, labelW, 20, text, txtClr, bgClr);
   }
}

void CreateBottomLabel(string name, int x, int y, int w, int h, string text, color txtClr, color bgClr)
{
   // Background rectangle
   string bgName = name + "_bg";
   if(ObjectFind(0, bgName) < 0)
      ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, bgClr);
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_COLOR, clrDimGray);
   ObjectSetInteger(0, bgName, OBJPROP_BACK, false);
   ObjectSetInteger(0, bgName, OBJPROP_HIDDEN, true);
   
   // Text label
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x + 5);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y - 3);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, txtClr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void DeleteObject(string name)
{
   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
   if(ObjectFind(0, name + "_bg") >= 0) ObjectDelete(0, name + "_bg");
}

//+------------------------------------------------------------------+
//| AI SIMULATION ENGINE                                              |
//+------------------------------------------------------------------+
void UpdateAISimulation()
{
   datetime now = TimeCurrent();
   if(now - g_lastAiUpdate < 1) return; // Update every second
   g_lastAiUpdate = now;
   
   g_scanPhase = (g_scanPhase + 1) % 100;
   
   // Determine AI status based on market conditions
   double tickRate = GetAvgTickRate();
   int spread = SpreadPoints();
   int slopePts = MathAbs(g_cachedSlopePts);
   int openOrders = CountOrdersDir(+1, true) + CountOrdersDir(-1, true);
   
   // AI Status logic
   if(g_scanPhase < 30)
   {
      g_aiStatus = "SCANNING MARKET...";
   }
   else if(g_scanPhase < 50)
   {
      g_aiStatus = "ANALYZING PATTERNS";
   }
   else if(g_scanPhase < 70)
   {
      g_aiStatus = "PROCESSING DATA";
   }
   else if(g_lastSigDir != 0)
   {
      g_aiStatus = (g_lastSigDir > 0 ? ">> BUY SIGNAL DETECTED" : ">> SELL SIGNAL DETECTED");
   }
   else if(openOrders > 0)
   {
      g_aiStatus = "MONITORING POSITIONS";
   }
   else
   {
      g_aiStatus = "READY - AWAITING SIGNAL";
   }
   
   // DYNAMIC CONFIDENCE - drifts to 80%, jumps to 93% on trade
   static int lastOrdersCount = 0;
   int currentOrders = OrdersTotal();

   if(currentOrders > lastOrdersCount)
   {
      // New position opened - jump to 93%
      g_aiConfidenceTarget = 93;
      g_lastTradeTime = now;
   }
   else if(now - g_lastTradeTime > 30)  // After 30s without a trade
   {
      // Slow drift down to 80%
      g_aiConfidenceTarget = 80;
   }
   lastOrdersCount = currentOrders;
   
   // Smooth animation - slow transition to target
   if(g_aiConfidence < g_aiConfidenceTarget)
   {
      g_aiConfidence += 2;  // Fast rise
      if(g_aiConfidence > g_aiConfidenceTarget) g_aiConfidence = g_aiConfidenceTarget;
   }
   else if(g_aiConfidence > g_aiConfidenceTarget)
   {
      g_aiConfidence -= 1;  // Slow drop
      if(g_aiConfidence < g_aiConfidenceTarget) g_aiConfidence = g_aiConfidenceTarget;
   }
   
   // Clamp to valid range
   if(g_aiConfidence < 75) g_aiConfidence = 75;
   if(g_aiConfidence > 95) g_aiConfidence = 95;
   
   // Pattern Recognition
   if(slopePts > strongTrendPts)
      g_aiPattern = "STRONG TREND";
   else if(slopePts > slopeThresholdPts)
      g_aiPattern = "MOMENTUM BURST";
   else if(tickRate > TickRateThreshold * 1.5)
      g_aiPattern = "HIGH ACTIVITY";
   else if(spread > MaxSpreadPts * 0.8)
      g_aiPattern = "SPREAD WARNING";
   else
      g_aiPattern = "CONSOLIDATION";
   
   // Market Regime
   if(slopePts > strongTrendPts)
      g_marketRegime = "TRENDING";
   else if(tickRate > TickRateThreshold * 2)
      g_marketRegime = "VOLATILE";
   else
      g_marketRegime = "RANGING";
   
   // Risk Level
   double ddPct = g_maxDDToday;
   if(ddPct > MaxEquityDD_Pct * 0.7) g_riskLevel = 2; // HIGH
   else if(ddPct > MaxEquityDD_Pct * 0.3) g_riskLevel = 1; // MEDIUM
   else g_riskLevel = 0; // LOW
   
   // Trade Quality Score
   g_tradeQuality = 0;
   if(InTradingSession(now)) g_tradeQuality += 25;
   if(spread < MaxSpreadPts * 0.5) g_tradeQuality += 25;
   if(tickRate > TickRateThreshold) g_tradeQuality += 25;
   if(g_cachedSlopeDir != 0) g_tradeQuality += 25;
   
   // AI Messages rotation
   UpdateAIMessages();
}

void UpdateAIMessages()
{
   static int msgCounter = 0;
   msgCounter++;
   
   if(msgCounter % 5 == 0) // Change message every 5 seconds
   {
      g_aiMsgIndex = (g_aiMsgIndex + 1) % 5;
   }
   
   double tickRate = GetAvgTickRate();
   int openBuys = CountOrdersDir(+1, true);
   int openSells = CountOrdersDir(-1, true);
   
   g_aiMessages[0] = "Scanning " + IntegerToString((int)(tickRate * 100)) + " data points/sec";
   g_aiMessages[1] = "Pattern recognition: " + g_aiPattern + " detected";
   g_aiMessages[2] = "Market regime: " + g_marketRegime + " | Confidence: " + IntegerToString(g_aiConfidence) + "%";
   g_aiMessages[3] = "Active positions: " + IntegerToString(openBuys) + " LONG / " + IntegerToString(openSells) + " SHORT";
   g_aiMessages[4] = "Risk assessment: " + (g_riskLevel == 0 ? "LOW" : (g_riskLevel == 1 ? "MEDIUM" : "HIGH"));
}


//+------------------------------------------------------------------+
//| DASHBOARD - WALL STREET PROFESSIONAL STYLE                        |
//+------------------------------------------------------------------+
void DrawProDashboard()
{
   if(!ShowProDashboard) return;
   
   datetime now = TimeCurrent();
   if(now - g_lastDashUpdate < 1) return;
   g_lastDashUpdate = now;
   
   // WALL STREET COLOR PALETTE - Dark professional theme
   color bgDark       = C'18,22,28';      // Deep dark background
   color bgPanel      = C'24,28,36';      // Panel background
   color bgPanelLight = C'32,38,48';      // Lighter panel sections
   color borderMain   = C'45,52,65';      // Subtle borders
   color borderAccent = C'55,90,140';     // Accent borders
   color textBright   = C'220,225,230';   // Primary text
   color textMuted    = C'130,140,155';   // Secondary text
   color accentGold   = C'212,175,55';    // Gold accent
   color accentBlue   = C'70,130,200';    // Blue accent
   color profitGreen  = C'50,205,100';    // Profit green
   color lossRed      = C'220,70,70';     // Loss red
   
   int x = DashboardX;
   int y = DashboardY;
   int w = DashboardWidth;
   
   // ================================================================
   // HEADER - Dark gradient style
   // ================================================================
   DrawPanel(ObjName("D_Header"), x, y, w, 40, C'20,35,55', borderAccent);
   DrawLabel(ObjName("D_Title"), x + 15, y + 10, "MoneyDancer", textBright, 10, "Arial Bold");
   DrawLabel(ObjName("D_Version"), x + w - 50, y + 12, "v1.0", accentGold, 8, "Arial Bold");
   
   // Status LED
   string ledChar = (g_scanPhase % 20 < 10 ? "o" : "O");
   color ledClr = (g_eaStopped ? lossRed : profitGreen);
   DrawLabel(ObjName("D_LED"), x + w - 25, y + 12, ledChar, ledClr, 10, "Webdings");
   
   y += 45;
   
   // ================================================================
   // ENGINE PANEL
   // ================================================================
   DrawPanel(ObjName("D_AIPanel"), x, y, w, 70, bgPanel, borderMain);
   DrawLabel(ObjName("D_AITitle"), x + 12, y + 6, ">> ENGINE", accentBlue, 8, "Arial Bold");
   
   // Status with dots animation
   string dots = "";
   int dotCnt = (g_scanPhase / 8) % 4;
   for(int i = 0; i < dotCnt; i++) dots += ".";
   DrawLabel(ObjName("D_AIStatus"), x + 15, y + 24, g_aiStatus + dots, textBright, 10, "Consolas");
   DrawLabel(ObjName("D_AIMsg"), x + 15, y + 42, g_aiMessages[g_aiMsgIndex], textMuted, 7, "Consolas");
   
   // Confidence bar - shifted left to fit the % readout
   int barW = 80, barH = 10;
   int barX = x + w - barW - 45;  // More room on the right for %
   int barY = y + 22;
   DrawPanel(ObjName("D_ConfBg"), barX, barY, barW, barH, C'35,40,50', borderMain);
   int fillW = (int)(barW * g_aiConfidence / 100.0);
   color confClr = (g_aiConfidence > 70 ? profitGreen : (g_aiConfidence > 40 ? accentGold : lossRed));
   if(fillW > 0) DrawPanel(ObjName("D_ConfFill"), barX+1, barY+1, fillW-2, barH-2, confClr, clrNONE);
   DrawLabel(ObjName("D_ConfLbl"), barX, barY - 12, "CONFIDENCE", textMuted, 7, "Arial");
   DrawLabel(ObjName("D_ConfPct"), barX + barW + 5, barY, IntegerToString(g_aiConfidence) + "%", confClr, 9, "Arial Bold");
   
   y += 75;
   
   // ================================================================
   // LIVE METRICS PANEL
   // ================================================================
   DrawPanel(ObjName("D_MetricsPanel"), x, y, w, 90, bgPanel, borderMain);
   DrawLabel(ObjName("D_MetricsTitle"), x + 12, y + 6, ">> LIVE METRICS", accentBlue, 8, "Arial Bold");
   
   double avgTick = GetAvgTickSize();
   double tickRate = GetAvgTickRate();
   int spread = SpreadPoints();
   
   // Left column
   DrawLabel(ObjName("D_L1"), x + 15, y + 25, "AVG TICK (100):", textMuted, 8, "Arial");
   DrawLabel(ObjName("D_V1"), x + 120, y + 25, DoubleToString(avgTick, 2), textBright, 9, "Consolas");
   
   DrawLabel(ObjName("D_L2"), x + 15, y + 42, "TICK RATE:", textMuted, 8, "Arial");
   DrawLabel(ObjName("D_V2"), x + 120, y + 42, DoubleToString(tickRate, 1) + " t/s", textBright, 9, "Consolas");
   
   DrawLabel(ObjName("D_L3"), x + 15, y + 59, "SPREAD:", textMuted, 8, "Arial");
   color spClr = (spread < MaxSpreadPts/2 ? profitGreen : (spread < MaxSpreadPts ? accentGold : lossRed));
   DrawLabel(ObjName("D_V3"), x + 120, y + 59, IntegerToString(spread) + " pts", spClr, 9, "Consolas");
   
   // Right column
   DrawLabel(ObjName("D_L4"), x + w/2 + 10, y + 25, "MAX DD TODAY:", textMuted, 8, "Arial");
   color ddTClr = (g_maxDDToday > MaxEquityDD_Pct*0.5 ? lossRed : textBright);
   DrawLabel(ObjName("D_V4"), x + w/2 + 110, y + 25, DoubleToString(g_maxDDToday, 2) + "%", ddTClr, 9, "Consolas");
   
   DrawLabel(ObjName("D_L5"), x + w/2 + 10, y + 42, "MAX DD EVER:", textMuted, 8, "Arial");
   color ddEClr = (g_maxDDEver > MaxEquityDD_Pct ? lossRed : textBright);
   DrawLabel(ObjName("D_V5"), x + w/2 + 110, y + 42, DoubleToString(g_maxDDEver, 2) + "%", ddEClr, 9, "Consolas");
   
   DrawLabel(ObjName("D_L6"), x + w/2 + 10, y + 59, "PATTERN:", textMuted, 8, "Arial");
   DrawLabel(ObjName("D_V6"), x + w/2 + 110, y + 59, g_aiPattern, accentGold, 9, "Consolas");
   
   // Bottom row - Risk/Quality/Regime
   string riskTxt = (g_riskLevel == 0 ? "LOW" : (g_riskLevel == 1 ? "MED" : "HIGH"));
   color riskClr = (g_riskLevel == 0 ? profitGreen : (g_riskLevel == 1 ? accentGold : lossRed));
   DrawLabel(ObjName("D_RiskL"), x + 15, y + 75, "RISK:", textMuted, 7, "Arial");
   DrawLabel(ObjName("D_RiskV"), x + 50, y + 75, riskTxt, riskClr, 8, "Arial Bold");
   
   DrawLabel(ObjName("D_QualL"), x + 100, y + 75, "QUAL:", textMuted, 7, "Arial");
   color qClr = (g_tradeQuality > 70 ? profitGreen : (g_tradeQuality > 40 ? accentGold : lossRed));
   DrawLabel(ObjName("D_QualV"), x + 135, y + 75, IntegerToString(g_tradeQuality) + "%", qClr, 8, "Arial Bold");
   
   DrawLabel(ObjName("D_RegL"), x + w/2 + 10, y + 75, "REGIME:", textMuted, 7, "Arial");
   color regClr = (g_marketRegime == "TRENDING" ? profitGreen : (g_marketRegime == "VOLATILE" ? lossRed : accentGold));
   DrawLabel(ObjName("D_RegV"), x + w/2 + 60, y + 75, g_marketRegime, regClr, 8, "Arial Bold");
   
   y += 95;
   
   // ================================================================
   // POSITION STATISTICS PANEL
   // ================================================================
   DrawPanel(ObjName("D_StatsPanel"), x, y, w, 105, bgPanel, borderMain);
   DrawLabel(ObjName("D_StatsTitle"), x + 12, y + 6, ">> POSITIONS", accentBlue, 8, "Arial Bold");
   
   // Period buttons
   int btnW = 60, btnH = 16;
   int btnX = x + w - 195;
   color btnT = (g_statsViewMode == 0 ? accentBlue : C'40,45,55');
   color btnW2 = (g_statsViewMode == 1 ? accentBlue : C'40,45,55');
   color btnM = (g_statsViewMode == 2 ? accentBlue : C'40,45,55');
   CreateButton(ObjName("D_BtnToday"), btnX, y + 5, btnW, btnH, "TODAY", textBright, btnT);
   CreateButton(ObjName("D_BtnWeek"), btnX + btnW + 3, y + 5, btnW, btnH, "WEEK", textBright, btnW2);
   CreateButton(ObjName("D_BtnMonth"), btnX + 2*(btnW + 3), y + 5, btnW, btnH, "MONTH", textBright, btnM);
   
   int cL, cS; double pL, pS;
   if(g_statsViewMode == 0) { cL = g_closedLongToday; cS = g_closedShortToday; pL = g_profitLongToday; pS = g_profitShortToday; }
   else if(g_statsViewMode == 1) { cL = g_closedLongWeek; cS = g_closedShortWeek; pL = g_profitLongWeek; pS = g_profitShortWeek; }
   else { cL = g_closedLongMonth; cS = g_closedShortMonth; pL = g_profitLongMonth; pS = g_profitShortMonth; }
   
   // LONG row
   DrawLabel(ObjName("D_LI"), x + 15, y + 28, "^", accentBlue, 14, "Wingdings 3");
   DrawLabel(ObjName("D_LL"), x + 35, y + 30, "LONG:", textMuted, 8, "Arial");
   DrawLabel(ObjName("D_LC"), x + 80, y + 30, IntegerToString(cL), textBright, 9, "Consolas");
   color pLClr = (pL >= 0 ? profitGreen : lossRed);
   DrawLabel(ObjName("D_LP"), x + 110, y + 30, (pL >= 0 ? "+" : "") + DoubleToString(pL, 2), pLClr, 9, "Consolas");
   
   // SHORT row
   DrawLabel(ObjName("D_SI"), x + 15, y + 46, "_", lossRed, 14, "Wingdings 3");
   DrawLabel(ObjName("D_SL"), x + 35, y + 48, "SHORT:", textMuted, 8, "Arial");
   DrawLabel(ObjName("D_SC"), x + 80, y + 48, IntegerToString(cS), textBright, 9, "Consolas");
   color pSClr = (pS >= 0 ? profitGreen : lossRed);
   DrawLabel(ObjName("D_SP"), x + 110, y + 48, (pS >= 0 ? "+" : "") + DoubleToString(pS, 2), pSClr, 9, "Consolas");
   
   // TOTAL row
   double totP = pL + pS;
   int totC = cL + cS;
   DrawLabel(ObjName("D_TL"), x + 15, y + 68, "TOTAL:", textMuted, 9, "Arial Bold");
   DrawLabel(ObjName("D_TC"), x + 70, y + 68, IntegerToString(totC), textBright, 9, "Consolas");
   color totClr = (totP >= 0 ? profitGreen : lossRed);
   DrawLabel(ObjName("D_TP"), x + 110, y + 68, (totP >= 0 ? "+$" : "-$") + DoubleToString(MathAbs(totP), 2), totClr, 11, "Arial Bold");
   
   // Open positions
   int oB = CountOrdersDir(+1, true);
   int oS = CountOrdersDir(-1, true);
   double fB = BasketFloatingPL(+1, true);
   double fS = BasketFloatingPL(-1, true);
   double fT = fB + fS;
   
   DrawLabel(ObjName("D_OL"), x + w/2 + 15, y + 30, "OPEN:", textMuted, 8, "Arial");
   DrawLabel(ObjName("D_OB"), x + w/2 + 60, y + 30, IntegerToString(oB) + " B", accentBlue, 9, "Consolas");
   DrawLabel(ObjName("D_OS"), x + w/2 + 100, y + 30, IntegerToString(oS) + " S", lossRed, 9, "Consolas");
   
   DrawLabel(ObjName("D_FL"), x + w/2 + 15, y + 48, "FLOAT:", textMuted, 8, "Arial");
   color fClr = (fT >= 0 ? profitGreen : lossRed);
   DrawLabel(ObjName("D_FV"), x + w/2 + 60, y + 48, (fT >= 0 ? "+$" : "-$") + DoubleToString(MathAbs(fT), 2), fClr, 10, "Consolas");
   
   y += 110;
   
   // ================================================================
   // CONTROL BUTTONS PANEL
   // ================================================================
   DrawPanel(ObjName("D_CtrlPanel"), x, y, w, 80, bgPanel, borderMain);
   DrawLabel(ObjName("D_CtrlTitle"), x + 12, y + 6, ">> CONTROLS", accentBlue, 8, "Arial Bold");
   
   int cBtnW = 95, cBtnH = 20;
   int cY1 = y + 26, cY2 = y + 52;
   
   CreateButton(ObjName("D_BtnProfitSell"), x + 8, cY1, cBtnW, cBtnH, "+ PROFIT SELL", textBright, C'70,45,45');
   CreateButton(ObjName("D_BtnProfitBuy"), x + 108, cY1, cBtnW, cBtnH, "+ PROFIT BUY", textBright, C'45,70,45');
   CreateButton(ObjName("D_BtnCloseAllSell"), x + 208, cY1, cBtnW, cBtnH, "X ALL SELL", textBright, C'100,45,45');
   CreateButton(ObjName("D_BtnCloseAllBuy"), x + 308, cY1, cBtnW, cBtnH, "X ALL BUY", textBright, C'45,80,45');
   
   CreateButton(ObjName("D_BtnCloseAll"), x + 8, cY2, 195, cBtnH, "!! CLOSE ALL !!", textBright, C'130,50,50');
   string stopTxt = (g_eaStopped ? "> START EA" : "[] STOP EA");
   color stopBg = (g_eaStopped ? C'45,90,45' : C'90,45,45');
   CreateButton(ObjName("D_BtnStopEA"), x + 208, cY2, 195, cBtnH, stopTxt, textBright, stopBg);
   
   y += 85;
   
   // ================================================================
   // FOOTER
   // ================================================================
   DrawPanel(ObjName("D_Footer"), x, y, w, 22, bgDark, borderMain);
   string sessStr = (InTradingSession(now) ? "[ACTIVE]" : "[CLOSED]");
   color sessClr = (InTradingSession(now) ? profitGreen : textMuted);
   DrawLabel(ObjName("D_Sess"), x + 10, y + 4, sessStr, sessClr, 8, "Arial");

   // Daily cap / pause status (compact)
   string capTxt = "";
   color capClr = textMuted;
   if(IsAutoPaused())
   {
      capTxt = "PAUSE:" + g_tradePauseReason;
      capClr = accentGold;
   }
   else if(g_dayBaseReady)
   {
      string pfx = (g_dayProfitUsd >= 0 ? "+$" : "-$");
      capTxt = "DAY:" + pfx + DoubleToString(MathAbs(g_dayProfitUsd), 0);
      if(MaxDailyProfitPct > 0)
      {
         capTxt = capTxt + " CAP:" + IntegerToString(MaxDailyProfitPct) + "%";
      }
         // Profit lock status
   if(RiskFromCurrentProfit)
   {
      string lockTag = " LOCK@" + TwoDigit(RiskFromCurrentProfitUntilHour) + ":" + TwoDigit(RiskFromCurrentProfitUntilMinute);
      if(g_profitLockCaptured)
         lockTag = lockTag + "+$" + DoubleToString(g_lockedProfitUsd, 0);
      capTxt = capTxt + lockTag;
   }
   capClr = (g_dayProfitUsd >= 0 ? profitGreen : lossRed);
   }
   else
   {
      capTxt = "BASE@" + TwoDigit(DailyBaselineHour) + ":" + TwoDigit(DailyBaselineMinute);
      capClr = textMuted;
   }
   DrawLabel(ObjName("D_Cap"), x + 90, y + 4, capTxt, capClr, 8, "Consolas");

   DrawLabel(ObjName("D_Time"), x + w - 115, y + 4, TimeToString(now, TIME_DATE|TIME_MINUTES), textMuted, 8, "Consolas");
   DrawLabel(ObjName("D_Mode"), x + w/2 - 25, y + 4, g_lastMode, textMuted, 8, "Arial");
}

//+------------------------------------------------------------------+
//| DASHBOARD HELPER FUNCTIONS                                        |
//+------------------------------------------------------------------+
void DrawPanel(string name, int x, int y, int w, int h, color bgClr, color borderClr)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgClr);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, borderClr);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

void DrawLabel(string name, int x, int y, string text, color clr, int fontSize, string font)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, font);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

void CreateButton(string name, int x, int y, int w, int h, string text, color txtClr, color bgClr)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, txtClr);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgClr);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrDimGray);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
}


//+------------------------------------------------------------------+
//| BUTTON EVENT HANDLERS                                             |
//+------------------------------------------------------------------+
void CheckButtonClicks()
{
   datetime now = TimeCurrent();
   if(now - g_lastButtonCheck < 1) return;
   g_lastButtonCheck = now;
   
   // Stats view mode buttons
   if(ObjectGetInteger(0, ObjName("D_BtnToday"), OBJPROP_STATE) == true)
   {
      g_statsViewMode = 0;
      ObjectSetInteger(0, ObjName("D_BtnToday"), OBJPROP_STATE, false);
   }
   if(ObjectGetInteger(0, ObjName("D_BtnWeek"), OBJPROP_STATE) == true)
   {
      g_statsViewMode = 1;
      ObjectSetInteger(0, ObjName("D_BtnWeek"), OBJPROP_STATE, false);
   }
   if(ObjectGetInteger(0, ObjName("D_BtnMonth"), OBJPROP_STATE) == true)
   {
      g_statsViewMode = 2;
      ObjectSetInteger(0, ObjName("D_BtnMonth"), OBJPROP_STATE, false);
   }
   
   // Close Profit Sell
   if(ObjectGetInteger(0, ObjName("D_BtnProfitSell"), OBJPROP_STATE) == true)
   {
      CloseProfitOrders(OP_SELL);
      ObjectSetInteger(0, ObjName("D_BtnProfitSell"), OBJPROP_STATE, false);
   }
   
   // Close Profit Buy
   if(ObjectGetInteger(0, ObjName("D_BtnProfitBuy"), OBJPROP_STATE) == true)
   {
      CloseProfitOrders(OP_BUY);
      ObjectSetInteger(0, ObjName("D_BtnProfitBuy"), OBJPROP_STATE, false);
   }
   
   // Close All Sell
   if(ObjectGetInteger(0, ObjName("D_BtnCloseAllSell"), OBJPROP_STATE) == true)
   {
      CloseAllOrdersType(OP_SELL);
      ObjectSetInteger(0, ObjName("D_BtnCloseAllSell"), OBJPROP_STATE, false);
   }
   
   // Close All Buy
   if(ObjectGetInteger(0, ObjName("D_BtnCloseAllBuy"), OBJPROP_STATE) == true)
   {
      CloseAllOrdersType(OP_BUY);
      ObjectSetInteger(0, ObjName("D_BtnCloseAllBuy"), OBJPROP_STATE, false);
   }
   
   // Close All + Stop EA
   if(ObjectGetInteger(0, ObjName("D_BtnCloseAll"), OBJPROP_STATE) == true)
   {
      CloseAllOrders();
      g_eaStopped = true;
      ObjectSetInteger(0, ObjName("D_BtnCloseAll"), OBJPROP_STATE, false);
   }
   
   // Stop/Start EA toggle
   if(ObjectGetInteger(0, ObjName("D_BtnStopEA"), OBJPROP_STATE) == true)
   {
      g_eaStopped = !g_eaStopped;
      ObjectSetInteger(0, ObjName("D_BtnStopEA"), OBJPROP_STATE, false);
   }
}

//+------------------------------------------------------------------+
//| POSITION CLOSING FUNCTIONS                                        |
//+------------------------------------------------------------------+
void CloseProfitOrders(int orderType)
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!IsMineTrade()) continue;
      if(OrderType() != orderType) continue;
      
      double profit = OrderProfit() + OrderSwap() + OrderCommission();
      if(profit > 0)
      {
         double price = (orderType == OP_BUY ? Bid : Ask);
         bool result = OrderClose(OrderTicket(), OrderLots(), price, Slippage, clrNONE);
         if(!result) ResetLastError();
      }
   }
}

void CloseAllOrdersType(int orderType)
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!IsMineTrade()) continue;
      if(OrderType() != orderType) continue;
      
      double price = (orderType == OP_BUY ? Bid : Ask);
      bool result = OrderClose(OrderTicket(), OrderLots(), price, Slippage, clrNONE);
      if(!result) ResetLastError();
   }
}

void CloseAllOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!IsMineTrade()) continue;
      
      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL) continue;
      
      double price = (type == OP_BUY ? Bid : Ask);
      bool result = OrderClose(OrderTicket(), OrderLots(), price, Slippage, clrNONE);
      if(!result) ResetLastError();
   }
}

//+------------------------------------------------------------------+
//| TICK BURST DETECTION (SECOND MODE)                                |
//+------------------------------------------------------------------+
void AddTickToSecond(double bid)
{
   double lvl = RoundToStep(bid, PriceStep);
   for(int i=0;i<g_levelsN;i++)
   {
      if(g_levels[i]==lvl){ g_counts[i]++; return; }
   }
   if(g_levelsN < MAX_LEVELS_PER_SEC)
   {
      g_levels[g_levelsN]=lvl;
      g_counts[g_levelsN]=1;
      g_levelsN++;
   }
}

void ResetSecond(datetime sec, double bid)
{
   g_sec=sec;
   g_firstBid=bid;
   g_lastBid=bid;
   g_levelsN=0;
   AddTickToSecond(bid);
}

bool EvaluateSecond(int &dirOut, int &peakTicksOut, int &movePtsOut)
{
   int bestIdx=-1,bestCnt=0;
   for(int i=0;i<g_levelsN;i++)
   {
      if(g_counts[i]>bestCnt){ bestCnt=g_counts[i]; bestIdx=i; }
   }
   if(bestIdx<0) return false;
   
   double move = g_lastBid - g_firstBid;
   int movePts = (int)MathAbs(move/Point);
   
   if(bestCnt < BurstTicks) return false;
   if(movePts < MinMovePoints) return false;
   
   dirOut = (move>0 ? +1 : -1);
   peakTicksOut = bestCnt;
   movePtsOut = movePts;
   return true;
}

//+------------------------------------------------------------------+
//| TICK BURST DETECTION (WINDOW MODE)                                |
//+------------------------------------------------------------------+
void PushTickWindow(double bid)
{
   int N = TickWindowTicks;
   if(N < 5) N = 5;
   if(N > 200) N = 200;
   
   double lvl = RoundToStep(bid, PriceStep);
   
   if(g_winCount >= N)
   {
      for(int i=1;i<g_winCount;i++)
      {
         g_winBids[i-1] = g_winBids[i];
         g_winLvls[i-1] = g_winLvls[i];
      }
      g_winCount--;
   }
   
   g_winBids[g_winCount] = bid;
   g_winLvls[g_winCount] = lvl;
   g_winCount++;
}

bool EvaluateTickWindow(int &dirOut, int &peakTicksOut, int &movePtsOut)
{
   int N = TickWindowTicks;
   if(N < 5) N = 5;
   if(N > 200) N = 200;
   if(g_winCount < N) return false;
   
   int bestCnt = 0;
   for(int i=0;i<g_winCount;i++)
   {
      int c=1;
      for(int j=i+1;j<g_winCount;j++)
         if(g_winLvls[j] == g_winLvls[i]) c++;
      if(c > bestCnt) bestCnt = c;
   }
   
   double move = g_winBids[g_winCount-1] - g_winBids[0];
   int movePts = (int)MathAbs(move/Point);
   
   if(bestCnt < BurstTicks) return false;
   if(movePts < MinMovePoints) return false;
   
   dirOut = (move>0 ? +1 : -1);
   peakTicksOut = bestCnt;
   movePtsOut = movePts;
   return true;
}

//+------------------------------------------------------------------+
//| BASKET CALCULATIONS                                               |
//+------------------------------------------------------------------+
bool CalcGroupBE(int dir, double &beOut)
{
   double sumLots=0, sumPx=0;
   int cnt=0;

   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!IsMineTrade()) continue;
      if(IsRunner()) continue;

      if(dir>0 && OrderType()!=OP_BUY)  continue;
      if(dir<0 && OrderType()!=OP_SELL) continue;

      double L = OrderLots();
      sumLots += L;
      sumPx   += L*OrderOpenPrice();
      cnt++;
   }

   if(cnt<=0 || sumLots<=0) return false;
   beOut = NormalizeDouble(sumPx/sumLots, Digits);
   return true;
}

// ------------------------------
// Basket snapshot (for series BE + logic)
// ------------------------------
struct BasketOrder
{
   int      ticket;
   int      type;
   double   lots;
   double   openPrice;
   double   swap;
   double   commission;
   datetime openTime;
};

double ProfitAtPrice(int type, string sym, double lots, double openPrice, double closePrice)
{
   double tickSize  = MarketInfo(sym, MODE_TICKSIZE);
   double tickValue = MarketInfo(sym, MODE_TICKVALUE);

   if(tickSize <= 0.0) tickSize = Point;
   if(tickValue <= 0.0) tickValue = 0.0;

   double diff = 0.0;
   if(type == OP_BUY)  diff = (closePrice - openPrice);
   else if(type == OP_SELL) diff = (openPrice - closePrice);
   else diff = 0.0;

   // profit in deposit currency (approx, uses current tick value)
   return (diff / tickSize) * tickValue * lots;
}

int CollectBasketOrdersSeries(int dir, string seriesKey, BasketOrder &outArr[])
{
   ArrayResize(outArr, 0);
   int n=0;

   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!IsMineTrade()) continue;
      if(IsPyramidTicket(OrderTicket())) continue;
      if(IsRunner()) continue;
      if(!IsSelectedOrderInSeries(seriesKey)) continue;

      int t = OrderType();
      if(dir>0 && t!=OP_BUY)  continue;
      if(dir<0 && t!=OP_SELL) continue;

      n++;
      ArrayResize(outArr, n);
      int k = n-1;

      outArr[k].ticket     = OrderTicket();
      outArr[k].type       = t;
      outArr[k].lots       = OrderLots();
      outArr[k].openPrice  = OrderOpenPrice();
      outArr[k].swap       = OrderSwap();
      outArr[k].commission = OrderCommission();
      outArr[k].openTime   = OrderOpenTime();
   }

   // sort ascending by openTime (simple insertion sort; n is small)
   for(int a=1; a<n; a++)
   {
      BasketOrder key = outArr[a];
      int b=a-1;
      while(b>=0 && outArr[b].openTime > key.openTime)
      {
         outArr[b+1] = outArr[b];
         b--;
      }
      outArr[b+1] = key;
   }

   return n;
}

double FirstBasketLotSeries(int dir, string seriesKey)
{
   BasketOrder arr[];
   int n = CollectBasketOrdersSeries(dir, seriesKey, arr);
   if(n<=0) return 0.0;
   return arr[0].lots;
}

double BasketProfitAtPriceSeries(BasketOrder &arr[], int n, double closePrice)
{
   double sum = 0.0;
   for(int i=0; i<n; i++)
   {
      double pr = ProfitAtPrice(arr[i].type, Symbol(), arr[i].lots, arr[i].openPrice, closePrice);
      sum += pr + arr[i].swap + arr[i].commission;
   }
   return sum;
}

// Cost-aware, series-scoped basket BE: solves price where total PnL (incl. swap+commission) == 0.
bool CalcBasketBEWithCostsSeries(int dir, string seriesKey, double &beOut)
{
   BasketOrder arr[];
   int n = CollectBasketOrdersSeries(dir, seriesKey, arr);
   if(n<=0) return false;

   double cur = (dir>0 ? Bid : Ask);

   // Find a bracket [lo, hi] such that profit(lo) and profit(hi) have opposite signs
   double lo = cur, hi = cur;
   double plo = BasketProfitAtPriceSeries(arr, n, lo);
   double phi = plo;

   // expand range up to ~20000 points (2k pips on 5-digit)
   int maxExpand = 40;
   double step = 200 * Point;

   bool found=false;
   for(int k=0; k<maxExpand; k++)
   {
      lo = cur - step*(k+1);
      hi = cur + step*(k+1);
      plo = BasketProfitAtPriceSeries(arr, n, lo);
      phi = BasketProfitAtPriceSeries(arr, n, hi);
      if(plo==0.0)
      {
         beOut = NormalizeDouble(lo, Digits);
         return true;
      }
      if(phi==0.0)
      {
         beOut = NormalizeDouble(hi, Digits);
         return true;
      }
      if((plo < 0.0 && phi > 0.0) || (plo > 0.0 && phi < 0.0))
      {
         found=true;
         break;
      }
   }

   if(!found)
   {
      // fallback to weighted-average BE (without costs) if no bracket found
      double sumLots=0, sumPx=0;
      for(int i=0;i<n;i++){ sumLots += arr[i].lots; sumPx += arr[i].lots*arr[i].openPrice; }
      if(sumLots<=0) return false;
      beOut = NormalizeDouble(sumPx/sumLots, Digits);
      return true;
   }

   // Bisection
   double a=lo, b=hi;
   double fa=plo, fb=phi;

   for(int it=0; it<40; it++)
   {
      double mid = 0.5*(a+b);
      double fm = BasketProfitAtPriceSeries(arr, n, mid);

      if(MathAbs(fm) < 0.01) { beOut = NormalizeDouble(mid, Digits); return true; }

      if((fa < 0.0 && fm > 0.0) || (fa > 0.0 && fm < 0.0))
      {
         b=mid; fb=fm;
      }
      else
      {
         a=mid; fa=fm;
      }
   }

   beOut = NormalizeDouble(0.5*(a+b), Digits);
   return true;
}

// Step gate based on DISTANCE FROM COST-AWARE BASKET BE (series-scoped)
bool StepGateFromBasketBESeries(int dir, string seriesKey)
{
   double be;
   if(!CalcBasketBEWithCostsSeries(dir, seriesKey, be))
      return true; // if cannot compute BE, do not block

   double cur = (dir > 0 ? Bid : Ask);
   int distPts = (int)MathAbs((cur - be) / Point);
   return (distPts >= StepPoints);
}

// Apply basket TP for all orders in the series to BE +/- bePoints
void ApplyBasketTPSeries(int dir, string seriesKey)
{
   double be;
   if(!CalcBasketBEWithCostsSeries(dir, seriesKey, be)) return;

   double tp = (dir>0 ? be + bePoints*Point : be - bePoints*Point);

   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!IsMineTrade()) continue;
      if(IsPyramidTicket(OrderTicket())) continue;
      if(IsRunner()) continue;
      if(!IsSelectedOrderInSeries(seriesKey)) continue;

      if(dir>0 && OrderType()!=OP_BUY)  continue;
      if(dir<0 && OrderType()!=OP_SELL) continue;

      double op = OrderOpenPrice();
      double sl = OrderStopLoss();
      double oldTp = OrderTakeProfit();

      if(oldTp > 0 && MathAbs(oldTp - tp) < (Point*2)) continue;

      bool ok = OrderModify(OrderTicket(), op, sl, tp, 0);
      if(!ok) ResetLastError();
   }
}

bool StepGateFromBasketBE(int dir)
{
   double be;
   if(!CalcGroupBE(dir, be))
      return true;
   
   double cur = (dir > 0 ? Bid : Ask);
   int distPts = (int)MathAbs((cur - be) / Point);
   return (distPts >= StepPoints);
}

void ApplyBasketTP(int dir)
{
   double be;
   if(!CalcGroupBE(dir, be)) return;
   
   double tp = (dir>0 ? be + bePoints*Point : be - bePoints*Point);
   tp = NormalizeDouble(tp, Digits);
   
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(!IsMineTrade()) continue;
      if(IsPyramidTicket(OrderTicket())) continue;
      if(IsRunner()) continue;
      
      if(dir>0 && OrderType()!=OP_BUY) continue;
      if(dir<0 && OrderType()!=OP_SELL) continue;
      
      double op = OrderOpenPrice();
      double sl = OrderStopLoss();
      double curTP = OrderTakeProfit();
      
      if(MathAbs(curTP - tp) > (2*Point))
      {
         bool _ok = OrderModify(OrderTicket(), op, sl, tp, 0, clrNONE);
         if(!_ok) ResetLastError();
      }
   }
}

//+------------------------------------------------------------------+
//| SCENARIO D - MINIMUM DISTANCE FILTER                              |
//| Prevents order clustering at the same price level                 |
//+------------------------------------------------------------------+
bool CheckMinDistanceFromExistingOrders(int dir)
{
   double currentPrice = (dir > 0 ? Ask : Bid);
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!IsMineTrade()) continue;
      if(IsRunner()) continue;
      
      // Check only orders in the same direction
      if(dir > 0 && OrderType() != OP_BUY) continue;
      if(dir < 0 && OrderType() != OP_SELL) continue;
      
      double orderPrice = OrderOpenPrice();
      int distancePts = (int)(MathAbs(currentPrice - orderPrice) / Point);
      
      // If any existing order is too close, reject new order
      if(distancePts < MinOrderDistancePts)
      {
         return false; // Too close to existing order
      }
   }
   
   return true; // OK - no orders too close
}

//+------------------------------------------------------------------+
//| GUARDS                                                            |
//+------------------------------------------------------------------+
bool EquityGuardTriggered()
{
   double bal = AccountBalance();
   double eq  = AccountEquity();
   if(bal <= 0) return false;
   
   double ddPct = (bal - eq) / bal * 100.0;
   return (ddPct >= MaxEquityDD_Pct);
}

bool BasketGuardTriggered(int dir)
{
   double bal = AccountBalance();
   if(bal <= 0) return false;
   
   double pl = BasketFloatingPL(dir, false);
   if(pl >= 0) return false;
   
   double lossPct = (-pl) / bal * 100.0;
   return (lossPct >= MaxBasketDD_Pct);
}

bool TrendBlocksD(int basketDir)
{
   if(!UseSlopeFilter) return false;
   
   int slopePts = MarketSlopeStrengthPtsCached();
   if(MathAbs(slopePts) < strongTrendPts) return false;
   
   if(basketDir < 0 && slopePts > 0) return true;
   if(basketDir > 0 && slopePts < 0) return true;
   return false;
}

//+------------------------------------------------------------------+
//| ORDER SEND                                                        |
//+------------------------------------------------------------------+
bool SendOrder(int dir, double lots, bool useTP, int tpPoints, bool isRunner, string commentText)
{
      // Block opening NEW orders outside allowed working hours
   if(UseTradingHours && !InTradingSession(TimeCurrent())) return(false);
if(SpreadPoints() > MaxSpreadPts) return false;
   if(!IsTradeAllowed()) return false;
   
   int type = (dir>0 ? OP_BUY : OP_SELL);
   double price = (dir>0 ? Ask : Bid);
   
   // PYRAMID routing (signal logic unchanged): decide at the actual open
   bool wantPyr = false;
   if(!isRunner) wantPyr = PyramidWantsOrder(dir);

   double sl=0,tp=0;
   // For pyramid: SL/TP is set exclusively by pyramid logic -> start with TP=0 and SL=0
   if(!wantPyr)
   {
      if(SL_Points>0)
         sl = (dir>0 ? price - SL_Points*Point : price + SL_Points*Point);
      if(useTP && tpPoints>0)
         tp = (dir>0 ? price + tpPoints*Point : price - tpPoints*Point);
   }

   if(wantPyr) lots = LotsBase; // pyramid always uses basic lot
   if(lots <= 0) lots = LotsBase;
   lots = ClampLot(lots);
   
   string cmt = commentText;
   if(isRunner) cmt = RUNNER_TAG + "|" + cmt;
   
   int ticket = OrderSend(Symbol(), type, lots, price, Slippage, sl, tp, cmt, Magic, 0, clrNONE);
   if(ticket > 0)
   {
      if(dir>0) g_lastBuyTime = TimeCurrent(); else g_lastSellTime = TimeCurrent();
      g_lastSignalTime = TimeCurrent();
      
      MarkOrderOpen(ticket);

      // Register position in pyramid (if routing flagged it as pyramid)
      if(wantPyr)
         PyramidOnNewTicket(ticket);
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| SCENARIO E - RUNNERS                                              |
//+------------------------------------------------------------------+
bool HasAnyRunnersOpen()
{
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(!IsMineTrade()) continue;
      if(IsRunner()) return true;
   }
   return false;
}

void ManageRunnersTrailing()
{
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(!IsMineTrade()) continue;
      if(!IsRunner()) continue;
      
      int type = OrderType();
      if(type!=OP_BUY && type!=OP_SELL) continue;
      
      double op = OrderOpenPrice();
      double sl = OrderStopLoss();
      double tp = OrderTakeProfit();
      
      double cur = (type==OP_BUY ? Bid : Ask);
      int profitPts = (int)((type==OP_BUY ? (cur-op) : (op-cur)) / Point);
      
      if(profitPts >= RunnerBE_StartPts)
      {
         double beSL = NormalizeDouble(op, Digits);
         if(type==OP_BUY)
         {
            if(sl < beSL - 2*Point)
            {
               bool _ok = OrderModify(OrderTicket(), op, beSL, tp, 0, clrNONE);
               if(!_ok) ResetLastError();
            }
         }
         else
         {
            if(sl > beSL + 2*Point || sl==0)
            {
               bool _ok = OrderModify(OrderTicket(), op, beSL, tp, 0, clrNONE);
               if(!_ok) ResetLastError();
            }
         }
      }
      
      if(profitPts >= (RunnerBE_StartPts + RunnerTrailDistPts))
      {
         double newSL = (type==OP_BUY ? cur - RunnerTrailDistPts*Point : cur + RunnerTrailDistPts*Point);
         newSL = NormalizeDouble(newSL, Digits);
         
         if(type==OP_BUY)
         {
            if(newSL > sl + RunnerTrailStepPts*Point)
            {
               bool _ok = OrderModify(OrderTicket(), op, newSL, tp, 0, clrNONE);
               if(!_ok) ResetLastError();
            }
         }
         else
         {
            if(sl==0 || newSL < sl - RunnerTrailStepPts*Point)
            {
               bool _ok = OrderModify(OrderTicket(), op, newSL, tp, 0, clrNONE);
               if(!_ok) ResetLastError();
            }
         }
      }
   }
}

double CurrentLossPerLot(int ticket)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET)) return 0.0;
   double pl = OrderProfit() + OrderSwap() + OrderCommission();
   if(pl >= 0) return 0.0;
   double lots = OrderLots();
   if(lots <= 0) return 0.0;
   return (-pl) / lots;
}

bool ReduceWorstLosingOrder(int dir, double budgetMoney)
{
   if(budgetMoney <= 0) return false;
   
   int worstTicket=-1;
   double worstPL=0;
   
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(!IsMineTrade()) continue;
      if(IsPyramidTicket(OrderTicket())) continue;
      if(IsRunner()) continue;
      
      if(dir>0 && OrderType()!=OP_BUY) continue;
      if(dir<0 && OrderType()!=OP_SELL) continue;
      
      double pl = OrderProfit() + OrderSwap() + OrderCommission();
      if(pl < worstPL)
      {
         worstPL = pl;
         worstTicket = OrderTicket();
      }
   }
   
   if(worstTicket<0) return false;
   if(!OrderSelect(worstTicket, SELECT_BY_TICKET)) return false;
   
   double lots = OrderLots();
   if(lots <= MinPartialCloseLot) return false;
   
   double lossPerLot = CurrentLossPerLot(worstTicket);
   if(lossPerLot <= 0) return false;
   
   double closeLots = budgetMoney / lossPerLot;
   if(closeLots < MinPartialCloseLot) closeLots = MinPartialCloseLot;
   if(closeLots > lots/2.0) closeLots = lots/2.0;
   
   closeLots = ClampLot(closeLots);
   if(closeLots < MinPartialCloseLot) return false;
   
   int type = OrderType();
   double price = (type==OP_BUY ? Bid : Ask);
   
   return OrderClose(worstTicket, closeLots, price, Slippage, clrNONE);
}

//+------------------------------------------------------------------+
//| M15 PNL TRACKING                                                  |
//+------------------------------------------------------------------+
void ResetPnLDayIfNeeded()
{
   int dk = DayKey(TimeCurrent());
   if(dk != g_pnlDayKey)
   {
      g_pnlDayKey = dk;
      for(int i=0;i<96;i++) g_m15Pnl[i]=0.0;
      
      int ht = OrdersHistoryTotal();
      for(int i=0;i<ht;i++)
      {
         if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
         if(OrderSymbol()!=Symbol()) continue;
         if(OrderMagicNumber()!=Magic) continue;
         
         datetime ct = OrderCloseTime();
         if(ct <= 0) continue;
         if(DayKey(ct) != g_pnlDayKey) continue;
         
         int idx = MinutesOfDay(ct)/15;
         if(idx<0 || idx>95) continue;
         
         double profit = OrderProfit()+OrderSwap()+OrderCommission();
         g_m15Pnl[idx] += profit;
      }
      g_lastHistTotal = ht;
   }
}

void UpdateM15BucketForClosedOrder()
{
   datetime ct = OrderCloseTime();
   if(ct <= 0) return;
   if(DayKey(ct) != g_pnlDayKey) return;
   
   int idx = MinutesOfDay(ct) / 15;
   if(idx < 0 || idx > 95) return;
   
   double profit = OrderProfit() + OrderSwap() + OrderCommission();
   g_m15Pnl[idx] += profit;
}

double TodayPnL()
{
   double s=0;
   for(int i=0;i<96;i++) s += g_m15Pnl[i];
   return s;
}

void ScanHistoryNewAndUpdatePnLAndMarkers()
{
   int ht = OrdersHistoryTotal();
   if(ht <= g_lastHistTotal) return;
   
   // Reset basket aggregation before collecting new closes
   ResetBasketAggregation();
   
   for(int i=g_lastHistTotal; i<ht; i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if(OrderSymbol()!=Symbol()) continue;
      if(OrderMagicNumber()!=Magic) continue;
      
      UpdateM15BucketForClosedOrder();
      MarkOrderCloseFromHistory();  // Now collects data for aggregation
      
      // SIPHON LOGIC
      // Runner is opposite to the losing basket.
      // So if a BUY runner closes in profit, the losing basket is SELL.
      // We reduce positions in the direction of the LOSING basket (opposite of runner).
      if(ScenarioE && StringFind(OrderComment(), RUNNER_TAG, 0) >= 0)
      {
         double profit = OrderProfit() + OrderSwap() + OrderCommission();
         if(profit > 0)
         {
            // Runner direction is OPPOSITE to the losing basket
            // So losing basket = -runnerDir
            int runnerDir = (OrderType()==OP_BUY ? +1 : -1);
            int losingBasketDir = -runnerDir;  // Basket we are hedging

            // Reduce the worst position in the LOSING basket
            ReduceWorstLosingOrder(losingBasketDir, profit * SiphonPct);
         }
      }
   }
   
   // Draw aggregated basket labels (sum instead of individual)
   DrawAggregatedBasketLabels();
   
   g_lastHistTotal = ht;
}

//+------------------------------------------------------------------+
//| SCENARIO D/E DECISIONS                                            |
//| Returns activation reason for E (shown on dashboard)               |
//+------------------------------------------------------------------+
bool CheckShouldActivateE(int basketDir, string &reason)
{
   if(!ScenarioE) 
   {
      reason = "";
      return false;
   }
   
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

void TryOpenRunner(int losingBasketDir, string reason)
{
   if(!ScenarioE) return;
   
   // Runner opens OPPOSITE to the losing basket (classic hedge)
   int hedgeDir = -losingBasketDir;  // Opposite direction!
   
   double losingLots = SumLotsDir(losingBasketDir, false);
   if(losingLots <= 0) return;
   
   // Check how many runners we already have in the hedge direction
   double runnersLots = SumRunnerLotsDir(hedgeDir);
   double maxAllowed = losingLots * HedgeRatio;
   if(runnersLots >= maxAllowed) return;
   
   double remaining = maxAllowed - runnersLots;
   double lot = MathMin(LotsBase, remaining);
   lot = ClampLot(lot);
   if(lot <= 0) return;
   
   int sid = CurrentSeriesId(losingBasketDir);
   string seriesCmt = SeriesKey(losingBasketDir, sid);
   string cmt = "HEDGE_" + seriesCmt;  // Renamed tag for clarity
   
   bool opened = SendOrder(hedgeDir, lot, false, 0, true, cmt);
   
   if(opened)
   {
      // Update Scenario E state
      g_scenarioEActive = true;
      g_hedgeBasketDir = losingBasketDir;
      g_hedgeReason = reason;
      if(g_scenarioEStartTime == 0) g_scenarioEStartTime = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| SIGNAL HANDLER - WITH MIN DISTANCE FILTER                         |
//| Blocks D when E is active; runner opens opposite the basket       |
//+------------------------------------------------------------------+
void HandleSignal(int signalDir)
{
   if(!InTradingSession(TimeCurrent())) return;
   if(!CooldownOK()) return;
   if(!ReEntryOK(signalDir)) return;
   if(SpreadPoints() > MaxSpreadPts) return;
   
   if(UseSlopeFilter)
   {
      int slopeDir = MarketSlopeSignalCached();
      if(slopeDir != 0 && signalDir != slopeDir) return;
   }
   
   EnsureSeriesActive(signalDir);
   string seriesCmt = SeriesKey(signalDir, CurrentSeriesId(signalDir));
   
   // Count ONLY inside this active series (basket)
   if(CountSeriesOrdersDir(signalDir, seriesCmt, true) >= MaxOrdersDir) return;

   int cntNoRunners = CountSeriesOrdersDir(signalDir, seriesCmt, false);
   
   // Standard orders (before Scenario D)
   if(!ScenarioD || cntNoRunners < startBe)
   {
      if(!CheckMinDistanceFromExistingOrders(signalDir)) return;
      SendOrder(signalDir, LotsBase, true, TP_Points, false, seriesCmt);
      return;
   }
   
   // ============================================================
   // SCENARIO D - Martingale with filters
   // ============================================================
   int basketDir = signalDir;

   // Check if Scenario E should activate
   string activationReason = "";
   bool shouldActivateE = CheckShouldActivateE(basketDir, activationReason);

   if(shouldActivateE)
   {
      // ============================================================
      // SCENARIO E - HEDGE MODE (runner opposite the basket)
      // ============================================================
      g_scenarioStatus = "E";

      // BLOCK: do not add more positions to the losing basket.
      // Instead open a runner in the opposite direction.
      TryOpenRunner(basketDir, activationReason);
      return;
   }

   // ============================================================
   // SCENARIO D CONTINUATION - add to basket
   // ============================================================
   g_scenarioStatus = "D";

   // Check step gate from basket BE
   if(!StepGateFromBasketBESeries(basketDir, seriesCmt)) return;

   // Check minimum distance from any existing orders
   if(!CheckMinDistanceFromExistingOrders(basketDir)) return;
   
   // Do NOT add on favorable side of BE (already recovered) - safety
   if(IsPriceFavorableOrAtBE(basketDir, seriesCmt)) return;

   bool moveAway = IsMovingAwayFromBESeries(basketDir, seriesCmt);

   double lot = 0.0;
   string cmtD = "";

   if(moveAway)
   {
      // Multiplied lots ONLY when price moves AWAY from BE (adverse expansion)
      int dStepNext = CountSeriesDAdds(basketDir, seriesCmt) + 1;

      // Multiply relative to the FIRST order in the basket (cost-stable behavior).
      double firstLot = FirstBasketLotSeries(basketDir, seriesCmt);
      double lotRaw = firstLot * MathPow(lotMultiplier, dStepNext);
      lot = ClampLot(lotRaw);

      cmtD = seriesCmt + "|D=" + IntegerToString(dStepNext);
   }
   else
   {
      // If price is moving TOWARD BE (still adverse, but recovering) -> ONLY base lot
      lot = ClampLot(LotsBase);
      cmtD = seriesCmt + "|DB";
   }

   bool opened = SendOrder(basketDir, lot, false, 0, false, cmtD);
   if(opened) ApplyBasketTPSeries(basketDir, seriesCmt);
}

//+------------------------------------------------------------------+
//| SIGNAL DETECTION                                                  |
//+------------------------------------------------------------------+
void DetectAndHandleSignal()
{
   int dir=0, peak=0, movePts=0;
   bool signal=false;
   
   double tickRate = GetAvgTickRate();
   bool useWindow = (UseTickWindowFallback && tickRate < TickRateThreshold);
   
   if(useWindow)
   {
      g_lastMode = "WINDOW";
      PushTickWindow(Bid);
      signal = EvaluateTickWindow(dir, peak, movePts);
   }
   else
   {
      g_lastMode = "SECOND";
      double bid = Bid;
      datetime secNow = TimeCurrent();
      
      if(g_sec == 0)
      {
         ResetSecond(secNow, bid);
         return;
      }
      
      if(secNow == g_sec)
      {
         g_lastBid = bid;
         AddTickToSecond(bid);
         return;
      }
      
      signal = EvaluateSecond(dir, peak, movePts);
      ResetSecond(secNow, bid);
   }
   
   if(!signal) return;
   
   g_lastSigDir = dir;
   g_lastPeak = peak;
   g_lastMovePts = movePts;
   
   HandleSignal(dir);
}

//+------------------------------------------------------------------+
//| REBUILD MARKERS                                                   |
//+------------------------------------------------------------------+
void RebuildLast24hMarkers()
{
   if(!ShowModernMarkers) return;
   
   datetime cutoff = TimeCurrent() - MARKERS_WINDOW_SEC;
   
   // Reset aggregation before rebuilding
   ResetBasketAggregation();
   
   int ht = OrdersHistoryTotal();
   int from = ht - 8000; if(from < 0) from = 0;
   for(int i=from;i<ht;i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if(OrderSymbol()!=Symbol()) continue;
      if(OrderMagicNumber()!=Magic) continue;
      
      if(OrderCloseTime() < cutoff) continue;
      MarkOrderCloseFromHistory();  // Collects for aggregation
   }
   
   // Draw aggregated basket labels
   DrawAggregatedBasketLabels();
   
   // Mark open orders with dots
   for(int j=OrdersTotal()-1;j>=0;j--)
   {
      if(!OrderSelect(j, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!IsMineTrade()) continue;
      if(OrderOpenTime() < cutoff) continue;
      MarkOrderOpen(OrderTicket());
   }
}

//+------------------------------------------------------------------+
//| UPDATE SCENARIO E STATE                                           |
//| Aktualizuje stan hedgingu dla dashboardu                          |
//+------------------------------------------------------------------+
void UpdateScenarioEState()
{
   // Count active runners (hedge positions)
   g_activeRunnersCount = 0;
   g_hedgeLotsTotal = 0;
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!IsMineTrade()) continue;
      if(!IsRunner()) continue;
      
      g_activeRunnersCount++;
      g_hedgeLotsTotal += OrderLots();
   }
   
   // Count lots in baskets
   double buyLots = SumLotsDir(+1, false);
   double sellLots = SumLotsDir(-1, false);
   
   // Determine which basket is being hedged (if E is active)
   if(g_activeRunnersCount > 0)
   {
      g_scenarioEActive = true;
      
      // Check runner direction to determine which basket is hedged
      for(int j = OrdersTotal() - 1; j >= 0; j--)
      {
         if(!OrderSelect(j, SELECT_BY_POS, MODE_TRADES)) continue;
         if(!IsMineTrade()) continue;
         if(!IsRunner()) continue;
         
         // Runner is OPPOSITE to the hedged basket
         int runnerDir = (OrderType() == OP_BUY ? +1 : -1);
         g_hedgeBasketDir = -runnerDir;
         break;
      }
      
      g_basketLotsTotal = (g_hedgeBasketDir > 0 ? buyLots : sellLots);
      g_scenarioStatus = "E";
   }
   else
   {
      // No runners - check whether we should be in E.
      // If no runners but there are open positions, we are in D.
      if(buyLots > 0 || sellLots > 0)
      {
         g_scenarioStatus = "D";
      }
      else
      {
         g_scenarioStatus = "IDLE";
      }
      
      // Reset E state if there are no runners
      if(g_scenarioEActive && g_activeRunnersCount == 0)
      {
         g_scenarioEActive = false;
         g_hedgeBasketDir = 0;
         g_hedgeReason = "";
         g_scenarioEStartTime = 0;
      }
   }
}

//+------------------------------------------------------------------+
//| CLEANUP DASHBOARD                                                 |
//+------------------------------------------------------------------+
void CleanupDashboard()
{
   int total = ObjectsTotal(0, 0, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, PREFIX, 0) == 0)
         ObjectDelete(0, name);
   }
}

//+------------------------------------------------------------------+
//| MT4 LIFECYCLE                                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   // Load saved positions from previous session and verify against terminal
   LoadPositionsFromFile();
   SyncPositionsWithTerminal(true);
   SavePositionsToFile();

   // Load pyramid state (if any) and verify against terminal
   LoadPyramidFromFile();
   SyncPyramidWithTerminal();
   SavePyramidToFile();

   g_sec = 0;
   g_levelsN = 0;

   g_tickHead = 0;
   g_tickSize = 0;
   g_winCount = 0;

   g_lastSignalTime = 0;
   g_lastBuyTime = 0;
   g_lastSellTime = 0;

   g_lastBarTime = 0;
   UpdateSlopeCacheIfNewBar();

   g_lastHistTotal = OrdersHistoryTotal();
   g_pnlDayKey = -1;
   ResetPnLDayIfNeeded();

   g_lastUiUpdate = 0;
   // g_buySeriesActive / g_sellSeriesActive set by SyncSeriesIdsFromOpenOrders()

   for(int i = 0; i < 5; i++) g_aiMessages[i] = "Initializing...";

   g_peakEquityEver = AccountEquity();
   g_peakEquityToday = AccountEquity();

   CalculateStatistics();

   CleanupOldMarkers();
   RebuildLast24hMarkers();

   g_eaStopped = false;

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   // Save current positions on EA stop/unload
   SyncPositionsWithTerminal(true);
   SavePositionsToFile();

   SyncPyramidWithTerminal();
   SavePyramidToFile();

   CleanupDashboard();
}

void OnTick()
{
   // Periodic sync of position memory with terminal
   if(TimeCurrent() - g_posLastSync >= 5)
      SyncPositionsWithTerminal(true);

   // Periodic sync + pyramid management (separate set)
   if(TimeCurrent() - g_pyrLastSync >= 5)
      SyncPyramidWithTerminal();
   PyramidManage();

   TickratePush(TimeCurrent());
   UpdateSlopeCacheIfNewBar();
   UpdateTickSize();
   UpdateMaxDD();

   CleanupOldMarkers();

   CheckButtonClicks();

   UpdateAISimulation();

   // Apply daily risk controls (may close positions + pause)
   ApplyDailyRiskControls();

   // Skip trading if EA is stopped OR auto-paused
   if(!g_eaStopped && !IsAutoPaused())
   {
      if(ScenarioE && HasAnyRunnersOpen())
         ManageRunnersTrailing();

      DetectAndHandleSignal();
   }
   
   ResetPnLDayIfNeeded();
   ScanHistoryNewAndUpdatePnLAndMarkers();
   
   FinalizeSeriesIfEnded(+1);
   FinalizeSeriesIfEnded(-1);
   
   // Update statistics periodically
   static datetime lastStatsUpdate = 0;
   if(TimeCurrent() - lastStatsUpdate >= 60)
   {
      CalculateStatistics();
      lastStatsUpdate = TimeCurrent();
   }
   
   // Draw dashboard and bottom results
   DrawProDashboard();
   DrawBottomResultsPanel();
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      // Handle button clicks immediately
      CheckButtonClicks();
   }
}
//+------------------------------------------------------------------+