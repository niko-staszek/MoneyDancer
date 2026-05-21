"""Regenerate verdict.md from existing signal_outcomes.csv / daily_pnl.csv.
Avoids re-loading 3GB ticks."""
import sys
from pathlib import Path

# Import the writer from the main script
sys.path.insert(0, str(Path(__file__).parent))
from replay_telegram_signals import write_verdict  # type: ignore

import pandas as pd

import sys as _sys
OUT = Path(_sys.argv[1] if len(_sys.argv) > 1 else 'runs/signals_apl_mar18')
TZ = int(_sys.argv[2]) if len(_sys.argv) > 2 else 2
outcomes = pd.read_csv(OUT / 'signal_outcomes.csv', parse_dates=['signal_time_utc', 'fill_time'])
outcomes['near_news'] = outcomes['near_news'].fillna('').astype(str)
outcomes['exits_summary'] = outcomes['exits_summary'].fillna('').astype(str)
daily = pd.read_csv(OUT / 'daily_pnl.csv', parse_dates=['date'])
daily['date'] = daily['date'].dt.date

write_verdict(outcomes, daily, OUT / 'verdict.md', tz_offset=TZ)
print(f"Regenerated {OUT / 'verdict.md'}  (tz=UTC+{TZ})")
