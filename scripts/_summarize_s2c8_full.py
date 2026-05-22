"""Compare S2.C.8 full 17-cell H1 sweep (cond@6%) vs STEP baseline."""
import yaml
from pathlib import Path

# STEP baseline H1 cells from project memory
STEP_H1 = {
    "jan25": 49.0,
    "feb25": -17.8,
    "mar25": 37.0,
    "apr25": 98.8,
    "may25": 79.7,
    "jun25": 36.8,
    "jul25": 59.4,
    "aug25": 25.1,
    "sep25": 70.5,
    "oct25": 100.9,
    "nov25": 64.0,
    "dec25": 305.8,
    "jan26": 19.0,
    "feb26": 160.5,
    "mar26": 212.1,
    "apr26": 258.4,
    "may26": 83.0,
}

print(f"{'Cell':<8} {'STEP %':>9} {'PRECLOSE %':>13} {'PC DD':>8} {'PC trd':>8} {'delta':>10}")

pc_total_dollars = 0.0
step_total_dollars = 0.0
worst_dd = 0.0
pos_count = 0
regression_count = 0

for cell, base in STEP_H1.items():
    p = Path(f"runs/PRECLOSE_C6-5k-{cell}/result.yaml")
    if not p.exists():
        print(f"{cell:<8} {base:>+8.1f}% {'MISSING':>12}")
        continue
    m = yaml.safe_load(p.read_text())["metrics"]
    pc_pct = m["net_profit"]/5000*100
    pc_dd = m["equity_dd_rel"]
    pc_trd = int(m["trades"])
    delta = pc_pct - base
    pc_total_dollars += m["net_profit"]
    step_total_dollars += base * 50  # base is %, 50 = 5000/100
    if pc_dd > worst_dd: worst_dd = pc_dd
    if pc_pct > 0: pos_count += 1
    if delta < -20: regression_count += 1
    print(f"{cell:<8} {base:>+8.1f}% {pc_pct:>+12.1f}% {pc_dd:>7.1f}% {pc_trd:>8} {delta:>+9.1f}pp")

print()
print(f"PRECLOSE total: ${pc_total_dollars:.2f}  STEP total: ${step_total_dollars:.2f}  delta: ${pc_total_dollars-step_total_dollars:+.2f}")
print(f"Positive cells: {pos_count}/17")
print(f"Worst DD: {worst_dd:.2f}%")
print(f"Regressions > 20pp: {regression_count}")
print()
print("Promotion gate check:")
print(f"  total >= $82,120 (STEP)? PRECLOSE=${pc_total_dollars:.0f} {'PASS' if pc_total_dollars >= 82120 else 'FAIL'}")
print(f"  >=16/17 positive? {pos_count}/17 {'PASS' if pos_count >= 16 else 'FAIL'}")
print(f"  max DD <= 37.8%? {worst_dd:.2f}% {'PASS' if worst_dd <= 37.8 else 'FAIL'}")
