# #GOLD capital-35k set — investigation (set authored ~June 2025)

Set: "#GOLD capital-35k, h 1- 22, m15.set" (Downloads). Old underscore+single-session+license scheme.
Translated to 2.0 camelCase via scripts/translate_set.py -> gold35k_translated.set (108 params, 6 benign drops).
Native copy gold35k_native.set (MaxSpreadPts 15->45 so it trades on duka_robo ~25-28 spread).
Config: LotMultiplier=2.0, MaxOrdersDir=20, StepPoints=35, TPPoints=1550, BEPoints=250, fixed 0.01 lot,
MinOrderDistancePts=999, PyramRange=1, AfterThisHourClose 14:30 (profit>150 / floatloss<-30). No basket-SL.
MaxSpreadPts adjusted 15->45 (its 15 = raw-ECN broker; duka_robo spread 25-28 blocked all entries at 15).
All runs M15, 35k deposit, Model=0 every-tick.

## Headline (4-month 2026, Feb-May = year-forward OOS vs set's Jun-2025 origin)
- native 1.2:        +64.8%  DD 10.8%  2717 deals  (the set's NATIVE EA - cleanest)
- 2.0 translated:    +67.9%  DD 18.5%   760 deals  (translation validated - same ballpark)
- native 1.1:       -103.7%  DD 102.6% 1314 deals  maxlot 2.56 = ACCOUNT WIPED. Wrong EA version. NEVER 1.1.

## 2025 spot weeks (2.0 translated) - near-INACTIVE
mar25 14 deals -1.4% | jul25 18 deals +1.1% | nov25 20 deals +2.4% (sep25 glitch NO_REPORT).
~14-20 deals/2wk vs ~95/2wk in 2026. NOT spread-blocked (2025 spread 16-30 < cap 45). Set barely trades 2025.

## READ
- Translation faithful (1.2 native ~= 2.0 translated on 2026).
- This is a MoneyDancer 1.2 set; on 1.1 it blows up (version-specific).
- +65% is 2026-REGIME-SPECIFIC: lights up on 2026's big directional gold moves, near-idle in quieter 2025.
- BUT better than STEP: STEP LOST -17k/-16k on mar26/may26; this set made +65% there + sits flat (not bleeding) in 2025.
- NOT a generalizable everywhere-edge. Regime-selective grid. No 2024 data to test further.

## NEXT: full 2025 native-1.2 sweep (12 cells, scripts/sweep_2025_native.py) to confirm regime-selective vs 2026-luck.
