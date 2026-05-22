"""Compare S2.C.8 round 4 (cond@4%) vs R2 uncond / R3 cond@1% / STEP."""
import yaml
from pathlib import Path

STEP = {"may25-H2": 128.8, "dec25-H1": 305.8, "apr26-H1": 258.4, "feb25-H1": -17.8}

print(f"{'Cell':<11} {'STEP':>8} {'R2 unc':>8} {'R3@1%':>8} {'R4@4%':>8} {'R4 DD':>7} {'R4 trd':>7} {'R4-STEP':>9}")
for cell, base in STEP.items():
    rows = []
    for prefix in ["PRECLOSE22", "PRECLOSE_C1", "PRECLOSE_C4"]:
        p = Path(f"runs/{prefix}-5k-{cell}/result.yaml")
        rows.append(yaml.safe_load(p.read_text())["metrics"] if p.exists() else None)
    r2, r3, r4 = rows
    r2p = r2["net_profit"]/5000*100 if r2 else 0
    r3p = r3["net_profit"]/5000*100 if r3 else 0
    r4p = r4["net_profit"]/5000*100 if r4 else 0
    r4dd = r4["equity_dd_rel"] if r4 else 0
    r4t = int(r4["trades"]) if r4 else 0
    print(f"{cell:<11} {base:>+7.1f}% {r2p:>+7.1f}% {r3p:>+7.1f}% {r4p:>+7.1f}% {r4dd:>6.1f}% {r4t:>7} {(r4p-base):>+8.1f}pp")
