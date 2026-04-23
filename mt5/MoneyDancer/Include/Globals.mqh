//+------------------------------------------------------------------+
//| Globals.mqh — runtime state variables                            |
//| Phase A3: PosMem globals only. Other globals added in A5.        |
//+------------------------------------------------------------------+
#ifndef __MD_GLOBALS_MQH__
#define __MD_GLOBALS_MQH__

//==================== MARKERS WINDOW ====================
// Used by InLast24h() and marker cleanup. Kept as a var so future tuning is
// possible without a recompile; changed to const int for type safety in MT5.
const int MARKERS_WINDOW_SEC = 86400;

//==================== ACTIVE POSITION PERSISTENCE ====================
// Position tickets are ulong in MT5 (MT4 used int).
// Saved on EA stop/unload, reloaded on start.
// File location: MQL5\Files\<PositionsFileName()>
ulong    g_posTickets[];   // EA's active position tickets
double   g_posTP[];        // last known TP
double   g_posSL[];        // last known SL
datetime g_posLastSync = 0;

//==================== SLOPE CACHE (A5.1) ====================
// MA handles created in SlopeInit() / released in SlopeDeinit().
int      g_ma_handle_main  = INVALID_HANDLE;  // main slope filter EMA (maPeriod)
int      g_ma_handle_pyram = INVALID_HANDLE;  // pyramid slope EMA (PyramSlopeEmaPeriod)
datetime g_lastBarTime     = 0;
int      g_cachedSlopeDir  = 0;   // +1 up, 0 flat, -1 down
int      g_cachedSlopePts  = 0;

//==================== PYRAMID STATE (A5.2) ====================
// Minimal state per pyramid position: ticket, trigger, tp, sl, index.
// Pyramid is always single-direction (no pyramid hedging).
ulong    g_pyrTickets[];   // pyramid position tickets (ulong in MT5)
double   g_pyrTrigger[];   // trigger price (where next pyramid add is allowed)
double   g_pyrTP[];        // last known TP
double   g_pyrSL[];        // last known SL
int      g_pyrIndex[];     // add order index (1st, 2nd, ...); highest = "last"
datetime g_pyrLastSync = 0;

//==================== SERIES STATE (A5.2) ====================
// Series IDs identify a "basket generation" — every new series increments the
// counter, and closed+reopened cycles don't collide.
int  g_buySeriesId      = 0;
int  g_sellSeriesId     = 0;
bool g_buySeriesActive  = false;
bool g_sellSeriesActive = false;

//==================== DAILY RISK STATE (A5.4) ====================
int      g_baseDayKey       = -1;
double   g_dayBaseBalance   = 0.0;
datetime g_dayBaseTime      = 0;
bool     g_dayBaseReady     = false;

// Profit lock (RiskFromCurrentProfit)
bool     g_profitLockCaptured = false;
double   g_lockedProfitUsd    = 0.0;
datetime g_profitLockTime     = 0;

// Auto-pause state (MaxDailyProfitPct cap, AfterThisHour, PROFIT_LOCK)
datetime g_tradePauseUntil  = 0;
string   g_tradePauseReason = "";

// Cached daily metrics (for dashboard)
double   g_dayProfitUsd     = 0.0;
double   g_dayProfitPct     = 0.0;
double   g_dayTargetBalance = 0.0;

//==================== SCENARIO D/E STATE (A5.5) ====================
bool     g_scenarioEActive      = false;   // Is Scenario E (hedge mode) currently active?
int      g_hedgeBasketDir       = 0;       // Direction of basket being hedged (-1=SELL, +1=BUY)
int      g_activeRunnersCount   = 0;       // Number of active runner positions
double   g_hedgeLotsTotal       = 0;       // Total lots in hedge runners
double   g_basketLotsTotal      = 0;       // Total lots in losing basket
string   g_scenarioStatus       = "D";     // Current scenario: "D", "E", "IDLE"
string   g_hedgeReason          = "";      // Why E was activated
datetime g_scenarioEStartTime   = 0;       // When E was activated

// For siphon-on-close: track how many deals we've already processed so we
// only react to new closures (avoids re-firing siphon on every tick).
int      g_lastDealsCount       = 0;

//==================== SIGNAL PIPELINE STATE (A5.6) ====================

// Per-second tick-burst detection (second mode)
datetime g_sec      = 0;
double   g_firstBid = 0;
double   g_lastBid  = 0;
double   g_levels[MAX_LEVELS_PER_SEC];
int      g_counts[MAX_LEVELS_PER_SEC];
int      g_levelsN  = 0;

// Tick rate ring buffer (for MA + fallback mode detection)
datetime g_tickTimes[MAX_TICK_TIMES];
int      g_tickHead = 0;
int      g_tickSize = 0;

// Tick window fallback (low-tick-rate mode)
double   g_winBids[MAX_WIN_TICKS];
double   g_winLvls[MAX_WIN_TICKS];
int      g_winCount = 0;

// Cooldown timestamps
datetime g_lastSignalTime = 0;
datetime g_lastBuyTime    = 0;
datetime g_lastSellTime   = 0;

// Last signal diagnostic info (read by Dashboard later)
string   g_lastMode    = "SECOND";
int      g_lastSigDir  = 0;
int      g_lastPeak    = 0;
int      g_lastMovePts = 0;

// TODO A7 dashboard/telemetry + A6 MMD: added in the active-dev CashCabaret
//   repo (mt5/CashCabaret/Include/). This bare port stays at A5 end-state.

#endif // __MD_GLOBALS_MQH__
