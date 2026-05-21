import subprocess, sys, yaml
from pathlib import Path
from statistics import mean, stdev

ROOT = Path(__file__).resolve().parent.parent

IS = [
    ("Jan", "S2.0a-5k-jan-2wk-rails-on", "2026.01.01", "2026.01.14", "XAUUSD.duk_robo"),
    ("Feb", "S2.0a-5k-feb-2wk-rails-on", "2026.02.01", "2026.02.14", "XAUUSD.duk_robo"),
    ("Mar", "S2.0a-5k-mar-2wk-rails-on", "2026.03.01", "2026.03.14", "XAUUSD.duk_robo"),
    ("Apr", "S2.0a-5k-apr-2wk-rails-on", "2026.04.01", "2026.04.14", "XAUUSD.duk_robo"),
    ("May", "S2.0a-5k-may-rails-on",     "2026.05.01", "2026.05.14", "XAUUSD.duk_robo"),
]
OOS = [
    ("Jan", "S2.0a-OOSv2-5k-jan25-2wk-rails-on", "2025.01.01", "2025.01.14", "XAUUSD.duk_robo_2025"),
    ("Feb", "S2.0a-OOSv2-5k-feb25-2wk-rails-on", "2025.02.01", "2025.02.14", "XAUUSD.duk_robo_2025"),
    ("Mar", "S2.0a-OOSv2-5k-mar25-2wk-rails-on", "2025.03.01", "2025.03.14", "XAUUSD.duk_robo_2025"),
    ("Apr", "S2.0a-OOSv2-5k-apr25-2wk-rails-on", "2025.04.01", "2025.04.14", "XAUUSD.duk_robo_2025"),
    ("May", "S2.0a-OOSv2-5k-may25-2wk-rails-on", "2025.05.01", "2025.05.14", "XAUUSD.duk_robo_2025"),
]


def parse(month, run_id, frm, to, symbol):
    report = ROOT / "runs" / run_id / f"{run_id}-report.htm"
    out    = ROOT / "runs" / run_id / "result.yaml"
    if not report.exists():
        return None
    subprocess.run([sys.executable, str(ROOT/"scripts"/"parse_mt5_report.py"),
                    "--report", str(report), "--run-id", run_id,
                    "--symbol", symbol, "--deposit", "5000",
                    "--from-date", frm, "--to-date", to, "--out", str(out)],
                   capture_output=True)
    with open(out) as f:
        d = yaml.safe_load(f)
    m = d["metrics"]
    win = m["profit_trades"] / m["trades"] * 100 if m["trades"] else 0
    return {"month": month, "net_pct": m["net_profit"]/5000*100,
            "pf": m["profit_factor"], "eq_dd": m["equity_dd_rel"],
            "trades": int(m["trades"]), "win_pct": win}


is_r = [parse(*r) for r in IS]
oos_r = [parse(*r) for r in OOS]

print("            IS 2026                          OOS 2025 (with fix)")
print("  Mo    Net%      PF   EqDD%  Trades  Win%      Net%      PF   EqDD%  Trades  Win%")
print("  " + "-"*88)
for a, b in zip(is_r, oos_r):
    print(f"  {a['month']:<3} {a['net_pct']:>+7.1f}%  {a['pf']:>5.2f}  {a['eq_dd']:>6.1f}%  {a['trades']:>6}  {a['win_pct']:>5.1f}%     "
          f"{b['net_pct']:>+7.1f}%  {b['pf']:>5.2f}  {b['eq_dd']:>6.1f}%  {b['trades']:>6}  {b['win_pct']:>5.1f}%")

is_nets = [r["net_pct"] for r in is_r]
oos_nets = [r["net_pct"] for r in oos_r]
is_dds  = [r["eq_dd"]   for r in is_r]
oos_dds = [r["eq_dd"]   for r in oos_r]
print()
print(f"  {'metric':<24} {'IS 2026':>10}  {'OOS 2025':>10}")
print(f"  {'-'*24} {'-'*10}  {'-'*10}")
print(f"  {'mean net%':<24} {mean(is_nets):>+9.1f}%  {mean(oos_nets):>+9.1f}%")
print(f"  {'std net%':<24} {stdev(is_nets):>10.1f}  {stdev(oos_nets):>10.1f}")
print(f"  {'worst month':<24} {min(is_nets):>+9.1f}%  {min(oos_nets):>+9.1f}%")
print(f"  {'best month':<24} {max(is_nets):>+9.1f}%  {max(oos_nets):>+9.1f}%")
print(f"  {'max eq DD%':<24} {max(is_dds):>9.1f}%  {max(oos_dds):>9.1f}%")
print(f"  {'DD>40% breaches':<24} {sum(1 for d in is_dds if d>40):>10}  {sum(1 for d in oos_dds if d>40):>10}")
print(f"  {'months positive':<24} {sum(1 for n in is_nets if n>0):>9}/5  {sum(1 for n in oos_nets if n>0):>9}/5")
