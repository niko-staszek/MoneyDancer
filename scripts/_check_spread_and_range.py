import pandas as pd

# Spread profile vs PnL spot-check
df = pd.read_csv('runs/signals_apl_mar18/signal_outcomes.csv')
mask = (df['signal_id'] == 4) & (df['exit_policy'] == 'scale_out') & (df['risk_pct'] == 1.0)
print('=== Signal 4 / scale_out / 1.0%  across spread profiles ===')
print(df[mask][['spread_profile', 'fill_time', 'fill_price', 'lot', 'net_pnl', 'first_exit_label', 'first_exit_sec']].to_string(index=False))
print()

# Per-day price range (use duka raw for canonical mids)
print('=== Per-day XAU range in tick data ===')
for prof in ['XAUUSD_2026_jan-may.csv', 'XAUUSD_2026_jan-may_robo.csv', 'XAUUSD_2026_jan-may_axi.csv']:
    print(f'--- {prof} ---')
    parts = []
    for chunk in pd.read_csv(f'data/duka/{prof}', chunksize=2_000_000):
        m = (chunk['utc_datetime'] >= '2026-03-17') & (chunk['utc_datetime'] < '2026-03-20')
        if m.any():
            parts.append(chunk[m])
        if chunk['utc_datetime'].iloc[-1] > '2026-03-20':
            break
    d = pd.concat(parts, ignore_index=True)
    d['utc_datetime'] = pd.to_datetime(d['utc_datetime'], utc=True)
    d['date'] = d['utc_datetime'].dt.date
    d['mid'] = (d['bid'] + d['ask']) / 2
    d['spread_pts'] = (d['ask'] - d['bid']) * 100
    agg = d.groupby('date').agg(
        bid_min=('bid', 'min'), bid_max=('bid', 'max'),
        ask_min=('ask', 'min'), ask_max=('ask', 'max'),
        mid_open=('mid', 'first'), mid_close=('mid', 'last'),
        spread_med=('spread_pts', 'median'),
        spread_p90=('spread_pts', lambda x: x.quantile(0.9)),
    ).round(2)
    print(agg.to_string())
    print()
