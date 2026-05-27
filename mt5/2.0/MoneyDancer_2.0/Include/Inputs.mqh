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
input int    MonStart1Hour          = 0;     // Start Set 1: HH
input int    MonStart1Minute        = 0;     // Start Set 1: MM
input int    MonEnd1Hour            = 0;     // End Set 1: HH
input int    MonEnd1Minute          = 0;     // End Set 1: MM
input int    MonStart2Hour          = 0;     // Start Set 2: HH
input int    MonStart2Minute        = 0;     // Start Set 2: MM
input int    MonEnd2Hour            = 0;     // End Set 2: HH
input int    MonEnd2Minute          = 0;     // End Set 2: MM

// Tuesday
input bool   TuesdayTrading          = true;  // Tuesday Trading
input int    TueStart1Hour          = 0;
input int    TueStart1Minute        = 0;
input int    TueEnd1Hour            = 0;
input int    TueEnd1Minute          = 0;
input int    TueStart2Hour          = 0;
input int    TueStart2Minute        = 0;
input int    TueEnd2Hour            = 0;
input int    TueEnd2Minute          = 0;

// Wednesday
input bool   WednesdayTrading        = true;  // Wednesday Trading
input int    WedStart1Hour          = 0;
input int    WedStart1Minute        = 0;
input int    WedEnd1Hour            = 0;
input int    WedEnd1Minute          = 0;
input int    WedStart2Hour          = 0;
input int    WedStart2Minute        = 0;
input int    WedEnd2Hour            = 0;
input int    WedEnd2Minute          = 0;

// Thursday
input bool   ThursdayTrading         = true;  // Thursday Trading
input int    ThuStart1Hour          = 0;
input int    ThuStart1Minute        = 0;
input int    ThuEnd1Hour            = 0;
input int    ThuEnd1Minute          = 0;
input int    ThuStart2Hour          = 0;
input int    ThuStart2Minute        = 0;
input int    ThuEnd2Hour            = 0;
input int    ThuEnd2Minute          = 0;

// Friday
input bool   FridayTrading           = true;  // Friday Trading
input int    FriStart1Hour          = 0;
input int    FriStart1Minute        = 0;
input int    FriEnd1Hour            = 0;
input int    FriEnd1Minute          = 0;
input int    FriStart2Hour          = 0;
input int    FriStart2Minute        = 0;
input int    FriEnd2Hour            = 0;
input int    FriEnd2Minute          = 0;

//==================== SIGNAL (Tick Burst) ====================
input string __sec_ai_order_detection__ = "==== Order Detection ====";
input double PriceStep             = 0.25;   // Price Range for Burst
input int    BurstTicks            = 10;     // Detect TOE and Burst
input int    MinMovePoints         = 20;     // Min. impact for price (points)
input int    CooldownSec           = 45;     // Time Filter

// S2.A — adaptive MinMovePoints based on ATR. When mode != MM_FIXED, the EA
// uses EffectiveMinMovePoints() instead of the raw input. Default FIXED
// preserves legacy behavior; opt-in via the mode input.
enum ENUM_MINMOVE_MODE
{
   MM_FIXED          = 0,   // Use raw MinMovePoints (default)
   MM_ATR_INVERSE    = 1,   // Higher vol -> lower MinMove (lets strategy grind)
   MM_ATR_LINEAR     = 2,   // Higher vol -> higher MinMove (proportional)
};
input ENUM_MINMOVE_MODE MinMoveAdaptiveMode = MM_FIXED;          // S2.A scaling mode
input ENUM_TIMEFRAMES   MinMoveATRTimeframe = PERIOD_M15;        // ATR timeframe for adaptive MinMove
input int               MinMoveATRPeriod    = 14;                // ATR period
input double            MinMoveATRConstant  = 1500.0;            // INVERSE: MinMove = C / ATR_pts
input double            MinMoveATRMult      = 1.0;               // LINEAR: MinMove = mult * ATR_pts
input int               MinMovePointsMin    = 20;                // Floor for adaptive MinMove
input int               MinMovePointsMax    = 80;                // Ceiling for adaptive MinMove

// S2.A.2 — ATR-floor entry gate. When > 0, blocks all new entries when ATR is
// below this threshold (in points). Targets extreme low-vol cells (mar25-type)
// where strategy has no edge. ATR timeframe + period reused from MinMove inputs.
input int               MinATRPointsForEntry = 0;                // S2.A.2 skip-trade floor (0=OFF)

// S2.A.3 — regime-aware lot scaling. Multiplies ComputeBaseLot() result by
// LotMultRange (when MMD says range, i.e., MMD_RegimeSimple==0) or LotMultTrend
// (when MMD says trend, ±1). Default both 1.0 = legacy. Only meaningful when
// UseMMDClassifier=true. Applied at series-open only; martingale adds preserve
// the basket's original sizing via FirstBasketLotSeries.
input double            LotMultRange         = 1.0;              // S2.A.3 lot multiplier in MMD-range
input double            LotMultTrend         = 1.0;              // S2.A.3 lot multiplier in MMD-trend
input int    MaxSpreadPts          = 45;     // Max Spread (points)

//==================== HYBRID MODE (LOW TICKRATE FALLBACK) ====================
input bool   UseTickWindowFallback = true;   // Support for Burst Detection
input int    TickRateLookbackSec   = 10;     // Check TOE in Zone
input double TickRateThreshold     = 4.0;    // Min. TOE in Range
input int    TickWindowTicks       = 25;     // Check next X Trades for TOE

//==================== MA SLOPE FILTER ====================
input string __sec_trend_filter__ = "==== Filter for Trend Detection ====";
input bool   UseSlopeFilter        = true;   // Dynamic - Strength of Momentum
input int    MAPeriod              = 50;     // Dynamic Period
input int    SlopeLookbackBars     = 5;      // Min. sequences for Strength
input int    SlopeThresholdPts     = 20;     // Dynamic force threshold for direction confirmation
input int    StrongTrendPts        = 60;     // Threshold for detecting strong dynamics

//==================== TRADING ====================
input string __sec_orders_sl_tp__ = "==== Orders & SL & TP ====";
input double LotsBase              = 0.01;  // Basic Order Size (used when LotsBaseMode=FIXED)

// S1.5 — auto-scaled LotsBase. When LotsBasePerThousand > 0, the EA computes
// LotsBase as (current_equity / 1000) * LotsBasePerThousand and uses that for
// new entries. Lets the same .set scale across 5k → 100k → 200k accounts
// without manual edits. Default 0 = use the fixed LotsBase above.
input double LotsBasePerThousand   = 0.0;   // S1.5 Lots per $1000 of equity (0=OFF; recommend 0.002 for 0.01@5k / 0.20@100k)
input int    TPPoints             = 50;    // Take Profit for Basic Order
input int    SLPoints             = 0;     // Stop Loss for Basic Order (MT4 original)
input int    Slippage              = 10;    // Accepted slippage for price
input int    Magic                 = 21010; // Magic Number

//==================== SCENARIO D ====================
input string __sec_higher_risk__ = "==== Higher Risk Mode for Orders ====";
input bool   ScenarioD             = true;  // MoE for Exit
input int    StartBE               = 5;     // After X Trades find Exit
input double LotMultiplier         = 1.50;  // Multiply Basic Order *X (used in MMD-trend if Range set)
// S2.C.5 — regime-aware martingale multiplier. When > 0 AND UseMMDClassifier=true,
// uses this value when MMD_RegimeSimple()==0 (range regime). In trend (MMD=±1),
// keeps using LotMultiplier. When 0 (default), falls back to LotMultiplier for all
// regimes — legacy behavior. Discovery from S2.C.2: weak/range cells benefit from
// gentler 2.5x, monsters need aggressive 4.0x. Regime-aware splits these answers.
input double LotMultiplierRange    = 0.0;   // S2.C.5 martingale mult in MMD-range (0=use LotMultiplier)
input int    BEPoints              = 30;    // Breakeven for ALL (sell or buy) Orders
input double MaxLot                = 0.0;   // Max Lot Size
input int    MaxOrdersDir          = 50;    // Max Orders in one Direction
input int    StepPoints            = 120;   // After X points let MOE run
input int    MinOrderDistancePts   = 100;   // Min distance between orders (points)

input string __sec_gather_profits__ = "==== Gather Profits ====";
//==================== PYRAMIDING ====================
// Minimal state: ticket, trigger, tp, sl, index. Pyramid is always single-direction.
// TP distance is always TPPoints (same as basic orders).
input int    PyramRange              = 0;     // Pyramiding Range (0=OFF, >0=ON)
input int    PyramSlopeEmaPeriod     = 3;     // Dynamic Period
input int    PyramSlopeLookbackBars  = 5;     // Min. sequences for Strength
input double PyramSlopeAngleDeg      = 20.0;  // Angle threshold (deg)
input int    PyramBEBufPts           = 0;     // Optional Breakeven buffer (points)
// S3.2c — fixed-TP mode for pyramid positions. When > 0, each pyramid position
// opens with TP = entry +/- PyramidFixedTPPts and PyramidManage skips the
// BUILDING/COASTING TP-overriding. Lets pyramid run as "single-position-with-
// fixed-TP" during steep-slope trends (works with WT regime gate). When 0,
// legacy BUILDING/COASTING behavior.
input int    PyramidFixedTPPts       = 0;     // S3.2c TP for pyramid pos (0=legacy build/coast)

//==================== GUARDS ====================
input string __sec_loss_control__ = "==== Set Loss Control ====";
input double MaxBasketDDPct       = 55.0; // Max DD per basket -> hedge. Test it!
input double MaxEquityDDPct       = 80.0; // Max DD across all trades -> hedge. Test it!

// S1.0 — per-basket equity stop-loss rail (default OFF for 1:1 1.1 parity).
// When a series' floating loss reaches MaxBasketLossPct of the equity at series open,
// close every position in that series and mark the series dead so Scenario E does
// not spawn runners. After MaxBasketSLPerDay triggers in a server day, pause new
// entries until 00:00. Set MaxBasketLossPct=0 to disable.
input double MaxBasketLossPct      = 0.0; // S1.0 Per-basket SL as % of equity at series open (0=OFF)
input int    MaxBasketSLPerDay     = 2;   // S1.0 Pause day after this many basket-SL triggers

// S2.A.7 Option 1 — regime-direction-aware basket SL.
// When != 0, override the single MaxBasketLossPct based on basket-direction-vs-MMD.
// Defaults all 0 = use single MaxBasketLossPct (legacy). Set independently to test.
// Recommended: Range=8, TrendWith=12, TrendAgainst=4 (let with-trend baskets ride pullbacks,
// kill against-trend baskets fast). Requires UseMMDClassifier=true to activate.
input double MaxBasketLossPctRange        = 0.0;  // 0 = use MaxBasketLossPct
input double MaxBasketLossPctTrendWith    = 0.0;  // 0 = use MaxBasketLossPct
input double MaxBasketLossPctTrendAgainst = 0.0;  // 0 = use MaxBasketLossPct

// S2.A.7 Option 2 — block ScenarioD martingale adds when MMD opposes basket direction.
// Existing TrendBlocksD uses slope filter; this adds MMD as additional gate.
// When true and UseMMDClassifier=true: if MMD_RegimeSimple opposes basket dir, block
// new D adds. Existing basket positions still TP/SL normally.
input bool   BlockDOnAdverseMMD           = false;

// S2.A.7 Option 3 — gate ScenarioE hedge runner activation by MMD.
// ScenarioE existing logic activates on MaxBasketDDPct threshold. When
// UseMMDAdverseGateForE=true and UseMMDClassifier=true, ScenarioE additionally
// requires MMD to oppose the basket direction (i.e., hedge only when trend
// really is against us, not on random basket DDs in range regimes).
input bool   UseMMDAdverseGateForE        = false;

// S1.6 — all-time peak-to-trough drawdown kill (default OFF for 1.1 parity).
// Tracks running max equity since EA start. When (peak - current) / peak * 100 >=
// MaxAllTimeDDPct, close every position and pause until the next 00:00. The DD
// ceiling is intentionally generous at first (40% per the rails-on baseline plan)
// and is meant to be hardened (40 → 30 → 25) once Sprint 1 is validated.
input double MaxAllTimeDDPct       = 0.0; // S1.6 All-time peak-to-trough DD % ceiling (0=OFF; recommend 40)

// S1.7 — Friday end-of-week flatten (default OFF for 1.1 parity).
// Gold opens Sunday with 20-50 pt gaps that blow through per-basket SL before
// any tick fires. After this hour Friday server-time: close every position and
// pause new entries until Monday 00:00. Empirically: 4 of 5 worst OOS-2025
// drawdowns started on a Friday and bled through the weekend.
input int    FridayFlattenHour     = 0;   // S1.7 Hour 0..23 (server time) to flatten on Friday (0=OFF; recommend 20)

// S2.C.8 — Daily pre-close flatten + XAU daily-break pause (default OFF).
// Close every position N minutes before the XAU daily-break window (~00:00 UTC
// where the broker reports "Market closed" and basket-SL rail cannot close
// baskets). Empirically motivated by may25-H2's 40.48% DD breach: basket bled
// during the ~30-min closed pocket because the rail couldn't fire. Resume at
// DailyResumeHour the next morning. Friday is already covered by S1.7 when on.
input int    DailyPreCloseHour     = 0;   // S2.C.8 Hour 0..23 server time to flatten daily (0=OFF; recommend 22)
input int    DailyPreCloseMinute   = 0;   // S2.C.8 Minute 0..59 of cutoff (recommend 0)
input int    DailyResumeHour       = 1;   // S2.C.8 Hour server time to resume next day
// S2.C.8 — Conditional flatten threshold. 0.0 = always close all (legacy unconditional);
// >0.0 = only close baskets whose floating loss >= X% of equity. Lets winning baskets run.
input double DailyPreCloseLossThresholdPct = 0.0; // S2.C.8 Close only if basket floating loss >= % equity (0=close all)

// PL.5 — Daily EOD summary webhook (Discord/Telegram). Default OFF.
// REQUIRES: add webhook URL to Tools > Options > Expert Advisors > "Allow WebRequest for listed URL".
// Format auto-detected: URL containing "telegram" uses Telegram bot API ({"text":...});
// everything else assumes Discord webhook ({"content":...}).
input bool   WebhookEnabled        = false; // PL.5 Enable daily EOD push to webhook URL
input string WebhookUrl            = "";    // PL.5 Webhook URL (Discord or Telegram bot sendMessage URL)
input int    WebhookEodHour        = 22;    // PL.5 Server hour 0..23 to push EOD summary
input int    WebhookEodMinute      = 30;    // PL.5 Server minute 0..59 of EOD push

// S1.1 — News-calendar blackout (default OFF; calendar inlined in NewsCalendar.mqh).
input bool   UseNewsBlackout       = false;  // S1.1 Block new entries around calendar events
input int    NewsBlackoutPreMin    = 30;     // Minutes BEFORE the event to start blocking
input int    NewsBlackoutPostMin   = 15;     // Minutes AFTER the event to keep blocking
input bool   NewsBlackoutTier2     = false;  // Also block on tier-2 events (default: T1 only)

// S1.4 — Rolling-spread spike circuit breaker (default OFF).
// Computes a rolling median over the last N seconds of spread observations and
// blocks new entries when the current spread exceeds median * k. Targets
// rollover spikes, news widening, and weekend-edge thin liquidity.
input bool   UseSpreadSpikeGuard   = false;  // S1.4 Enable rolling-spread spike block
input double SpreadSpikeMultK      = 3.0;    // S1.4 Current spread must be <= median * K
input int    SpreadSpikeWindowSec  = 300;    // S1.4 Rolling-median window (seconds)
input int    SpreadSpikeMinSamples = 30;     // S1.4 Minimum samples before guard activates

// S1.3 — Hard daily-loss kill (per-day intraday floor; complements S1.6 all-time).
input double MaxDailyLossPct       = 0.0;    // S1.3 Day-pause when realized+floating loss >= % (0=OFF; recommend 15)

// S2.0 — Time-window codification (block specific bad hours discovered in S2.0).
// HourBlockMask: comma-separated server-time hours to block (e.g., "18,23").
// Empty string = no extra blocking (legacy hour windows still apply).
input string HourBlockList         = "";     // S2.0 e.g. "18,23" to block evening losing hours

// S3.2 — simple regime gate (ADX-based; rule-based first cut).
// When RegimeMode=HARD and ADX(_Period, _TF) >= RegimeAdxThresh, HandleSignal
// short-circuits and no new grid entries fire. Pyramid is unaffected. Default
// OFF so 1.1 parity is preserved.
enum ENUM_REGIME_MODE
{
   REGIME_OFF  = 0,   // Off (default; full 1.1 behavior)
   REGIME_SOFT = 1,   // Soft: log-only, do not block (telemetry mode)
   REGIME_HARD = 2,   // Hard: block grid entries when ADX >= threshold
};
input ENUM_REGIME_MODE RegimeMode        = REGIME_OFF;       // S3.2 Regime gate mode
input int              RegimeAdxThresh   = 30;               // S3.2 ADX threshold for TREND classification
input int              RegimePeriod      = 14;               // S3.2 ADX period
input ENUM_TIMEFRAMES  RegimeTimeframe   = PERIOD_M15;       // S3.2 Timeframe ADX is computed on

// S3.2b — what to do in MMD-trend regime. When MMD says +1 (bull) or -1 (bear),
// the EA can either block both directions (S17 ship behavior) or allow only
// trend-aligned entries (with-trend grid). ADX has no direction so this is
// only meaningful when UseMMDClassifier=true.
enum ENUM_REGIME_TREND_MODE
{
   REGIME_TREND_BLOCK_BOTH    = 0,   // S17 ship behavior — block both dirs (default)
   REGIME_TREND_WITH_TREND    = 1,   // S3.2b — allow grid only in MMD's trend direction
};
input ENUM_REGIME_TREND_MODE RegimeTrendMode = REGIME_TREND_BLOCK_BOTH;  // S3.2b in-trend behavior

// S3.2a — MMD multi-cloud regime classifier (lifted from CashCabaret).
// When UseMMDClassifier=true and RegimeMode=HARD, the gate uses MMD_RegimeSimple
// (7-cloud stacking; classifies BULL/RANGE/BEAR via {+1,+0.5,0,-0.5,-1} stack)
// instead of the simple ADX threshold. MMD is per-bar cached.
input bool             UseMMDClassifier   = false;   // S3.2a Use MMD instead of ADX
input int              MMDPeriodRed      = 12;      // fast cloud
input int              MMDPeriodOrange   = 48;
input int              MMDPeriodLBlue    = 144;
input int              MMDPeriodBlue     = 288;
input int              MMDPeriodLGreen   = 720;
input int              MMDPeriodGreen    = 1440;
input int              MMDPeriodPurple   = 3456;   // slow cloud

//==================== DAILY RISK LOCKS ====================
input string __sec_daily_risk__                 = "══════ DAILY RISK LOCKS ══════";
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

// S1.2 — % parallels to the USD thresholds above. When > 0 these REPLACE the
// corresponding USD value via baseline-balance scaling so the same .set works
// across 5k / 100k / 200k accounts without manual edits.
input double AfterThisHourMinProfitPct    = 0.0;    // S1.2 (0=use USD value)
input double AfterThisHourMaxFloatingLossPct = 0.0; // S1.2 (0=use USD value; e.g. 0.2 = -0.2% of baseline)

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
input string __sec_profit_target__       = "══════ TOTAL PROFIT TARGET ══════";
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
input string __sec_big_losses__ = "==== Helper for BIG LOSSES ====";
input bool   ScenarioE             = false; // Test it! Active hedge!
input double HedgeRatio            = 0.35;
input int    RunnerBEStartPts     = 120;
input int    RunnerTrailDistPts    = 200;
input int    RunnerTrailStepPts    = 50;
input double SiphonPct             = 0.90;
input double MinPartialCloseLot    = 0.01;

//==================== DASHBOARD ====================
input string __sec_dashboard__          = "══════ DASHBOARD ══════";
input bool   ShowProDashboard      = true;
input int    DashboardX            = 20;
input int    DashboardY            = 30;
input int    DashboardWidth        = 420;
input color  DashAccentColor       = clrDodgerBlue;
input color  DashProfitColor       = clrLime;
input color  DashLossColor         = clrCrimson;

//==================== MODERN MARKERS ====================
input string __sec_markers__          = "══════ MODERN MARKERS ══════";
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
