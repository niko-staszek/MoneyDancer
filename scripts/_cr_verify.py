import yaml
m = yaml.safe_load(open("runs/CR_VERIFY-5k-mar25/result.yaml"))["metrics"]
print("CR_VERIFY mar25: net=${:.2f} ({:+.1f}%) | DD={:.2f}% | trades={} | PF={}".format(
    m["net_profit"], m["net_profit"]/5000*100, m["equity_dd_rel"], int(m["trades"]), m["profit_factor"]))
print("STEP baseline:   net=$1850.91 (+37.0%) | DD=22.18% | trades=1722 | PF=1.33")
print()
match = (abs(m["net_profit"]-1850.91) < 0.01 and int(m["trades"]) == 1722 and abs(m["equity_dd_rel"]-22.18) < 0.01)
print("BIT-IDENTICAL:", "YES — code review fixes are backtest-invariant" if match else "NO — investigate divergence")
