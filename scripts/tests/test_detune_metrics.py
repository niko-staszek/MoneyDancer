# scripts/tests/test_detune_metrics.py
import sys, pathlib
import numpy as np, pandas as pd
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from detune_metrics import ulcer_index, max_dd_pct, daily_avg_pct, losing_basket_count, cross_cell_consistency

def test_ulcer_zero_on_monotonic():
    bal = pd.Series([100.0, 101, 102, 103])     # never draws down
    assert ulcer_index(bal) == 0.0

def test_ulcer_positive_on_dip():
    bal = pd.Series([100.0, 90, 100, 100])       # one 10% dip
    u = ulcer_index(bal)
    assert 4.0 < u < 6.0                          # rms of {0,10,0,0}% ~= 5.0

def test_max_dd_pct():
    bal = pd.Series([100.0, 80, 120])            # trough 80 from peak 100 = 20%
    assert abs(max_dd_pct(bal) - 20.0) < 1e-9

def test_daily_avg_pct():
    # two UTC days, out-deals; deposit 100k; net +3000 over 2 days = 1.5%/day on 100k
    df = pd.DataFrame({
        "time": ["2025.01.02 10:00:00", "2025.01.03 10:00:00"],
        "direction": ["out", "out"], "profit": [1000.0, 2000.0]})
    assert abs(daily_avg_pct(df, deposit=100000.0) - 1.5) < 1e-9

def test_losing_basket_count():
    # series A nets +5 (win), series B nets -3 (loss) -> 1 losing basket
    df = pd.DataFrame({
        "direction": ["out","out","out"], "profit": [5.0, -1.0, -2.0],
        "comment": ["TBb1","TBs2","TBs2"]})
    assert losing_basket_count(df) == 1

def test_cross_cell_consistency():
    # per-cell daily-avg returns; 1 negative cell, std computed
    r = cross_cell_consistency([2.0, 1.5, -0.5, 2.0])
    assert r["n_negative"] == 1
    assert abs(r["ret_std"] - np.std([2.0,1.5,-0.5,2.0], ddof=1)) < 1e-9
