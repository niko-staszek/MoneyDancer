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

//==================== DASHBOARD STATE (A7b) ====================
// Visual-only. Strategy has no functional dependency on these.
// Mirrored from the active-dev CashCabaret repo (Dashboard.mqh is visually
// identical); the bare port stays frozen at A5 end-state for strategy code.

// Avg tick-size ring (chart-noise metric shown on dashboard)
double   g_lastPrice        = 0.0;
double   g_tickSizes[MAX_TICK_SIZES];
int      g_tickSizeHead     = 0;
int      g_tickSizeCount    = 0;

// Daily / all-time drawdown tracking (peak equity vs current)
int      g_ddDayKey         = -1;
double   g_peakEquityToday  = 0.0;
double   g_peakEquityEver   = 0.0;
double   g_maxDDToday       = 0.0;
double   g_maxDDEver        = 0.0;

// Period stats (today / week / month × long / short). Counts + profit sums.
int      g_closedLongToday  = 0;
int      g_closedShortToday = 0;
double   g_profitLongToday  = 0.0;
double   g_profitShortToday = 0.0;
int      g_closedLongWeek   = 0;
int      g_closedShortWeek  = 0;
double   g_profitLongWeek   = 0.0;
double   g_profitShortWeek  = 0.0;
int      g_closedLongMonth  = 0;
int      g_closedShortMonth = 0;
double   g_profitLongMonth  = 0.0;
double   g_profitShortMonth = 0.0;

// Basket-close aggregation (group closes within 5s window for one label)
datetime g_basketCloseTime[];
double   g_basketClosePrice[];
double   g_basketProfit[];
int      g_basketType[];          // direction sign: +1 buy, -1 sell
int      g_basketCount      = 0;

// "AI" simulation — cosmetic status + confidence widget
datetime g_lastAiUpdate       = 0;
int      g_scanPhase          = 0;
string   g_aiStatus           = "INITIALIZING";
string   g_aiPattern          = "";
string   g_marketRegime       = "RANGING";
int      g_aiConfidence       = 80;
int      g_aiConfidenceTarget = 80;
datetime g_lastTradeTime      = 0;
int      g_riskLevel          = 0;
int      g_tradeQuality       = 0;
string   g_aiMessages[5];
int      g_aiMsgIndex         = 0;

// Dashboard / button throttles (1-sec cooldown)
datetime g_lastDashUpdate   = 0;
datetime g_lastButtonCheck  = 0;
datetime g_lastBottomUpdate = 0;

// EA run-state toggle (STOP / START button)
bool     g_eaStopped        = false;

// Stats panel view mode: 0=today, 1=week, 2=month
int      g_statsViewMode    = 0;

// Bottom-panel M15 bucketed PnL (96 slots = 24h × 4)
double   g_m15Pnl[96];
int      g_pnlDayKey        = -1;
int      g_lastHistTotal    = 0;

// Old-marker cleanup throttle (60-sec cooldown)
datetime g_lastCleanup      = 0;

#endif // __MD_GLOBALS_MQH__
