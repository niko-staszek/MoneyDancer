"""Compare S2.C.8 H2 OOS sweep (PRECLOSE_C6) vs STEP H2 baseline."""
import yaml
from pathlib import Path

# STEP H2 baseline from memory (16 cells, may26-H2 has no data)
# These are net% computed from runs/STEP-OOS-5k-*-H2/ result.yaml or memo
def step_h2_yaml(cell):
    # Try plain folder first, then v2 fallback for cells that needed re-runs
    for p in [Path(f"runs/STEP-OOS-5k-{cell}-H2/result.yaml"),
              Path(f"runs/STEP-OOS-5k-{cell}-H2v2/STEP-OOS-5k-{cell}-H2v2-report.result.yaml"),
              Path(f"runs/STEP-OOS-5k-{cell}-H2v2/result.yaml")]:
        if p.exists():
            return yaml.safe_load(p.read_text())["metrics"]
    return None

def step_h2_pct(cell):
    m = step_h2_yaml(cell)
    return m["net_profit"] / 5000 * 100 if m else None

def step_h2_dd(cell):
    m = step_h2_yaml(cell)
    return m["equity_dd_rel"] if m else None

cells = ["jan25", "feb25", "mar25", "apr25", "may25", "jun25", "jul25", "aug25",
         "sep25", "oct25", "nov25", "dec25", "jan26", "feb26", "mar26", "apr26"]

# may25-H2 sample was at PRECLOSE_C6-5k-may25-H2 (no -OOS prefix because it was the early test)
def pc_h2_yaml(cell):
    # First check PRECLOSE_C6-OOS-5k-cell-H2 (full sweep), else PRECLOSE_C6-5k-cell-H2 (sample)
    for path in [Path(f"runs/PRECLOSE_C6-OOS-5k-{cell}-H2/result.yaml"),
                 Path(f"runs/PRECLOSE_C6-5k-{cell}-H2/result.yaml")]:
        if path.exists():
            return yaml.safe_load(path.read_text())["metrics"]
    return None

print(f"{'Cell':<8} {'STEP %':>9} {'STEP DD':>8} {'PC %':>9} {'PC DD':>8} {'PC trd':>8} {'delta':>10}")

pc_total = 0.0
step_total = 0.0
pc_pos = 0
step_pos = 0
pc_worst_dd = 0.0
step_worst_dd = 0.0

for cell in cells:
    step_pct = step_h2_pct(cell)
    step_dd = step_h2_dd(cell)
    pc = pc_h2_yaml(cell)

    if step_pct is None:
        step_str = "?"; step_dd_str = "?"
    else:
        step_str = f"{step_pct:+.1f}%"
        step_dd_str = f"{step_dd:.1f}%"
        step_total += step_pct * 50
        if step_pct > 0: step_pos += 1
        if step_dd > step_worst_dd: step_worst_dd = step_dd

    if pc is None:
        pc_str = "MISSING"; pc_dd_str = ""; pc_trd_str = ""; delta_str = ""
    else:
        pc_pct = pc["net_profit"]/5000*100
        pc_dd = pc["equity_dd_rel"]
        pc_trd = int(pc["trades"])
        pc_str = f"{pc_pct:+.1f}%"
        pc_dd_str = f"{pc_dd:.1f}%"
        pc_trd_str = str(pc_trd)
        delta = pc_pct - step_pct if step_pct is not None else 0
        delta_str = f"{delta:+.1f}pp"
        pc_total += pc["net_profit"]
        if pc_pct > 0: pc_pos += 1
        if pc_dd > pc_worst_dd: pc_worst_dd = pc_dd

    print(f"{cell:<8} {step_str:>9} {step_dd_str:>8} {pc_str:>9} {pc_dd_str:>8} {pc_trd_str:>8} {delta_str:>10}")

print()
print(f"PRECLOSE H2 total: ${pc_total:.2f}  ({pc_pos} positive / 16)")
print(f"STEP H2 total:     ${step_total:.2f}  ({step_pos} positive / 16)")
print(f"Delta:             ${pc_total-step_total:+.2f}")
print(f"PRECLOSE H2 worst DD: {pc_worst_dd:.2f}%")
print(f"STEP H2 worst DD:     {step_worst_dd:.2f}%")
