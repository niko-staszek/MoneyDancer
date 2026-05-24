# F0 trade artifacts — master index

Generated from 13 per-run `trades.csv` files. Master CSV: `runs/trades_master.csv`. Use it for cross-run analysis (calendar/event overlay, regime detection, hour-of-day heatmaps, etc.).

| Run | Total deals | in | out | Σ profit | First ts | Last ts |
|---|---|---|---|---|---|---|
| F0-35k-pyramid | 588 | 294 | 294 | +1,837.43 | 2026.01.02 10:03:03 | 2026.01.30 23:54:59 |
| F0-35k-pyramid-duka | 826 | 413 | 413 | +5,226.21 | 2026.01.05 23:00:51 | 2026.01.30 16:26:41 |
| F0-3k-heavy-pyramid | 1,468 | 734 | 734 | +416.45 | 2026.01.02 10:03:03 | 2026.01.30 23:54:59 |
| F0-3k-heavy-pyramid-duka | 1,612 | 806 | 806 | +437.45 | 2026.01.05 23:00:51 | 2026.01.30 03:30:05 |
| F0-5k-duka-feb | 2,838 | 1,419 | 1,419 | +3,595.23 | 2026.02.02 23:52:44 | 2026.02.27 01:24:30 |
| F0-5k-duka-mar | 4,674 | 2,337 | 2,337 | +4,427.61 | 2026.03.02 23:02:07 | 2026.03.30 23:59:59 |
| F0-5k-duka-validate-AprMay | 414 | 207 | 207 | -21,463.95 | 2026.04.02 01:05:17 | 2026.04.07 01:20:00 |
| F0-5k-heavy-grid | 5,238 | 2,619 | 2,619 | +4,393.24 | 2026.01.02 10:00:09 | 2026.01.30 02:08:42 |
| F0-5k-heavy-grid-duka | 3,040 | 1,520 | 1,520 | +3,991.54 | 2026.01.05 23:00:46 | 2026.01.30 01:38:32 |
| F0-test1.3a-scalper | 954 | 477 | 477 | +14.78 | 2026.01.02 10:03:05 | 2026.01.30 23:54:59 |
| F0-test1.3a-scalper-duka | 8,372 | 4,186 | 4,186 | +2,954.44 | 2026.01.06 03:30:46 | 2026.01.30 23:59:59 |
| F0-test1.3a-scalper-duka-tightSpread | 340 | 170 | 170 | -1,076.75 | 2026.01.06 11:25:17 | 2026.01.30 23:59:59 |
| F0-test13a-fastscalper | 2,736 | 1,368 | 1,368 | +427.21 | 2026.01.02 10:03:05 | 2026.01.30 23:54:59 |

## Schema

Columns:
- `run_id`     — F0-* identifier
- `time`       — broker-server time `YYYY.MM.DD HH:MM:SS`
- `deal`       — MT5 deal id (sequential within run)
- `symbol`     — `XAUUSD` or `XAUUSD.duk`
- `type`       — `buy` or `sell`
- `direction`  — `in` (opening) or `out` (closing)
- `volume`     — lot size
- `price`      — fill price
- `order`      — order id (links in/out deals)
- `commission` / `swap` / `profit` / `balance` — currency in account ccy (USD)
- `comment`    — EA tag, e.g. `TBb1`, `TBs727`, `tp 4584.43`, `TBs761|D=3`

## Useful next-step queries

- **Calendar overlay**: `scripts/overlay_calendar.py --trades runs/<run_id>/trades.csv --calendar data/calendar/Q1_2026.csv --out runs/<run_id>/event_impact.csv`
- **Per-hour PnL**: aggregate `out` rows by `time[11:13]` (hour) → mean/sum profit
- **Per-day equity**: aggregate `out` rows by `time[:10]` (date) → cumulative `balance`
- **Basket-life distribution**: group by `comment` prefix (`TBb`, `TBs`) → time delta from first `in` to last `out`
- **Martingale-depth distribution**: comments with `|D=N` are Scenario-D adds at depth N
