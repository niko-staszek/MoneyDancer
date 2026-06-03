# scripts/tests/test_opt_runner.py
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from opt_runner import build_opt_inputs, SWEEP

def test_swept_levers_present_with_ranges():
    fixed = {"LotMultiplier": "4.0", "MaxOrdersDir": "50", "TPPoints": "60", "Magic": "21010"}
    body = build_opt_inputs(fixed)
    # a swept lever -> value||start||step||stop||Y (camelCase; LotMultiplier capped at 2.5)
    assert "LotMultiplier=4.0||1.0||0.5||2.5||Y" in body
    assert "MaxOrdersDir=50||10||10||50||Y" in body
    # a non-swept input -> fixed (no ||, or ||...||N); Magic must NOT be optimized
    assert "Magic=21010" in body and "Magic=21010||" not in body

def test_all_ten_levers_swept():
    body = build_opt_inputs({k: "1" for k in SWEEP})
    assert sum(1 for line in body.splitlines() if line.endswith("||Y")) == len(SWEEP) == 10

def test_subset_levers_only():
    # active=subset -> only those levers get ranges; other SWEEP levers fixed
    fixed = {k: "1" for k in SWEEP}
    body = build_opt_inputs(fixed, active=["LotMultiplier", "MaxOrdersDir"])
    assert sum(1 for line in body.splitlines() if line.endswith("||Y")) == 2
    assert "LotMultiplier=1||1.0||0.5||2.5||Y" in body
    assert "StepPoints=1" in body and "StepPoints=1||" not in body  # not swept this batch
