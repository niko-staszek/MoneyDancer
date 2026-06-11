//+------------------------------------------------------------------+
//| Inputs.mqh — all input parameters                                |
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
input double PriceStep             = 0.25;   // Price range for burst detection
input int    BurstTicks            = 10;     // Tick burst count to detect order entry
input int    MinMovePoints         = 20;     // Minimum price move to qualify (points)
input int    CooldownSec           = 45;     // Minimum seconds between signals
input int    MaxSpreadPts          = 45;     // Maximum allowed spread (points)

//==================== HYBRID MODE (LOW TICKRATE FALLBACK) ====================
input bool   UseTickWindowFallback = true;   // Enable fallback for low-tick-rate environments
input int    TickRateLookbackSec   = 10;     // Lookback window for tick-rate check (seconds)
input double TickRateThreshold     = 4.0;    // Minimum tick rate to use burst mode
input int    TickWindowTicks       = 25;     // Tick window size for fallback detection

//==================== MA SLOPE FILTER ====================
input string __sec_trend_filter__ = "==== Filter for Trend Detection ====";
input bool   UseSlopeFilter        = true;   // Enable MA slope trend filter
input int    maPeriod              = 50;     // MA period for slope calculation
input int    slopeLookbackBars     = 5;      // Bars to look back for slope strength
input int    slopeThresholdPts     = 20;     // Minimum slope to confirm trend direction (points)
input int    strongTrendPts        = 60;     // Slope threshold to classify as strong trend (points)

//==================== TRADING ====================
input string __sec_orders_sl_tp__ = "==== Orders & SL & TP ====";
input double LotsBase              = 0.01;  // Base lot size for the first order
// --- v1.4 account-scaled position size (opt-in; AutoLotScaling=false => fixed LotsBase, 1.3-identical) ---
enum AutoLotMetric { Metric_Equity, Metric_Balance };   // dropdown: Equity / Balance
enum AutoLotCalc   { Calc_Add,      Calc_Multiply  };   // dropdown: Add / Multiply
input bool          AutoLotScaling   = false;           // Enable automatic lot scaling by account size
input AutoLotMetric AutoLotType      = Metric_Equity;   // Scale by Equity or Balance
input AutoLotCalc   AutoLotMode      = Calc_Add;         // Lot scaling method: Add or Multiply
input double        AutoLotDivisor   = 2000;            // Account units per 0.01 of base lot (with Add: ~0.5 base @100k)
input double        AutoLotIncrement = 0.01;            // Lot increment per unit (Add mode only)
input int    TP_Points             = 50;    // Take profit for the first order (points)
input int    SL_Points             = 0;     // Stop loss for the first order, points (0=OFF)
input int    Slippage              = 10;    // Maximum accepted slippage (points)
input int    Magic                 = 21010; // Magic number for this EA instance

//==================== SCENARIO D ====================
input string __sec_higher_risk__ = "==== Higher Risk Mode for Orders ====";
input bool   ScenarioD             = true;  // Enable Scenario D (martingale exit)
input int    startBe               = 5;     // Number of orders before seeking breakeven exit
input double lotMultiplier         = 1.50;  // Lot size multiplier per additional order
input int    bePoints              = 30;    // Breakeven target for all open orders (points)
input double maxLot                = 0.0;   // Maximum lot size per order (0=OFF)
input int    MaxOrdersDir          = 50;    // Maximum orders in one direction
input int    StepPoints            = 120;   // Minimum price move before adding next order (points)
input int    MinOrderDistancePts   = 100;   // Minimum distance between orders (points)
input bool   FoldManualOrders      = false;  // Manage hand-placed (magic 0) orders as part of the basket

input string __sec_gather_profits__ = "==== Gather Profits ====";
//==================== PYRAMIDING ====================
// Minimal state: ticket, trigger, tp, sl, index. Pyramid is always single-direction.
// TP distance is always TP_Points (same as basic orders).
input int    PyramRange              = 0;     // Pyramiding range, points (0=OFF)
input int    PyramSlopeEmaPeriod     = 3;     // EMA period for pyramid slope filter
input int    PyramSlopeLookbackBars  = 5;     // Bars to look back for pyramid slope strength
input double PyramSlopeAngleDeg      = 20.0;  // Minimum slope angle to allow pyramiding (degrees)
input int    PyramBEBufPts           = 0;     // Pyramid breakeven buffer (points)

//==================== GUARDS ====================
input string __sec_loss_control__ = "==== Set Loss Control ====";
input double MaxBasketDD_Pct       = 55.0; // Maximum drawdown per basket before hedge (%)
input double MaxEquityDD_Pct       = 80.0; // Maximum drawdown across all trades before hedge (%)

// Per-basket equity stop-loss rail
input double MaxBasketLossPct      = 0.0;  // Per-basket equity stop-loss, % at series open (0=OFF)
input int    MaxBasketSLPerDay     = 2;    // Pause for the day after this many basket stop-loss hits

// All-time drawdown kill
input double MaxAllTimeDDPct       = 0.0;  // All-time drawdown kill, % (0=OFF; try 40)

// ADX regime gate
enum ENUM_REGIME_MODE
{
   REGIME_OFF  = 0,
   REGIME_SOFT = 1,
   REGIME_HARD = 2,
};
input ENUM_REGIME_MODE RegimeMode      = REGIME_OFF;
input int              RegimeAdxThresh = 30;
input int              RegimePeriod    = 14;
input ENUM_TIMEFRAMES  RegimeTimeframe = PERIOD_M15;

//==================== DAILY RISK LOCKS ====================
input string __risk_sep__                 = "══════ DAILY RISK LOCKS ══════";
// Max Daily Profit: enter 1..999 (1=1% increase in BALANCE relative to the baseline at 01:00); 0 = OFF
input int    MaxDailyProfitPct            = 0;      // Daily profit cap (0=OFF, 1..999=%)
input int    DailyBaselineHour            = 1;      // Baseline snapshot hour (default 01:00)
input int    DailyBaselineMinute          = 0;      // Baseline snapshot minute (default 00)

// After This Hour Close (protection of earned profits):
// If, by the specified time (or after it) BALANCE - baseline >= AfterThisHourMinProfitUsd
// and total FLOAT (open positions) >= AfterThisHourMaxFloatingLossUsd (eq. -10.0),
// then the EA closes all positions and suspends trading until the next day.
input int    AfterThisHourCloseHour       = -1;     // Close and pause after this hour if profit met (-1=OFF)
input int    AfterThisHourCloseMinute     = 0;      // Minute for the after-hours profit protection check
input double AfterThisHourMinProfitUsd    = 0.0;    // Minimum profit in USD required to trigger protection
input double AfterThisHourMaxFloatingLossUsd = -10.0; // Maximum allowed floating loss in USD at trigger time

// Profit Lock After Time (uses daily baseline from DailyBaselineHour:DailyBaselineMinute):
// If enabled: EA works normally until the lock time (UntilHour:UntilMinute).
// At the lock time it snapshots today's profit (Balance - baseline). After that, EA will NOT allow giving back
// that locked profit. If Equity drops below (baseline + lockedProfit) -> CloseAll + pause trading until next day.
input bool   RiskFromCurrentProfit            = false; // Enable profit-lock after a set time
input int    RiskFromCurrentProfitUntilHour   = 13;    // Lock time — hour (server time)
input int    RiskFromCurrentProfitUntilMinute = 30;    // Lock time — minute

//==================== TOTAL PROFIT TARGET (1.1) ====================
// Stop trading once today's total P/L (realized + floating) hits the target.
// Daily reset: pauses until next server-time 00:00, like the other daily locks.
input string __profit_target_sep__       = "══════ TOTAL PROFIT TARGET ══════";
enum ENUM_DAILY_TARGET_MODE
{
   DAILY_TARGET_OFF = 0,   // Off
   DAILY_TARGET_PCT = 1,   // Percentage of baseline
   DAILY_TARGET_USD = 2    // Fixed USD amount
};
input ENUM_DAILY_TARGET_MODE DailyProfitTargetMode = DAILY_TARGET_OFF; // Daily profit target mode
input double DailyProfitTargetPct = 5.0;    // Profit target as % of daily baseline (Percentage mode)
input double DailyProfitTargetUsd = 100.0;  // Profit target as fixed USD amount (FixedUSD mode)

//==================== SCENARIO E ====================
input string __sec_big_losses__ = "==== Helper for BIG LOSSES ====";
input bool   ScenarioE             = false; // Enable Scenario E (active hedge on large losses)
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
