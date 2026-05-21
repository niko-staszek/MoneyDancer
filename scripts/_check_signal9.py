import pandas as pd
df = pd.read_csv('runs/signals_apl_mar18/signal_outcomes.csv')
df['exits_summary'] = df['exits_summary'].fillna('').astype(str)
m = (df['signal_id'] == 9) & (df['exit_policy'] == 'scale_out') & (df['risk_pct'] == 1.0)
sub = df[m][['spread_profile', 'fill_time', 'fill_price', 'lot', 'first_exit_label',
             'first_exit_sec', 'net_pnl', 'exits_summary']]
print(sub.to_string(index=False))
