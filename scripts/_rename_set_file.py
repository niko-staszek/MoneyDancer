"""Apply the same input renames to .set files (Phase 1 ship .set regeneration).

Run with: python scripts/_rename_set_file.py path/to/file.set [...more.set]
Writes back in place.
"""
from __future__ import annotations
import re
import sys
from pathlib import Path

# Same INPUT_RENAMES table as _naming_refactor.py (kept in sync manually).
INPUT_RENAMES = {
    "maPeriod": "MAPeriod", "slopeLookbackBars": "SlopeLookbackBars",
    "slopeThresholdPts": "SlopeThresholdPts", "strongTrendPts": "StrongTrendPts",
    "startBe": "StartBE", "lotMultiplier": "LotMultiplier",
    "lotMultiplierRange": "LotMultiplierRange", "bePoints": "BEPoints",
    "maxLot": "MaxLot",
    "MonStart1_Hour": "MonStart1Hour", "MonStart1_Minute": "MonStart1Minute",
    "MonEnd1_Hour": "MonEnd1Hour", "MonEnd1_Minute": "MonEnd1Minute",
    "MonStart2_Hour": "MonStart2Hour", "MonStart2_Minute": "MonStart2Minute",
    "MonEnd2_Hour": "MonEnd2Hour", "MonEnd2_Minute": "MonEnd2Minute",
    "TueStart1_Hour": "TueStart1Hour", "TueStart1_Minute": "TueStart1Minute",
    "TueEnd1_Hour": "TueEnd1Hour", "TueEnd1_Minute": "TueEnd1Minute",
    "TueStart2_Hour": "TueStart2Hour", "TueStart2_Minute": "TueStart2Minute",
    "TueEnd2_Hour": "TueEnd2Hour", "TueEnd2_Minute": "TueEnd2Minute",
    "WedStart1_Hour": "WedStart1Hour", "WedStart1_Minute": "WedStart1Minute",
    "WedEnd1_Hour": "WedEnd1Hour", "WedEnd1_Minute": "WedEnd1Minute",
    "WedStart2_Hour": "WedStart2Hour", "WedStart2_Minute": "WedStart2Minute",
    "WedEnd2_Hour": "WedEnd2Hour", "WedEnd2_Minute": "WedEnd2Minute",
    "ThuStart1_Hour": "ThuStart1Hour", "ThuStart1_Minute": "ThuStart1Minute",
    "ThuEnd1_Hour": "ThuEnd1Hour", "ThuEnd1_Minute": "ThuEnd1Minute",
    "ThuStart2_Hour": "ThuStart2Hour", "ThuStart2_Minute": "ThuStart2Minute",
    "ThuEnd2_Hour": "ThuEnd2Hour", "ThuEnd2_Minute": "ThuEnd2Minute",
    "FriStart1_Hour": "FriStart1Hour", "FriStart1_Minute": "FriStart1Minute",
    "FriEnd1_Hour": "FriEnd1Hour", "FriEnd1_Minute": "FriEnd1Minute",
    "FriStart2_Hour": "FriStart2Hour", "FriStart2_Minute": "FriStart2Minute",
    "FriEnd2_Hour": "FriEnd2Hour", "FriEnd2_Minute": "FriEnd2Minute",
    "TP_Points": "TPPoints", "SL_Points": "SLPoints",
    "MaxBasketDD_Pct": "MaxBasketDDPct", "MaxEquityDD_Pct": "MaxEquityDDPct",
    "RunnerBE_StartPts": "RunnerBEStartPts",
    "MMDPeriod_Red": "MMDPeriodRed", "MMDPeriod_Orange": "MMDPeriodOrange",
    "MMDPeriod_LBlue": "MMDPeriodLBlue", "MMDPeriod_Blue": "MMDPeriodBlue",
    "MMDPeriod_LGreen": "MMDPeriodLGreen", "MMDPeriod_Green": "MMDPeriodGreen",
    "MMDPeriod_Purple": "MMDPeriodPurple",
}

SORTED = sorted(INPUT_RENAMES.items(), key=lambda kv: -len(kv[0]))


def rename_set_text(text: str) -> tuple[str, int]:
    total = 0
    for old, new in SORTED:
        # In .set files an input name appears at start of line followed by =
        # Use word boundary to be safe.
        pattern = re.compile(r"\b" + re.escape(old) + r"\b")
        new_text, n = pattern.subn(new, text)
        if n > 0:
            text = new_text
            total += n
    return text, total


def main():
    for arg in sys.argv[1:]:
        p = Path(arg)
        text = p.read_text(encoding="utf-8", errors="replace")
        new_text, n = rename_set_text(text)
        p.write_text(new_text, encoding="utf-8")
        print(f"{p}: {n} renames")


if __name__ == "__main__":
    main()
