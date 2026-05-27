//+------------------------------------------------------------------+
//|                                                MoneyDancer 2.0   |
//|                                                             JoJo |
//+------------------------------------------------------------------+
//| 2.0 = full Sprint 1 + Sprint 2 entry. All rails default OFF so a |
//| 1.x .set produces identical behavior; turn rails on individually  |
//| via the corresponding Use* / numeric inputs.                      |
//|                                                                   |
//| Sprint 1 (survival rails, in Risk.mqh / Guards.mqh):              |
//|   S1.0  Per-basket equity SL (with close-failure escalation)      |
//|   S1.1  News-calendar blackout (MT5 native + 140-event fallback)  |
//|   S1.2  % thresholds (scale-portable across 5k/100k/200k)         |
//|   S1.3  Intraday daily-loss kill                                  |
//|   S1.4  Rolling-spread spike circuit breaker                      |
//|   S1.5  Auto-scaled LotsBase (equity/1000 * LotsBasePerThousand)  |
//|   S1.6  All-time peak-to-trough DD trailing kill                  |
//|   S1.7  Friday end-of-week flatten                                |
//|                                                                   |
//| Sprint 2 entry (still all OFF by default):                        |
//|   S2.0  Hour-of-day blocklist (HourBlockList="18,23" recommended) |
//|   S3.2  ADX regime gate                                           |
//|   S3.2a MMD multi-cloud regime classifier                         |
//|                                                                   |
//| Bugfixes baked in 2026-05-17 (Feb-2025 OOS catastrophe lesson):   |
//|   - Rails no longer respect IsAutoPaused() — must monitor open    |
//|     positions even while new entries are paused.                  |
//|   - Series-close failure escalates to CloseAllPositions() and     |
//|     does NOT increment the daily SL counter (was causing a        |
//|     spurious day-pause that left positions to bleed for hours).   |
//+------------------------------------------------------------------+
#property copyright "JoJo"
#property version   "2.0"
#property strict

#include <Trade\Trade.mqh>

// Include order matters — downstream modules reference upstream symbols.
// Dependencies: Inputs → Globals → Utils → Persistence → Orders → Slope
//   → Regime → Pyramid → Series → Basket → ScenarioD → Risk → ScenarioE
//   → Dashboard → Telemetry → Signal
// Regime (S3.2) sits next to Slope — both are indicator-cached and consulted
// by Signal.mqh before opening entries.
#include "Include/Inputs.mqh"
#include "Include/Globals.mqh"
#include "Include/Utils.mqh"
#include "Include/Persistence.mqh"
#include "Include/RailStatePersist.mqh"
#include "Include/SymbolSpec.mqh"
#include "Include/Webhook.mqh"
#include "Include/RegimeTrace.mqh"
#include "Include/Orders.mqh"
#include "Include/Slope.mqh"
#include "Include/MMD.mqh"
#include "Include/Regime.mqh"
#include "Include/Pyramid.mqh"
#include "Include/Series.mqh"
#include "Include/Basket.mqh"
#include "Include/ScenarioD.mqh"
#include "Include/Risk.mqh"
#include "Include/ScenarioE.mqh"
#include "Include/Dashboard.mqh"
#include "Include/Telemetry.mqh"
#include "Include/NewsCalendar.mqh"
#include "Include/Guards.mqh"
#include "Include/Signal.mqh"

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("MoneyDancer 2.0 init — Sprint 1 rails + Sprint 2 entry");

   // PL.3 — verify broker symbol spec before doing anything else.
   // Aborts init if XAU contract_size / vol_min/step / digits / tradeable are unexpected.
   // Tester is exempt (custom symbols may have non-standard specs by design).
   if(!MQLInfoInteger(MQL_TESTER))
   {
      if(!VerifySymbolSpec())
      {
         Print("[PL.3] aborting OnInit due to symbol-spec failure");
         return(INIT_FAILED);
      }
   }

   // Configure CTrade (magic, slippage, filling mode).
   OrdersInit();

   // Create MA handles for slope cache + pyramid slope.
   if(!SlopeInit()) return(INIT_FAILED);

   // S3.2 — regime gate (no-op when RegimeMode=OFF).
   if(!RegimeInit()) return(INIT_FAILED);

   // S3.2a — MMD multi-cloud classifier (lazy-init handles).
   if(!MMD_Init()) return(INIT_FAILED);

   // S1.1 — load economic calendar (inlined; no file I/O).
   News_Init();

   // S1.4 + S2.0 — init spread-spike ring + hour-block parsing.
   Guards_Init();

   // Load saved positions from previous session; verify against terminal.
   LoadPositionsFromFile();
   SyncPositionsWithTerminal(true);
   SavePositionsToFile();

   // Load pyramid state and verify against terminal.
   LoadPyramidFromFile();
   SyncPyramidWithTerminal();
   SavePyramidToFile();

   // Recover series IDs from open-position comments.
   SyncSeriesIdsFromOpenOrders();

   // Dashboard state + rehydrate last 24h markers from history.
   Dashboard_Init();
   RebuildLast24hMarkers();

   // PL.1 — load saved rail state (S1.6 peak, S1.0 day counter, pauses, series anchors).
   // Skipped in tester. Restored values OVERRIDE the fresh inits above where they overlap.
   LoadRailState();

   // PL.4 — open today's telemetry CSV + log init event.
   TelemetryInit();

   // S2.C.9 — per-trade regime trace (tester-allowed, default OFF).
   RegimeTrace_Init();

   // PL.1 — 60s heartbeat to persist rail state (mirrors what live needs).
   if(!MQLInfoInteger(MQL_TESTER))
      EventSetTimer(60);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Periodic heartbeat — persist rail state every 60s (PL.1)         |
//+------------------------------------------------------------------+
void OnTimer()
{
   SaveRailState();         // PL.1 — heartbeat persistence
   WebhookCheckAndFire();   // PL.5 — daily EOD push (once per day at WebhookEodHour:Min)
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // PL.1 — persist rail state BEFORE other deinits so a crash here doesn't lose state.
   SaveRailState();

   // PL.4 — log deinit event + close CSV.
   TelemetryDeinit(reason);

   // S2.C.9 — close regime trace CSV.
   RegimeTrace_Deinit();

   // Stop the heartbeat timer if we set one.
   if(!MQLInfoInteger(MQL_TESTER))
      EventKillTimer();

   // Save current positions on EA stop/unload.
   SyncPositionsWithTerminal(true);
   SavePositionsToFile();

   // Save pyramid state.
   SyncPyramidWithTerminal();
   SavePyramidToFile();

   SlopeDeinit();
   RegimeDeinit();
   MMD_Deinit();
   CleanupDashboard();

   Print("MoneyDancer deinit, reason=", reason);
}

//+------------------------------------------------------------------+
//| Expert tick handler                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   // Periodic position-memory sync (every 5 seconds)
   if(TimeCurrent() - g_posLastSync >= 5)
      SyncPositionsWithTerminal(true);

   // Periodic pyramid sync + management.
   if(TimeCurrent() - g_pyrLastSync >= 5)
      SyncPyramidWithTerminal();
   PyramidManage();

   // Tick-rate ring (feeds SECOND/WINDOW mode switching in DetectAndHandleSignal).
   TickratePush(TimeCurrent());

   // Slope cache refresh on new bar (cheap no-op otherwise).
   UpdateSlopeCacheIfNewBar();

   // S3.2a — MMD per-bar cross evaluation (no-op when UseMMDClassifier=false).
   MMD_OnNewBarIfAny();

   // S1.4 + S2.0 — sample spread for spike guard (cheap, runs always).
   Guards_OnTick();

   // Daily risk layer (may CloseAll + pause).
   ApplyDailyRiskControls();

   // S1.0 — per-basket equity SL. Runs BEFORE Scenario E so a SL'd
   // basket has nothing left for E to promote to runners.
   EnforceBasketSL();

   // S1.3 — intraday daily-loss kill (separate from S1.6 all-time).
   EnforceDailyLossKill();

   // S1.6 — all-time peak-to-trough DD kill.
   EnforceAllTimeDD();

   // S1.7 — Friday end-of-week flatten.
   EnforceFridayFlatten();

   // S2.C.8 — Daily pre-close flatten (XAU daily-break safety).
   EnforceDailyPreClose();

   // Scenario E bookkeeping + siphon-on-close.
   UpdateScenarioEState();
   ScenarioE_ScanNewRunnerClosures();

   // Skip new trade logic if paused or operator hit STOP on dashboard.
   if(!IsAutoPaused() && !g_eaStopped)
   {
      if(ScenarioE && HasAnyRunnersOpen())
         ManageRunnersTrailing();

      DetectAndHandleSignal();
   }

   // Dashboard refresh (draws, stats, button polling, marker cleanup).
   Dashboard_OnTick();
}

//+------------------------------------------------------------------+
//| Chart event handler                                               |
//|                                                                   |
//| CR-I6: Dashboard buttons (STOP/START, CloseAll, etc.) ARE         |
//| implemented in Dashboard.mqh, but their dispatch uses a 1-sec     |
//| polling loop in CheckButtonClicks() rather than CHARTEVENT_OBJECT_|
//| CLICK dispatch. Keeping this handler empty is acceptable — the    |
//| polling works. If sub-second button responsiveness becomes        |
//| desired, wire CHARTEVENT_OBJECT_CLICK here to call DispatchButton.|
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
}

//+------------------------------------------------------------------+
//| Custom tester criterion                                           |
//|                                                                   |
//| CR-M6: returns 0.0 to let MT5 use its built-in optimizer metric. |
//| If we ever do parameter sweeps where custom scoring matters (e.g.,|
//| weight UPI > raw profit), implement here. For now, optimizer-     |
//| based work isn't on the roadmap (backtest iteration exhausted     |
//| 2026-05-23 — see docs/HISTORY.md).                                |
//+------------------------------------------------------------------+
double OnTester()
{
   return(0.0);
}
//+------------------------------------------------------------------+
