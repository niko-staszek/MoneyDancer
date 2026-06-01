# scripts/detune_metrics.py
"""Smoothness metrics for the gold detune, from a tester trades.csv DataFrame.

ulcer_index(balance) - RMS of percentage drawdowns over the equity/balance curve.
max_dd_pct(balance)  - deepest peak-to-trough drawdown, percent.
daily_avg_pct(trades, deposit) - net out-deal profit / deposit / #UTC days, percent.
losing_basket_count(trades)    - # baskets (series id) whose net out-deal profit < 0.
cross_cell_consistency(cell_returns) - #negative cells + std of per-cell returns.
"""
import numpy as np
import pandas as pd

def ulcer_index(balance):
    b = np.asarray(balance, float)
    if len(b) == 0:
        return 0.0
    peak = np.maximum.accumulate(b)
    dd = np.where(peak > 0, (peak - b) / peak * 100.0, 0.0)
    return float(np.sqrt(np.mean(dd * dd)))

def max_dd_pct(balance):
    b = np.asarray(balance, float)
    if len(b) == 0:
        return 0.0
    peak = np.maximum.accumulate(b)
    dd = np.where(peak > 0, (peak - b) / peak * 100.0, 0.0)
    return float(np.max(dd))

def _out(trades):
    d = trades
    return d[d["direction"] == "out"] if "direction" in d else d

def daily_avg_pct(trades, deposit):
    o = _out(trades)
    if len(o) == 0 or deposit <= 0:
        return 0.0
    days = pd.to_datetime(o["time"], format="%Y.%m.%d %H:%M:%S").dt.normalize().nunique()
    days = max(1, int(days))
    return float(o["profit"].sum() / deposit / days * 100.0)

def losing_basket_count(trades):
    o = _out(trades)
    if len(o) == 0 or "comment" not in o:
        return 0
    by = o.groupby(o["comment"].astype(str))["profit"].sum()
    return int((by < 0).sum())

def cross_cell_consistency(cell_returns):
    r = np.asarray([x for x in cell_returns if x is not None], float)
    return {"n_negative": int((r < 0).sum()),
            "ret_std": float(np.std(r, ddof=1)) if len(r) > 1 else 0.0,
            "n_cells": int(len(r))}
