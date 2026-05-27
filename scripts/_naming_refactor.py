"""3.0 naming refactor — applies the input + global renames across mt5/2.0/MoneyDancer_2.0/.

Run with:  python scripts/_naming_refactor.py
Then:      git diff --stat   (verify ~22 files touched)
           git diff           (review changes by hand)

The renames are word-boundary-safe (re.sub with \\b around each identifier)
so substrings inside longer identifiers won't get touched.

After this script + compile + backtest-verify, the new XAUUSD_2.0_STEP_ship.set
must be regenerated with the new input names (input names in .set file are
the renamed ones).
"""
from __future__ import annotations
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TARGET_DIR = ROOT / "mt5" / "2.0" / "MoneyDancer_2.0"

# ----- INPUT RENAMES (camelCase + underscore_legacy → PascalCase) -----
INPUT_RENAMES = {
    # camelCase legacy
    "maPeriod":            "MAPeriod",
    "slopeLookbackBars":   "SlopeLookbackBars",
    "slopeThresholdPts":   "SlopeThresholdPts",
    "strongTrendPts":      "StrongTrendPts",
    "startBe":             "StartBE",
    "lotMultiplier":       "LotMultiplier",
    "lotMultiplierRange":  "LotMultiplierRange",
    "bePoints":            "BEPoints",
    "maxLot":              "MaxLot",

    # PascalCase_underscore legacy — day-of-week trading windows (40 inputs)
    "MonStart1_Hour":   "MonStart1Hour",
    "MonStart1_Minute": "MonStart1Minute",
    "MonEnd1_Hour":     "MonEnd1Hour",
    "MonEnd1_Minute":   "MonEnd1Minute",
    "MonStart2_Hour":   "MonStart2Hour",
    "MonStart2_Minute": "MonStart2Minute",
    "MonEnd2_Hour":     "MonEnd2Hour",
    "MonEnd2_Minute":   "MonEnd2Minute",
    "TueStart1_Hour":   "TueStart1Hour",
    "TueStart1_Minute": "TueStart1Minute",
    "TueEnd1_Hour":     "TueEnd1Hour",
    "TueEnd1_Minute":   "TueEnd1Minute",
    "TueStart2_Hour":   "TueStart2Hour",
    "TueStart2_Minute": "TueStart2Minute",
    "TueEnd2_Hour":     "TueEnd2Hour",
    "TueEnd2_Minute":   "TueEnd2Minute",
    "WedStart1_Hour":   "WedStart1Hour",
    "WedStart1_Minute": "WedStart1Minute",
    "WedEnd1_Hour":     "WedEnd1Hour",
    "WedEnd1_Minute":   "WedEnd1Minute",
    "WedStart2_Hour":   "WedStart2Hour",
    "WedStart2_Minute": "WedStart2Minute",
    "WedEnd2_Hour":     "WedEnd2Hour",
    "WedEnd2_Minute":   "WedEnd2Minute",
    "ThuStart1_Hour":   "ThuStart1Hour",
    "ThuStart1_Minute": "ThuStart1Minute",
    "ThuEnd1_Hour":     "ThuEnd1Hour",
    "ThuEnd1_Minute":   "ThuEnd1Minute",
    "ThuStart2_Hour":   "ThuStart2Hour",
    "ThuStart2_Minute": "ThuStart2Minute",
    "ThuEnd2_Hour":     "ThuEnd2Hour",
    "ThuEnd2_Minute":   "ThuEnd2Minute",
    "FriStart1_Hour":   "FriStart1Hour",
    "FriStart1_Minute": "FriStart1Minute",
    "FriEnd1_Hour":     "FriEnd1Hour",
    "FriEnd1_Minute":   "FriEnd1Minute",
    "FriStart2_Hour":   "FriStart2Hour",
    "FriStart2_Minute": "FriStart2Minute",
    "FriEnd2_Hour":     "FriEnd2Hour",
    "FriEnd2_Minute":   "FriEnd2Minute",

    # _Points / _Pct / _StartPts
    "TP_Points":         "TPPoints",
    "SL_Points":         "SLPoints",
    "MaxBasketDD_Pct":   "MaxBasketDDPct",
    "MaxEquityDD_Pct":   "MaxEquityDDPct",
    "RunnerBE_StartPts": "RunnerBEStartPts",

    # MMD cloud period inputs
    "MMDPeriod_Red":     "MMDPeriodRed",
    "MMDPeriod_Orange":  "MMDPeriodOrange",
    "MMDPeriod_LBlue":   "MMDPeriodLBlue",
    "MMDPeriod_Blue":    "MMDPeriodBlue",
    "MMDPeriod_LGreen":  "MMDPeriodLGreen",
    "MMDPeriod_Green":   "MMDPeriodGreen",
    "MMDPeriod_Purple":  "MMDPeriodPurple",
}

# ----- GLOBAL RENAMES (snake_case → camelCase) -----
GLOBAL_RENAMES = {
    # Globals.mqh
    "g_ma_handle_main":         "g_maHandleMain",
    "g_ma_handle_pyram":        "g_maHandlePyram",
    "g_mmd_hSMA":               "g_mmdHandlesSMA",
    "g_mmd_hEMA":               "g_mmdHandlesEMA",
    "g_mmd_periods":            "g_mmdPeriods",
    "g_mmd_lastCrossBarTime":   "g_mmdLastCrossBarTime",
    "g_mmd_lastCrossSign":      "g_mmdLastCrossSign",
    "g_mmd_lastBarProcessed":   "g_mmdLastBarProcessed",

    # Guards.mqh
    "g_spread_t":         "g_spreadT",
    "g_spread_pts":       "g_spreadPts",
    "g_spread_n":         "g_spreadN",
    "g_spread_head":      "g_spreadHead",
    "g_hour_blocked":     "g_hourBlocked",
    "g_hour_block_parsed":"g_hourBlockParsed",

    # NewsCalendar.mqh
    "g_news_events":  "g_newsEvents",
    "g_news_count":   "g_newsCount",
    "g_news_cursor":  "g_newsCursor",
    "g_news_source":  "g_newsSource",

    # Risk.mqh
    "g_basketSLMarketClosedLogged_Buy":  "g_basketSLMarketClosedLoggedBuy",
    "g_basketSLMarketClosedLogged_Sell": "g_basketSLMarketClosedLoggedSell",

    # Telemetry.mqh
    "g_tele_file":   "g_teleFile",
    "g_tele_dayKey": "g_teleDayKey",
}

ALL_RENAMES = {**INPUT_RENAMES, **GLOBAL_RENAMES}

# Sort by length desc so longer names get renamed first (prevents
# "g_mmd" matching inside "g_mmd_hSMA" prematurely).
SORTED_RENAMES = sorted(ALL_RENAMES.items(), key=lambda kv: -len(kv[0]))


def rename_in_text(text: str) -> tuple[str, int]:
    """Apply all renames with word-boundary safety. Returns (new_text, change_count)."""
    total = 0
    for old, new in SORTED_RENAMES:
        # \b matches word boundary; works for [A-Za-z0-9_] identifiers
        pattern = re.compile(r"\b" + re.escape(old) + r"\b")
        new_text, n = pattern.subn(new, text)
        if n > 0:
            text = new_text
            total += n
    return text, total


def main():
    targets = list(TARGET_DIR.rglob("*.mq5")) + list(TARGET_DIR.rglob("*.mqh"))
    targets = [t for t in targets if "legacy" not in str(t).lower()]

    total_files = 0
    total_changes = 0
    for path in sorted(targets):
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            text = path.read_text(encoding="cp1250")
        new_text, n = rename_in_text(text)
        if n > 0:
            path.write_text(new_text, encoding="utf-8")
            print(f"  {path.relative_to(ROOT)}: {n} renames")
            total_files += 1
            total_changes += n

    print(f"\nTotal: {total_changes} renames across {total_files} files")
    print(f"Mapping: {len(INPUT_RENAMES)} inputs + {len(GLOBAL_RENAMES)} globals = {len(ALL_RENAMES)} unique names")


if __name__ == "__main__":
    main()
