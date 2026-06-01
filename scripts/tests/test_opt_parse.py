# scripts/tests/test_opt_parse.py
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from opt_parse import top_configs

def test_top_configs_ranks_by_result():
    rows = [
        {"lotMultiplier": "4.0", "MaxOrdersDir": "50", "Result": "0.5"},
        {"lotMultiplier": "2.0", "MaxOrdersDir": "20", "Result": "3.1"},
        {"lotMultiplier": "1.5", "MaxOrdersDir": "10", "Result": "2.4"},
    ]
    top = top_configs(rows, n=2)
    assert len(top) == 2
    assert top[0]["lotMultiplier"] == "2.0"        # highest Result first
    assert "Result" not in top[0]                   # finalists are param-only dicts
    assert top[1]["lotMultiplier"] == "1.5"
