//+------------------------------------------------------------------+
//| SymbolSpec.mqh — PL.3 symbol spec verification (cent + standard)  |
//|                                                                   |
//| Verifies broker symbol specs at OnInit() so the EA refuses to     |
//| trade if XAUUSD spec is outside expected ranges. Targets the      |
//| cent-account-vs-standard ambiguity: cent brokers sometimes report |
//| different contract sizes, lot steps, or tick values that would    |
//| make our LotsBasePerThousand-based sizing wildly wrong on real    |
//| money.                                                            |
//|                                                                   |
//| Behavior:                                                          |
//|   - ALWAYS logs every spec field at OnInit (for forensic audit).  |
//|   - HARD ASSERTS (return false → INIT_FAILED) only on:            |
//|       * contract_size out of [10, 1000] (XAU is typically 100)    |
//|       * volume_min  out of (0, 1] (broker accepts at least 1 lot)|
//|       * volume_step out of (0, 1] (step is reasonable fraction)  |
//|       * digits      out of {2, 3} (XAU is 2 or 3-digit)          |
//|   - WARNS only on:                                                 |
//|       * tick_value, swap, stop level — varies by broker; info     |
//|                                                                   |
//| Returns true if specs are tradeable; false to abort OnInit.       |
//+------------------------------------------------------------------+
#ifndef __MD_SYMBOLSPEC_MQH__
#define __MD_SYMBOLSPEC_MQH__

bool VerifySymbolSpec()
{
   string sym = _Symbol;

   // Read all relevant spec fields
   int    digits      = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   double point       = SymbolInfoDouble(sym, SYMBOL_POINT);
   double tickSize    = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   double tickValue   = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
   double contractSize= SymbolInfoDouble(sym, SYMBOL_TRADE_CONTRACT_SIZE);
   double volMin      = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   double volMax      = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);
   double volStep     = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
   int    calcMode    = (int)SymbolInfoInteger(sym, SYMBOL_TRADE_CALC_MODE);
   int    stopsLevel  = (int)SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL);
   int    freezeLevel = (int)SymbolInfoInteger(sym, SYMBOL_TRADE_FREEZE_LEVEL);
   double swapLong    = SymbolInfoDouble(sym, SYMBOL_SWAP_LONG);
   double swapShort   = SymbolInfoDouble(sym, SYMBOL_SWAP_SHORT);
   int    spread      = (int)SymbolInfoInteger(sym, SYMBOL_SPREAD);
   long   tradeMode   = SymbolInfoInteger(sym, SYMBOL_TRADE_MODE);

   // Log everything (always, for forensic audit + cent-vs-standard comparison)
   PrintFormat("[PL.3] === Symbol Spec for %s ===", sym);
   PrintFormat("[PL.3]   digits=%d  point=%.5f  tick_size=%.5f  tick_value=%.5f",
               digits, point, tickSize, tickValue);
   PrintFormat("[PL.3]   contract_size=%.2f  vol_min=%.2f  vol_max=%.2f  vol_step=%.2f",
               contractSize, volMin, volMax, volStep);
   PrintFormat("[PL.3]   calc_mode=%d  stops_level=%d  freeze_level=%d  spread=%d",
               calcMode, stopsLevel, freezeLevel, spread);
   PrintFormat("[PL.3]   swap_long=%.4f  swap_short=%.4f  trade_mode=%d",
               swapLong, swapShort, (int)tradeMode);

   // Hard asserts — refuse to trade if any of these fail
   bool ok = true;

   if(digits < 2 || digits > 3)
   {
      PrintFormat("[PL.3] CRITICAL: digits=%d outside expected {2,3} for XAU-style symbol — refusing to trade", digits);
      ok = false;
   }
   if(contractSize < 10.0 || contractSize > 1000.0)
   {
      PrintFormat("[PL.3] CRITICAL: contract_size=%.2f outside [10,1000] — XAU is typically 100 oz. Refusing.", contractSize);
      ok = false;
   }
   if(volMin <= 0.0 || volMin > 1.0)
   {
      PrintFormat("[PL.3] CRITICAL: vol_min=%.4f outside (0,1] — refusing", volMin);
      ok = false;
   }
   if(volStep <= 0.0 || volStep > 1.0)
   {
      PrintFormat("[PL.3] CRITICAL: vol_step=%.4f outside (0,1] — refusing", volStep);
      ok = false;
   }
   if(tickValue <= 0.0)
   {
      PrintFormat("[PL.3] CRITICAL: tick_value=%.4f <= 0 — lot sizing would be wrong. Refusing.", tickValue);
      ok = false;
   }
   if(tradeMode == SYMBOL_TRADE_MODE_DISABLED)
   {
      PrintFormat("[PL.3] CRITICAL: SYMBOL_TRADE_MODE=DISABLED — symbol not tradeable. Refusing.");
      ok = false;
   }

   // Soft warnings — info only
   if(stopsLevel > 100)
      PrintFormat("[PL.3] WARN: stops_level=%d > 100 — broker requires stops far from price (may interact with BEPoints/TPPoints=60/65)", stopsLevel);
   if(MathAbs(swapLong) > 100.0 || MathAbs(swapShort) > 100.0)
      PrintFormat("[PL.3] WARN: swap is unusually large (long=%.2f short=%.2f) — multi-day baskets will accumulate cost", swapLong, swapShort);

   // Lot-sanity cross-check: at $5k equity with LotsBasePerThousand=0.002, computed base lot = 0.01
   // Verify this lot is valid given step + min
   double exampleEquity = 5000.0;
   double exampleBaseLot = (exampleEquity / 1000.0) * 0.002;  // = 0.01
   double rounded = MathRound(exampleBaseLot / volStep) * volStep;
   if(rounded < volMin)
      PrintFormat("[PL.3] WARN: at $5k equity our base lot %.4f rounds to %.4f which is below vol_min %.4f — would fail at small equity",
                  exampleBaseLot, rounded, volMin);

   if(ok)
      PrintFormat("[PL.3] OK: symbol spec passes critical assertions");
   else
      PrintFormat("[PL.3] FAIL: symbol spec failed critical assertions — EA will refuse to init");

   return ok;
}

#endif // __MD_SYMBOLSPEC_MQH__
