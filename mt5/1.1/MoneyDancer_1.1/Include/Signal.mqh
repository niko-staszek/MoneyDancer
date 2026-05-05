//+------------------------------------------------------------------+
//| Signal.mqh — tick-burst detection + cooldowns + order orchestrator|
//| Phase A5.6                                                       |
//|                                                                   |
//| Contains:                                                         |
//|   - Tick-rate ring + burst detectors (second + window modes)      |
//|   - Cooldown gates                                                |
//|   - SendOrder (pyramid/runner-aware order entry)                  |
//|   - HandleSignal (martingale / hedge / basic dispatcher)          |
//|   - DetectAndHandleSignal (top-level per-tick entry point)        |
//|                                                                   |
//| MT5 adaptations:                                                  |
//|   - Bid/Ask constants → SymbolInfoDouble(_Symbol, SYMBOL_BID/ASK) |
//|   - OrderSend() → CTrade via OpenPosition() (returns ulong ticket)|
//|   - IsTradeAllowed() → TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)|
//+------------------------------------------------------------------+
#ifndef __MD_SIGNAL_MQH__
#define __MD_SIGNAL_MQH__

//+------------------------------------------------------------------+
//| Tick rate ring                                                    |
//+------------------------------------------------------------------+
void TickratePush(datetime t)
{
   g_tickTimes[g_tickHead] = t;
   g_tickHead = (g_tickHead + 1) % MAX_TICK_TIMES;
   if(g_tickSize < MAX_TICK_TIMES) g_tickSize++;
}

double GetAvgTickRate()
{
   int look = TickRateLookbackSec;
   if(look < 1) look = 1;

   datetime now    = TimeCurrent();
   datetime cutoff = now - look;
   int cnt = 0;
   for(int i = 0; i < g_tickSize; i++)
   {
      int idx = g_tickHead - 1 - i;
      while(idx < 0) idx += MAX_TICK_TIMES;
      datetime tt = g_tickTimes[idx];
      if(tt < cutoff) break;
      cnt++;
   }
   return (double)cnt / (double)look;
}

//+------------------------------------------------------------------+
//| Per-second burst detector (SECOND mode)                           |
//+------------------------------------------------------------------+
void AddTickToSecond(double bid)
{
   double lvl = RoundToStep(bid, PriceStep);
   for(int i = 0; i < g_levelsN; i++)
   {
      if(g_levels[i] == lvl) { g_counts[i]++; return; }
   }
   if(g_levelsN < MAX_LEVELS_PER_SEC)
   {
      g_levels[g_levelsN] = lvl;
      g_counts[g_levelsN] = 1;
      g_levelsN++;
   }
}

void ResetSecond(datetime sec, double bid)
{
   g_sec      = sec;
   g_firstBid = bid;
   g_lastBid  = bid;
   g_levelsN  = 0;
   AddTickToSecond(bid);
}

bool EvaluateSecond(int &dirOut, int &peakTicksOut, int &movePtsOut)
{
   int bestIdx = -1, bestCnt = 0;
   for(int i = 0; i < g_levelsN; i++)
   {
      if(g_counts[i] > bestCnt) { bestCnt = g_counts[i]; bestIdx = i; }
   }
   if(bestIdx < 0) return false;

   double move    = g_lastBid - g_firstBid;
   int    movePts = (int)MathAbs(move / _Point);

   if(bestCnt < BurstTicks)    return false;
   if(movePts < MinMovePoints) return false;

   dirOut       = (move > 0 ? +1 : -1);
   peakTicksOut = bestCnt;
   movePtsOut   = movePts;
   return true;
}

//+------------------------------------------------------------------+
//| Rolling tick-window fallback (WINDOW mode)                        |
//+------------------------------------------------------------------+
void PushTickWindow(double bid)
{
   int N = TickWindowTicks;
   if(N < 5)   N = 5;
   if(N > 200) N = 200;

   double lvl = RoundToStep(bid, PriceStep);

   if(g_winCount >= N)
   {
      for(int i = 1; i < g_winCount; i++)
      {
         g_winBids[i - 1] = g_winBids[i];
         g_winLvls[i - 1] = g_winLvls[i];
      }
      g_winCount--;
   }

   g_winBids[g_winCount] = bid;
   g_winLvls[g_winCount] = lvl;
   g_winCount++;
}

bool EvaluateTickWindow(int &dirOut, int &peakTicksOut, int &movePtsOut)
{
   int N = TickWindowTicks;
   if(N < 5)   N = 5;
   if(N > 200) N = 200;
   if(g_winCount < N) return false;

   int bestCnt = 0;
   for(int i = 0; i < g_winCount; i++)
   {
      int c = 1;
      for(int j = i + 1; j < g_winCount; j++)
         if(g_winLvls[j] == g_winLvls[i]) c++;
      if(c > bestCnt) bestCnt = c;
   }

   double move    = g_winBids[g_winCount - 1] - g_winBids[0];
   int    movePts = (int)MathAbs(move / _Point);

   if(bestCnt < BurstTicks)    return false;
   if(movePts < MinMovePoints) return false;

   dirOut       = (move > 0 ? +1 : -1);
   peakTicksOut = bestCnt;
   movePtsOut   = movePts;
   return true;
}

//+------------------------------------------------------------------+
//| Cooldown gates                                                    |
//+------------------------------------------------------------------+
bool CooldownOK()
{
   if(g_lastSignalTime == 0) return true;
   return (TimeCurrent() - g_lastSignalTime) >= CooldownSec;
}

bool ReEntryOK(int dir)
{
   datetime t = (dir > 0 ? g_lastBuyTime : g_lastSellTime);
   if(t == 0) return true;
   return (TimeCurrent() - t) >= CooldownSec;
}

//+------------------------------------------------------------------+
//| SendOrder — routing-aware entry. Delegates to OpenPosition() for |
//| the actual CTrade call, then bookkeeping (cooldown timestamps,   |
//| marker, pyramid registration).                                    |
//|                                                                   |
//| Returns true on successful open.                                  |
//+------------------------------------------------------------------+
bool SendOrder(int dir, double lots, bool useTP, int tpPoints, bool isRunner, string commentText)
{
   // Block new opens outside the allowed working hours.
   if(UseTradingHours && !InTradingSession(TimeCurrent())) return false;

   if(SpreadPoints() > MaxSpreadPts) return false;
   if(!(bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) return false;

   double price = (dir > 0)
                    ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                    : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Pyramid routing (doesn't change the signal — decides at open-time).
   bool wantPyr = false;
   if(!isRunner) wantPyr = PyramidWantsOrder(dir);

   // MT4 original: pyramid starts with SL=TP=0; non-pyramid sets SL only
   // if SL_Points>0 and TP only if caller requested it. Matches legacy
   // trade flow for A8 validation diffing.
   double sl = 0, tp = 0;
   if(!wantPyr)
   {
      if(SL_Points > 0)
         sl = (dir > 0 ? price - SL_Points * _Point : price + SL_Points * _Point);
      if(useTP && tpPoints > 0)
         tp = (dir > 0 ? price + tpPoints * _Point : price - tpPoints * _Point);
   }

   if(wantPyr)   lots = LotsBase;     // pyramid always uses basic lot
   if(lots <= 0) lots = LotsBase;
   lots = ClampLot(lots);

   string cmt = commentText;
   if(isRunner) cmt = RUNNER_TAG + "|" + cmt;

   ulong ticket = OpenPosition(dir, lots, sl, tp, cmt);
   if(ticket == 0) return false;

   // Bookkeeping.
   if(dir > 0) g_lastBuyTime = TimeCurrent(); else g_lastSellTime = TimeCurrent();
   g_lastSignalTime = TimeCurrent();

   MarkOrderOpen(ticket);

   if(wantPyr)
      PyramidOnNewPosition(ticket);

   return true;
}

//+------------------------------------------------------------------+
//| HandleSignal — main dispatcher. Routes to basic / martingale /   |
//| hedge based on current basket state, series, and guards.          |
//+------------------------------------------------------------------+
void HandleSignal(int signalDir)
{
   if(!InTradingSession(TimeCurrent())) return;
   if(!CooldownOK())                    return;
   if(!ReEntryOK(signalDir))            return;
   if(SpreadPoints() > MaxSpreadPts)    return;

   if(UseSlopeFilter)
   {
      int slopeDir = MarketSlopeSignalCached();
      if(slopeDir != 0 && signalDir != slopeDir) return;
   }

   EnsureSeriesActive(signalDir);
   string seriesCmt = SeriesKey(signalDir, CurrentSeriesId(signalDir));

   // Cap orders per series (includes runners).
   if(CountSeriesOrdersDir(signalDir, seriesCmt, true) >= MaxOrdersDir) return;

   int cntNoRunners = CountSeriesOrdersDir(signalDir, seriesCmt, false);

   // Fast path (before martingale kicks in).
   if(!ScenarioD || cntNoRunners < startBe)
   {
      if(!CheckMinDistanceFromExistingPositions(signalDir)) return;
      SendOrder(signalDir, LotsBase, true, TP_Points, false, seriesCmt);
      return;
   }

   // --- SCENARIO D path (martingale with filters) ---
   int basketDir = signalDir;

   // Should Scenario E activate (guard-triggered hedge)?
   string activationReason = "";
   bool shouldActivateE = CheckShouldActivateE(basketDir, activationReason);

   if(shouldActivateE)
   {
      g_scenarioStatus = "E";
      // Don't keep adding to the losing basket — open a runner instead.
      TryOpenRunner(basketDir, activationReason);
      return;
   }

   g_scenarioStatus = "D";

   // Step gate: require price to have drifted far enough from basket BE.
   if(!StepGateFromBasketBESeries(basketDir, seriesCmt)) return;

   // Min-distance from any existing same-direction position.
   if(!CheckMinDistanceFromExistingPositions(basketDir)) return;

   // Safety: don't add on favorable side of BE.
   if(IsPriceFavorableOrAtBE(basketDir, seriesCmt)) return;

   bool moveAway = IsMovingAwayFromBESeries(basketDir, seriesCmt);

   double lot  = 0.0;
   string cmtD = "";

   if(moveAway)
   {
      // Multiplied lots ONLY when price is expanding away from BE.
      int    dStepNext = CountSeriesDAdds(basketDir, seriesCmt) + 1;
      double firstLot  = FirstBasketLotSeries(basketDir, seriesCmt);
      double lotRaw    = firstLot * MathPow(lotMultiplier, dStepNext);
      lot = ClampLot(lotRaw);
      cmtD = seriesCmt + "|D=" + IntegerToString(dStepNext);
   }
   else
   {
      // Price is recovering toward BE — stick with basic lot.
      lot  = ClampLot(LotsBase);
      cmtD = seriesCmt + "|DB";
   }

   bool opened = SendOrder(basketDir, lot, false, 0, false, cmtD);
   if(opened) ApplyBasketTPSeries(basketDir, seriesCmt);
}

//+------------------------------------------------------------------+
//| DetectAndHandleSignal — top-level per-tick entry. Chooses SECOND |
//| vs WINDOW mode based on current tick rate.                        |
//+------------------------------------------------------------------+
void DetectAndHandleSignal()
{
   int dir = 0, peak = 0, movePts = 0;
   bool signal = false;

   double tickRate = GetAvgTickRate();
   bool useWindow  = (UseTickWindowFallback && tickRate < TickRateThreshold);

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(useWindow)
   {
      g_lastMode = "WINDOW";
      PushTickWindow(bid);
      signal = EvaluateTickWindow(dir, peak, movePts);
   }
   else
   {
      g_lastMode = "SECOND";
      datetime secNow = TimeCurrent();

      if(g_sec == 0)
      {
         ResetSecond(secNow, bid);
         return;
      }

      if(secNow == g_sec)
      {
         g_lastBid = bid;
         AddTickToSecond(bid);
         return;
      }

      signal = EvaluateSecond(dir, peak, movePts);
      ResetSecond(secNow, bid);
   }

   if(!signal) return;

   g_lastSigDir  = dir;
   g_lastPeak    = peak;
   g_lastMovePts = movePts;

   HandleSignal(dir);
}

#endif // __MD_SIGNAL_MQH__
