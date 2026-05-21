"""Summarize S2.C.8 sample results vs STEP baseline."""
import yaml
from pathlib import Path

# STEP baseline (from validated 17-month sweep + H2 OOS)
STEP_BASELINE = {
    "may25-H2":  (128.8, 40.48),   # from H2 OOS — the breach cell
    "dec25-H1":  (305.8, None),    # from H1 sweep
    "apr26-H1":  (258.4, None),
    "feb25-H1":  (-17.8, 37.79),   # STEP's only negative
    "mar25-H1":  ( 37.0, None),
    "jan26-H1":  ( 19.0, None),
}

# PRECLOSE round 1 (23:55 cutoff)
ROUND_1 = {}
for cell in ["may25-H2", "dec25-H1", "apr26-H1", "feb25-H1", "mar25-H1", "jan26-H1"]:
    p = Path(f"runs/PRECLOSE-5k-{cell}/result.yaml")
    if p.exists():
        d = yaml.safe_load(p.read_text())
        m = d["metrics"]
        ROUND_1[cell] = (m["net_profit"] / 5000 * 100, m["equity_dd_rel"], int(m["trades"]))

# PRECLOSE round 2 (22:00 cutoff)
ROUND_2 = {}
for cell in ["may25-H2", "dec25-H1", "apr26-H1", "feb25-H1", "mar25-H1", "jan26-H1"]:
    p = Path(f"runs/PRECLOSE22-5k-{cell}/result.yaml")
    if p.exists():
        d = yaml.safe_load(p.read_text())
        m = d["metrics"]
        ROUND_2[cell] = (m["net_profit"] / 5000 * 100, m["equity_dd_rel"], int(m["trades"]))

print(f"{'Cell':<12} {'STEP %':>10} {'R1 % (23:55)':>14} {'R1 DD%':>8} {'R1 trd':>8}  {'R2 % (22:00)':>14} {'R2 DD%':>8} {'R2 trd':>8}  {'delta R2-STEP':>14}")
for cell, (base_pct, base_dd) in STEP_BASELINE.items():
    r1 = ROUND_1.get(cell, (None, None, None))
    r2 = ROUND_2.get(cell, (None, None, None))
    r1_pct, r1_dd, r1_t = r1
    r2_pct, r2_dd, r2_t = r2
    delta = (r2_pct - base_pct) if (r2_pct is not None and base_pct is not None) else None
    print(f"{cell:<12} {base_pct:>+9.1f}% {r1_pct:>+13.1f}% {r1_dd:>7.1f}% {r1_t:>8}  {r2_pct:>+13.1f}% {r2_dd:>7.1f}% {r2_t:>8}  {delta:>+13.1f}pp")
