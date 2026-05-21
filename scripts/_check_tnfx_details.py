import pandas as pd
import sys
sys.stdout.reconfigure(encoding='utf-8')

out = pd.read_csv('runs/signals_discord/tnfx/signal_outcomes.csv')
out['near_news'] = out['near_news'].fillna('').astype(str)
out['exits_summary'] = out['exits_summary'].fillna('').astype(str)

# Per signal at the BEST config: axi/scale_out/20%
print('=== Per signal at axi/scale_out/20% (best config) ===')
sub = out[(out['spread_profile'] == 'axi') & (out['exit_policy'] == 'scale_out') & (out['risk_pct'] == 20.0)]
sub = sub.sort_values('signal_time_utc')
cols = ['msg_idx', 'signal_time_utc', 'side', 'entry_signal', 'sl', 'fill_kind',
        'fill_price', 'lot', 'first_exit_label', 'net_pnl', 'net_pct', 'equity_post']
print(sub[cols].to_string(index=False))
print()

# Also tnfx daily at 20% risk
print('=== Daily PnL at axi/scale_out/20% ===')
daily = pd.read_csv('runs/signals_discord/tnfx/daily_pnl.csv')
d = daily[(daily['spread_profile'] == 'axi') & (daily['exit_policy'] == 'scale_out') & (daily['risk_pct'] == 20.0)]
print(d.to_string(index=False))

# Same at 1% for comparison
print('\n=== Per signal at axi/scale_out/1% (low risk) ===')
sub = out[(out['spread_profile'] == 'axi') & (out['exit_policy'] == 'scale_out') & (out['risk_pct'] == 1.0)]
sub = sub.sort_values('signal_time_utc')
print(sub[cols].to_string(index=False))
