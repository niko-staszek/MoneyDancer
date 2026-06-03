# scripts/opt_runner.py
"""Build + launch an MT5 genetic optimization for the gold smoothness detune.

SWEEP defines the 10 levers and their start/step/stop. build_opt_inputs() renders the
[TesterInputs] body: swept levers as `value||start||step||stop||Y`, everything else fixed.
main() writes the UTF-16 ini (Optimization=2 genetic, custom OnTester criterion) and launches
the terminal. Result parsing is opt_parse.py.
"""
import argparse, subprocess, sys, time
from pathlib import Path

# lever -> (start, step, stop).
# NOTE: names MUST match the current EA's camelCase inputs (v2.0+2 migrated from
# underscore -> camelCase: LotMultiplier/TPPoints/BEPoints/StartBE/MaxBasketDDPct).
# A mismatched key is silently ignored by MT5 (uses the default) — verified by the
# "params take effect" discriminator before any optimization is trusted.
SWEEP = {
    "LotMultiplier":       ("1.0", "0.5", "2.5"),  # capped: detune zone (4.0 = slow + the aggression we cut)
    "MaxOrdersDir":        ("10",  "10",  "50"),
    "MaxBasketLossPct":    ("2",   "2",   "8"),
    "StepPoints":          ("40",  "20",  "120"),
    "TPPoints":            ("30",  "10",  "80"),
    "BEPoints":            ("30",  "10",  "80"),
    "MinOrderDistancePts": ("20",  "20",  "80"),
    "MaxBasketDDPct":      ("20",  "10",  "60"),
    "StartBE":             ("1",   "1",   "5"),
    "MinMovePoints":       ("15",  "10",  "45"),
}

TERMINAL = Path(r"C:\Program Files\RoboForex MT5 Terminal\terminal64.exe")
DATA = Path(r"C:\Users\nikof\AppData\Roaming\MetaQuotes\Terminal\5FFA568149E88FCD5B44D926DCFEAA79")
PROFILE = DATA / "MQL5" / "Profiles" / "Tester"

def build_opt_inputs(fixed, active=None):
    """fixed: {input_name: value} for ALL inputs (from a parsed .set). Only levers in
    `active` (subset of SWEEP) get optimization ranges; the rest are fixed. active=None
    means sweep ALL SWEEP levers (whole-set behaviour)."""
    act = set(SWEEP) if active is None else set(active)
    lines = []
    for k, v in fixed.items():
        if k in SWEEP and k in act:
            start, step, stop = SWEEP[k]
            lines.append(f"{k}={v}||{start}||{step}||{stop}||Y")
        else:
            lines.append(f"{k}={v}")
    return "\r\n".join(lines) + "\r\n"

def build_opt_ini(fixed, symbol, frm, to, deposit, expert, report, active=None, opt_mode=1):
    head = [
        "; smoothness-detune optimization", "[Tester]",
        f"Expert={expert}", f"Symbol={symbol}", "Period=M5",
        f"Optimization={opt_mode}",  # 1 = full grid (small batches), 2 = genetic
        "Model=0",                   # every real tick (mandatory for this EA)
        f"FromDate={frm}", f"ToDate={to}", "ForwardMode=0",
        f"Deposit={deposit:g}", "Currency=USD", "Leverage=500", "ExecutionMode=40",
        "OptimizationCriterion=6",   # 6 = custom max (OnTester return)
        "Visual=0", f"Report={report}", "ReplaceReport=1", "ShutdownTerminal=1", "",
        "[TesterInputs]",
    ]
    return "\r\n".join(head) + "\r\n" + build_opt_inputs(fixed, active)

def parse_set(path):
    out = {}
    for raw in Path(path).read_text(encoding="utf-8", errors="ignore").splitlines():
        s = raw.strip()
        if not s or "=" not in s or "," in s.split("=")[0] or s.startswith(("Sep", "__", ";")):
            continue
        k, _, v = s.partition("=")
        if k in ("RequireAxiBroker", "LicenseExpireAt", "LicenseCode"):
            continue
        out[k] = v
    return out

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--set-file", required=True)
    ap.add_argument("--run-id", required=True)
    ap.add_argument("--symbol", default="XAUUSD.duk_robo_2025")
    ap.add_argument("--from-date", required=True)
    ap.add_argument("--to-date", required=True)
    ap.add_argument("--deposit", type=float, default=100000)
    ap.add_argument("--expert", default=r"MoneyDancer_2.0\MoneyDancer_2.0.ex5")
    ap.add_argument("--levers", nargs="+", default=None,
                    help="subset of SWEEP levers to optimize (default: all). e.g. --levers LotMultiplier MaxOrdersDir")
    ap.add_argument("--opt-mode", type=int, default=1, help="1=full grid (small batch), 2=genetic")
    ap.add_argument("--set-override", action="append", default=[],
                    help="KEY=VALUE fixed-input override (carry batch winners forward). Repeatable.")
    ap.add_argument("--timeout", type=int, default=86400)
    a = ap.parse_args()
    if a.levers:
        bad = [l for l in a.levers if l not in SWEEP]
        if bad:
            print(f"[OPT] ERROR: unknown levers {bad}; valid: {list(SWEEP)}"); return
    fixed = parse_set(a.set_file)
    for ov in a.set_override:
        if "=" in ov:
            k, v = ov.split("=", 1); fixed[k] = v
            print(f"[OPT] fixed override {k}={v}")
    report = f"{a.run_id}-opt"
    ini = build_opt_ini(fixed, a.symbol, a.from_date, a.to_date, a.deposit, a.expert, report,
                        active=a.levers, opt_mode=a.opt_mode)
    ini_path = PROFILE / f"{a.run_id}.ini"
    ini_path.write_text(ini, encoding="utf-16")
    print(f"[OPT] wrote {ini_path}; launching genetic optimization ...")
    t0 = time.time()
    rc = subprocess.run([str(TERMINAL), f"/config:{ini_path}"]).returncode
    print(f"[OPT] terminal rc={rc} after {time.time()-t0:.0f}s; report base = {report}")
    print(f"[OPT] optimization XML/cache under {DATA} (parse with opt_parse.py)")

if __name__ == "__main__":
    main()
