"""Break down TNFX backtest by quarter and check whether the 'tnfx is great' window
was an isolated event or whether it's reproducible at different periods."""
import sys
from pathlib import Path
import pandas as pd
sys.stdout.reconfigure(encoding='utf-8')

OUT = Path('runs/tnfx_full')
outcomes = pd.read_csv(OUT / 'signal_outcomes.csv', parse_dates=['time_utc', 'fill_time'])
outcomes['date'] = pd.to_datetime(outcomes['time_utc']).dt.date

# Use scale_out at 1% as the "reasonable retail" benchmark for comparison
sub = outcomes[(outcomes['exit_policy'] == 'scale_out') & (outcomes['risk_pct'] == 1.0)].copy()
sub['quarter'] = pd.PeriodIndex(pd.to_datetime(sub['time_utc']), freq='Q')

print('=== Per quarter (scale_out, 1% risk) ===')
print(sub.groupby('quarter').agg(
    n_signals=('msg_idx', 'count'),
    n_filled=('fill_kind', lambda x: (x != 'NEVER').sum()),
    wins=('net_pnl', lambda x: (x > 0).sum()),
    losses=('net_pnl', lambda x: (x < 0).sum()),
    total_pnl=('net_pnl', 'sum'),
    avg_per_signal=('net_pnl', 'mean'),
).round(2).to_string())

# Also the March-April 2026 window we originally backtested
mar_apr = sub[(sub['date'] >= pd.Timestamp('2026-03-26').date()) &
              (sub['date'] <= pd.Timestamp('2026-04-13').date())]
print(f'\n=== Original 12-day window (Mar26-Apr13 2026), scale_out 1% ===')
print(f'  n_signals: {len(mar_apr)}')
print(f'  total PnL: ${mar_apr["net_pnl"].sum():,.2f}')
print(f'  wins/losses: {(mar_apr["net_pnl"]>0).sum()}/{(mar_apr["net_pnl"]<0).sum()}')

# And the 1% per-policy summary
print('\n=== Per exit_policy total across all 1326 signals (1% risk) ===')
for pol in ['scale_out', 'tp1_be', 'tp1_only']:
    p = outcomes[(outcomes['exit_policy'] == pol) & (outcomes['risk_pct'] == 1.0)]
    print(f'  {pol:<10}  total=${p["net_pnl"].sum():,.0f}  '
          f'winrate={(p["net_pnl"]>0).sum()/len(p)*100:.1f}%  '
          f'avg_per_sig=${p["net_pnl"].mean():,.2f}')
