//+------------------------------------------------------------------+
//|                                                      MoneyDancer |
//|                                                             JoJo |
//+------------------------------------------------------------------+
//| Bare MT4→MT5 port (A1-A5 end state). Frozen reference — active   |
//| development with MMD, telemetry, prop-compliance SL, etc. lives   |
//| in the sibling CashCabaret repo.                                  |
//+------------------------------------------------------------------+
#property copyright "JoJo"
#property version   "1.0"
#property strict

#include <Trade\Trade.mqh>

// Include order matters — downstream modules reference upstream symbols.
// Dependencies: Inputs → Globals → Utils → Persistence → Orders → Slope
//   → Pyramid → Series → Basket → ScenarioD → Risk → ScenarioE
//   → Dashboard → Telemetry → Signal
// Telemetry + Dashboard are empty stubs in the bare port.
#include "Include/Inputs.mqh"
#include "Include/Globals.mqh"
#include "Include/Utils.mqh"
#include "Include/Persistence.mqh"
#include "Include/Orders.mqh"
#include "Include/Slope.mqh"
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
   Print("MoneyDancer v1.0 init — Phase A5 (bare port)");

   // Configure CTrade (magic, slippage, filling mode).
   OrdersInit();

   // Create MA handles for slope cache + pyramid slope.
   if(!SlopeInit()) return(INIT_FAILED);

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
