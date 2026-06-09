//+------------------------------------------------------------------+
//|                                                MoneyDancer 1.3   |
//|                                                             JoJo |
//+------------------------------------------------------------------+
//| 1.2 = 1.1 + initial Sprint 1 critical-path rails (all default OFF |
//| so a 1.1 .set produces identical behavior):                       |
//|                                                                   |
//|   S1.0 Per-basket equity SL (with close-failure escalation +     |
//|        rails-during-pause bugfixes from 2026-05-17).             |
//|   S1.6 All-time peak-to-trough DD trailing kill.                 |
//|   S3.2 ADX regime gate (HARD blocks grid entries when ADX high). |
//|                                                                   |
//| For the full Sprint 1 + Sprint 2 entry (news filter, spread       |
//| spike, Friday flatten, hour-block, MMD, auto-LotsBase, etc.),    |
//| see 2.0. 1.x continues as a parallel lineage for other features. |
//+------------------------------------------------------------------+
#property copyright "JoJo"
#property version   "1.3"
#property strict

#include <Trade\Trade.mqh>

// Include order matters — downstream modules reference upstream symbols.
// Dependencies: Inputs → Globals → Utils → Persistence → Orders → Slope →
//   Regime → Pyramid → Series → Basket → ScenarioD → Risk → ScenarioE →
//   Dashboard → Telemetry → Signal
#include "Include/Inputs.mqh"
#include "Include/Globals.mqh"
#include "Include/Utils.mqh"
#include "Include/Persistence.mqh"
#include "Include/Orders.mqh"
#include "Include/Slope.mqh"
#include "Include/Regime.mqh"
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
   Print("MoneyDancer 1.3 init — S1.0 + S1.6 + S3.2 rails (default OFF)");

   // Configure CTrade (magic, slippage, filling mode).
   OrdersInit();

   // Create MA handles for slope cache + pyramid slope.
   if(!SlopeInit()) return(INIT_FAILED);

   // S3.2 regime gate (lazy iADX init in GetCurrentADX).
   if(!RegimeInit()) return(INIT_FAILED);

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

   // S1.0 — per-basket equity SL (with close-failure escalation).
   EnforceBasketSL();

   // S1.6 — all-time peak-to-trough DD trailing kill.
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
//| Custom tester criterion (placeholder — Phase D)                   |
//+------------------------------------------------------------------+
double OnTester()
{
   return(0.0);
}
//+------------------------------------------------------------------+
