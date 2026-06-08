# WT/scripts/tests/test_v3_namemap.py
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from v3_namemap import to_v3, build_map

def test_to_v3_cases():
    cases = {
        "lotMultiplier": "LotMultiplier", "maPeriod": "MaPeriod", "startBe": "StartBe",
        "TP_Points": "TpPoints", "SL_Points": "SlPoints", "bePoints": "BePoints",
        "slopeThresholdPts": "SlopeThresholdPts", "MonStart1_Hour": "MonStart1Hour",
        "MaxBasketDD_Pct": "MaxBasketDdPct", "MaxEquityDD_Pct": "MaxEquityDdPct",
        "MaxAllTimeDDPct": "MaxAllTimeDdPct", "RunnerBE_StartPts": "RunnerBeStartPts",
        "PyramBEBufPts": "PyramBeBufPts", "RegimeAdxThresh": "RegimeAdxThresh",
        "StepPoints": "StepPoints", "MaxOrdersDir": "MaxOrdersDir", "Magic": "Magic",
        "ShowProDashboard": "ShowProDashboard",
    }
    for old, new in cases.items():
        assert to_v3(old) == new, f"{old} -> {to_v3(old)} (want {new})"

def test_build_map_no_collisions(tmp_path):
    mqh = tmp_path / "Inputs.mqh"
    mqh.write_text(
        "input double lotMultiplier = 1.5;\n"
        "input int TP_Points = 60;\n"
        "input int MonStart1_Hour = 3;\n"
        "input int StepPoints = 35;\n")
    m = build_map(mqh)
    assert m == {"lotMultiplier": "LotMultiplier", "TP_Points": "TpPoints",
                 "MonStart1_Hour": "MonStart1Hour", "StepPoints": "StepPoints"}
    assert len(set(m.values())) == len(m)
