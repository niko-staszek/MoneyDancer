//+------------------------------------------------------------------+
//| Dashboard.mqh — UI layer (stubs only for A5 strategy compile)    |
//| Full port target: Phase A7 (alongside telemetry) or dedicated    |
//|                   later phase. Strategy logic has no functional  |
//|                   dependency on these; they're purely visual.     |
//+------------------------------------------------------------------+
#ifndef __MD_DASHBOARD_MQH__
#define __MD_DASHBOARD_MQH__

// Stub: marks a newly-opened position on the chart. Real implementation
// draws arrows/labels; the strategy doesn't care whether this actually
// does anything, so a no-op keeps A5 compiling without pulling in the
// full marker/drawing subsystem.
void MarkOrderOpen(ulong ticket)
{
   // No-op until dashboard/markers port — parameter intentionally unused.
}

// TODO Phase A7+: port from MT4 source:
//   DrawProDashboard, DrawBottomResultsPanel, CleanupDashboard,
//   DrawPanel, DrawLabel, CreateButton, CreateBottomLabel, DeleteObject,
//   DrawSmallArrow, DrawProfitLabel, DrawTradeLine,
//   MarkOrderCloseFromHistory, CollectClosedOrderForBasket,
//   DrawAggregatedBasketLabels, CleanupOldMarkers, RebuildLast24hMarkers,
//   CheckButtonClicks, UpdateAISimulation, UpdateAIMessages,
//   CalculateStatistics, ResetPnLDayIfNeeded, UpdateM15BucketForClosedOrder,
//   TodayPnL, ScanHistoryNewAndUpdatePnLAndMarkers (UI portion only —
//     siphon trigger already lives in ScenarioE_ScanNewRunnerClosures),
//   FinalizeSeriesIfEnded, SeriesProfitAndLastClose24h,
//   UpdateTickSize, GetAvgTickSize, UpdateMaxDD.

#endif // __MD_DASHBOARD_MQH__
