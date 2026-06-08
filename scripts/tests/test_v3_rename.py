# WT/scripts/tests/test_v3_rename.py
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from v3_rename import apply_map

def test_word_boundary_and_longest_first():
    m = {"MaxOrders": "MaxOrdersX", "MaxOrdersDir": "MaxOrdersDirX", "lotMultiplier": "LotMultiplier"}
    src = "input int MaxOrdersDir=50;\nx = MaxOrdersDir + lotMultiplier;\n// MaxOrders note\n"
    out = apply_map(src, m)
    assert "MaxOrdersDirX=50" in out and "MaxOrdersDirX + LotMultiplier" in out
    assert "// MaxOrdersX note" in out
    assert "MaxOrdersDirXX" not in out
