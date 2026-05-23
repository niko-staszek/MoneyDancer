"""S2.C.4 martingale-shape sample comparison vs STEP baseline."""
import yaml
from pathlib import Path

STEP_H1 = {
    "mar25": (37.0, 22.18),
    "jul25": (59.4, 18.2),
    "dec25": (305.8, 18.0),
    "apr26": (258.4, 12.2),
    "jan26": (19.0, 31.5),
}

def load(prefix, cell):
    p = Path(f"runs/{prefix}-5k-{cell}/result.yaml")
    if p.exists():
        return yaml.safe_load(p.read_text())["metrics"]
    return None

for variant_id, variant_name in [("A", "startBe=3 / MaxOrd=50"),
                                  ("B", "startBe=1 / MaxOrd=30"),
                                  ("C", "startBe=3 / MaxOrd=30")]:
    print(f"\n=== Variant {variant_id}: {variant_name} ===")
    print(f"{'Cell':<8} {'STEP %':>9} {'STEP DD':>8} {'PC %':>9} {'PC DD':>8} {'trd':>7} {'delta %':>9} {'delta DD':>10}")
    total_delta = 0.0
    improvements = 0
    regressions_30 = 0
    worst_dd = 0.0
    for cell, (base_pct, base_dd) in STEP_H1.items():
        m = load(f"MART_{variant_id}", cell)
        if m is None:
            print(f"{cell:<8} {base_pct:>+8.1f}% {base_dd:>7.1f}% {'MISSING':>9}")
            continue
        pct = m["net_profit"]/5000*100
        dd = m["equity_dd_rel"]
        trd = int(m["trades"])
        d_pct = pct - base_pct
        d_dd = dd - base_dd
        total_delta += d_pct
        if d_pct > 0: improvements += 1
        if d_pct < -30: regressions_30 += 1
        if dd > worst_dd: worst_dd = dd
        print(f"{cell:<8} {base_pct:>+8.1f}% {base_dd:>7.1f}% {pct:>+8.1f}% {dd:>7.1f}% {trd:>7} {d_pct:>+8.1f}pp {d_dd:>+9.1f}pp")
    print(f"Aggregate delta: {total_delta:+.1f}pp  Improvements: {improvements}/5  Regressions>30pp: {regressions_30}  Worst DD: {worst_dd:.1f}%")
    gate_pass = improvements >= 3 and regressions_30 == 0 and worst_dd <= 37.8
    print(f"Gate (>=3 improve, no -30pp, DD <= 37.8): {'PASS' if gate_pass else 'FAIL'}")
