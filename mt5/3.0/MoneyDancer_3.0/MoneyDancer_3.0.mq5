//+------------------------------------------------------------------+
//|                                                MoneyDancer 3.0   |
//|                                                             JoJo |
//+------------------------------------------------------------------+
//| 1.2 = 1.1 + initial Sprint 1 critical-path rails (all default OFF |
//| so a 1.1 .set produces identical behavior):                       |
//|                                                                   |
//|   Per-basket equity SL (with close-failure escalation +     |
//|        rails-during-pause bugfixes from 2026-05-17).             |
//|   All-time peak-to-trough DD trailing kill.                 |
//|   ADX regime gate (HARD blocks grid entries when ADX high). |
//|                                                                   |
//| For the full Sprint 1 + Sprint 2 entry (news filter, spread       |
//| spike, Friday flatten, hour-block, MMD, auto-LotsBase, etc.),    |
//| see 2.0. 1.x continues as a parallel lineage for other features. |
//+------------------------------------------------------------------+
#property copyright "JoJo"
#property version   "1.2"
#property strict

#include <Trade\Trade.mqh>

// Include order matters â€” downstream modules reference upstream symbols.
// Dependencies: Inputs â†’ Globals â†’ Utils â†’ Persistence â†’ Orders â†’ Slope â†’
//   Regime â†’ Pyramid â†’ Series â†’ Basket â†’ ScenarioD â†’ Risk â†’ ScenarioE â†’
//   Dashboard â†’ Telemetry â†’ Signal
#include "Include/Inputs.mqh"
#include "Include/Globals.mqh"
#include "Include/Utils.mqh"
#include "Include/Persistence.mqh"
#include "Include/Orders.mqh"
#include "Include/Slope.mqh"
#include "Include/Regime.mqh"
#include "Include/AtrSpacing.mqh"
#include "Include/Pyramid.mqh"
#include "Include/Series.mqh"
#include "Include/Basket.mqh"
#include "Include/ScenarioD.mqh"
#include "Include/Risk.mqh"
#include "Include/ScenarioE.mqh"
#include "Include/Dashboard.mqh"
#include "Include/Telemetry.mqh"
#include "Include/Signal.mqh"

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("MoneyDancer 3.0 init â€” + + rails (default OFF)");

   // Configure CTrade (magic, slippage, filling mode).
   OrdersInit();

   // Create MA handles for slope cache + pyramid slope.
   if(!SlopeInit()) return(INIT_FAILED);

   // regime gate (lazy iADX init in GetCurrentADX).
   if(!RegimeInit()) return(INIT_FAILED);

   // v3.2 ATR-adaptive spacing handle (no-op when AtrSpacingMode==0).
   AtrSpacingInit();

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

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Save current positions on EA stop/unload.
   SyncPositionsWithTerminal(true);
   SavePositionsToFile();

   // Save pyramid state.
   SyncPyramidWithTerminal();
   SavePyramidToFile();

   SlopeDeinit();
   RegimeDeinit();
   AtrSpacingDeinit();
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

   // Daily risk layer (may CloseAll + pause).
   ApplyDailyRiskControls();

   // â€” per-basket equity SL (with close-failure escalation).
   EnforceBasketSL();

   // â€” all-time peak-to-trough DD trailing kill.
   EnforceAllTimeDD();

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
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   // Bare port: no dashboard buttons. Dashboard port is a later phase.
}

//+------------------------------------------------------------------+
//| Custom tester criterion (placeholder â€” Phase D)                   |
//+------------------------------------------------------------------+
double OnTester()
{
   return(0.0);
}
//+------------------------------------------------------------------+
