//+------------------------------------------------------------------+
//| Inputs.mqh — all input parameters                                |
//| Phase A2: ported 1:1 from MT4 source. Same names, same defaults. |
//| New Phase B inputs (IDLE rails, news, scalper toggle) added in   |
//| Section 18 at the bottom.                                        |
//+------------------------------------------------------------------+
#ifndef __MD_INPUTS_MQH__
#define __MD_INPUTS_MQH__

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
input int    MinMovePoints         = 20;     // Min. impact for price (points)
input int    CooldownSec           = 45;     // Time Filter
input int    MaxSpreadPts          = 45;     // Max Spread (points)

//==================== HYBRID MODE (LOW TICKRATE FALLBACK) ====================
input bool   UseTickWindowFallback = true;   // Support for Burst Detection
input int    TickRateLookbackSec   = 10;     // Check TOE in Zone
input double TickRateThreshold     = 4.0;    // Min. TOE in Range
input int    TickWindowTicks       = 25;     // Check next X Trades for TOE

//==================== MA SLOPE FILTER ====================
input string __sec_trend_filter__ = "==== Filter for Trend Detection ====";
input bool   UseSlopeFilter        = true;   // Dynamic - Strength of Momentum
input int    maPeriod              = 50;     // Dynamic Period
input int    slopeLookbackBars     = 5;      // Min. sequences for Strength
input int    slopeThresholdPts     = 20;     // Dynamic force threshold for direction confirmation
input int    strongTrendPts        = 60;     // Threshold for detecting strong dynamics

//==================== TRADING ====================
input string __sec_orders_sl_tp__ = "==== Orders & SL & TP ====";
input double LotsBase              = 0.01;  // Basic Order Size
input int    TP_Points             = 50;    // Take Profit for Basic Order
input int    SL_Points             = 0;     // Stop Loss for Basic Order (MT4 original)
input int    Slippage              = 10;    // Accepted slippage for price
input int    Magic                 = 21010; // Magic Number

//==================== SCENARIO D ====================
input string __sec_higher_risk__ = "==== Higher Risk Mode for Orders ====";
input bool   ScenarioD             = true;  // MoE for Exit
input int    startBe               = 5;     // After X Trades find Exit
input double lotMultiplier         = 1.50;  // Multiply Basic Order *X
input int    bePoints              = 30;    // Breakeven for ALL (sell or buy) Orders
input double maxLot                = 0.0;   // Max Lot Size
input int    MaxOrdersDir          = 50;    // Max Orders in one Direction
input int    StepPoints            = 120;   // After X points let MOE run
input int    MinOrderDistancePts   = 100;   // Min distance between orders (points)

input string __sec_gather_profits__ = "==== Gather Profits ====";
//==================== PYRAMIDING ====================
// Minimal state: ticket, trigger, tp, sl, index. Pyramid is always single-direction.
// TP distance is always TP_Points (same as basic orders).
input int    PyramRange              = 0;     // Pyramiding Range (0=OFF, >0=ON)
input int    PyramSlopeEmaPeriod     = 3;     // Dynamic Period
input int    PyramSlopeLookbackBars  = 5;     // Min. sequences for Strength
input double PyramSlopeAngleDeg      = 20.0;  // Angle threshold (deg)
input int    PyramBEBufPts           = 0;     // Optional Breakeven buffer (points)

//==================== GUARDS ====================
input string __sec_loss_control__ = "==== Set Loss Control ====";
input double MaxBasketDD_Pct       = 55.0; // Max DD per basket -> hedge. Test it!
input double MaxEquityDD_Pct       = 80.0; // Max DD across all trades -> hedge. Test it!

//==================== DAILY RISK LOCKS ====================
input string __risk_sep__                 = "══════ DAILY RISK LOCKS ══════";
// Max Daily Profit: enter 1..999 (1=1% increase in BALANCE relative to the baseline at 01:00); 0 = OFF
input int    MaxDailyProfitPct            = 0;      // Daily Profit (0=OFF, 1..999=%)
input int    DailyBaselineHour            = 1;      // Hour baseline (default 01:00)
input int    DailyBaselineMinute          = 0;      // Minute baseline (default 00)

// After This Hour Close (protection of earned profits):
// If, by the specified time (or after it) BALANCE - baseline >= AfterThisHourMinProfitUsd
// and total FLOAT (open positions) >= AfterThisHourMaxFloatingLossUsd (eq. -10.0),
// then the EA closes all positions and suspends trading until the next day.
input int    AfterThisHourCloseHour       = -1;     // After this Hour Protect Profit (-1=OFF, 0..23=Hour)
input int    AfterThisHourCloseMinute     = 0;      // After this Minute Protect Profit (default 00)
input double AfterThisHourMinProfitUsd    = 0.0;    // Profit in USD, then Protect
input double AfterThisHourMaxFloatingLossUsd = -10.0; // FLOAT in USD must be >= this value (eq. -10)

// Profit Lock After Time (uses daily baseline from DailyBaselineHour:DailyBaselineMinute):
// If enabled: EA works normally until the lock time (UntilHour:UntilMinute).
// At the lock time it snapshots today's profit (Balance - baseline). After that, EA will NOT allow giving back
// that locked profit. If Equity drops below (baseline + lockedProfit) -> CloseAll + pause trading until next day.
input bool   RiskFromCurrentProfit            = false; // Enable Profit Lock
input int    RiskFromCurrentProfitUntilHour   = 13;    // Lock time - Hour (server time)
input int    RiskFromCurrentProfitUntilMinute = 30;    // Lock time - Minute

//==================== SCENARIO E ====================
input string __sec_big_losses__ = "==== Helper for BIG LOSSES ====";
input bool   ScenarioE             = false; // Test it! Active hedge!
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

// Tags used in position comments. These are not inputs — tuned centrally here.
const string RUNNER_TAG = "HEDGE_";  // Tag for hedge positions (Scenario E)
const string PREFIX     = "MD_";     // Object/file-name prefix (was "PROAI_" in MT4)

#endif // __MD_INPUTS_MQH__
