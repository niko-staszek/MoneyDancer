"""Compare S2.C.8 round 5 (cond@6%) vs prior rounds."""
import yaml
from pathlib import Path

STEP = {"may25-H2": 128.8, "dec25-H1": 305.8, "apr26-H1": 258.4, "feb25-H1": -17.8}

print(f"{'Cell':<11} {'STEP':>7} {'R2 unc':>7} {'R3@1%':>7} {'R4@4%':>7} {'R5@6%':>7} {'R5 DD':>7} {'R5 trd':>7} {'R5-STEP':>9}")
for cell, base in STEP.items():
    rows = []
    for prefix in ["PRECLOSE22", "PRECLOSE_C1", "PRECLOSE_C4", "PRECLOSE_C6"]:
        p = Path(f"runs/{prefix}-5k-{cell}/result.yaml")
        rows.append(yaml.safe_load(p.read_text())["metrics"] if p.exists() else None)
    r2, r3, r4, r5 = rows
    r2p = r2["net_profit"]/5000*100 if r2 else 0
    r3p = r3["net_profit"]/5000*100 if r3 else 0
    r4p = r4["net_profit"]/5000*100 if r4 else 0
    r5p = r5["net_profit"]/5000*100 if r5 else 0
    r5dd = r5["equity_dd_rel"] if r5 else 0
    r5t = int(r5["trades"]) if r5 else 0
    print(f"{cell:<11} {base:>+6.1f}% {r2p:>+6.1f}% {r3p:>+6.1f}% {r4p:>+6.1f}% {r5p:>+6.1f}% {r5dd:>6.1f}% {r5t:>7} {(r5p-base):>+8.1f}pp")
