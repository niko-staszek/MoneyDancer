"""Compare S2.C.8 round 3 (conditional) vs round 2 (unconditional) vs STEP baseline."""
import yaml
from pathlib import Path

STEP = {
    "may25-H2": (128.8, 40.48),
    "dec25-H1": (305.8, None),
    "apr26-H1": (258.4, None),
    "feb25-H1": (-17.8, 37.79),
    "mar25-H1": (37.0, None),
    "jan26-H1": (19.0, None),
}

print(f"{'Cell':<12} {'STEP %':>9} {'R2 uncond':>11} {'R3 cond&gt;=1%':>13} {'R3 DD%':>8} {'R3 trd':>7}  {'R3-STEP':>10}")

r3_sum_pct = 0.0
step_sum = 0.0
r3_worst_dd = 0.0
r3_breaches = 0
r3_big_regressions = 0  # > 30pp loss vs STEP

for cell, (base, _) in STEP.items():
    r2p = Path(f"runs/PRECLOSE22-5k-{cell}/result.yaml")
    r3p = Path(f"runs/PRECLOSE_C1-5k-{cell}/result.yaml")
    r2 = yaml.safe_load(r2p.read_text())["metrics"] if r2p.exists() else None
    r3 = yaml.safe_load(r3p.read_text())["metrics"] if r3p.exists() else None
    r2pct = r2["net_profit"]/5000*100 if r2 else None
    r3pct = r3["net_profit"]/5000*100 if r3 else None
    r3dd  = r3["equity_dd_rel"] if r3 else None
    r3trd = int(r3["trades"]) if r3 else None
    delta = r3pct - base if r3pct is not None else None
    if r3pct is not None:
        r3_sum_pct += r3pct
        step_sum += base
        if r3dd > r3_worst_dd: r3_worst_dd = r3dd
        if r3dd > 40: r3_breaches += 1
        if delta < -30: r3_big_regressions += 1
    print(f"{cell:<12} {base:>+8.1f}% {r2pct:>+10.1f}% {r3pct:>+12.1f}% {r3dd:>7.1f}% {r3trd:>7}  {delta:>+9.1f}pp")

print()
print(f"Sum %:           STEP={step_sum:+.1f}%  R3={r3_sum_pct:+.1f}%  delta={(r3_sum_pct-step_sum):+.1f}pp")
print(f"R3 worst DD:     {r3_worst_dd:.1f}%  (breaches 40%: {r3_breaches})")
print(f"R3 big regressions (>30pp drop): {r3_big_regressions}/6")
print()
print("Promotion gate check (for full 17-cell sweep):")
may25_dd = yaml.safe_load(Path("runs/PRECLOSE_C1-5k-may25-H2/result.yaml").read_text())["metrics"]["equity_dd_rel"]
print(f"  may25-H2 DD < 35%? {may25_dd:.1f}% {'PASS' if may25_dd < 35 else 'FAIL'}")
print(f"  >=4/6 cells no regression > 30pp? {6-r3_big_regressions}/6 {'PASS' if r3_big_regressions <= 2 else 'FAIL'}")
print(f"  No cell DD > 40%? {'PASS' if r3_breaches == 0 else 'FAIL'} (max={r3_worst_dd:.1f}%)")
