"""Embed the 2026-Q1 high-impact USD/EUR events relevant to XAUUSD.

For F0 we just need a small, accurate list to overlay on trade times. Times are
in UTC. The MT5 server uses GMT+2/+3 (RoboForex-Pro: EET/EEST). We convert at
overlay time using `broker_offset_hours`.

Source: Federal Reserve calendar, BLS schedule, BEA schedule, ECB monetary
policy calendar, BoE MPC calendar. Sept-Dec dates roll forward for future
reference. List trimmed to the events most likely to move gold.
"""

from __future__ import annotations

import csv
import datetime as dt
from pathlib import Path


# (utc_datetime_iso, currency, tier, label)
EVENTS: list[tuple[str, str, str, str]] = [
    # January 2026
    ("2026-01-08T13:30:00Z", "USD", "T1", "Initial Jobless Claims"),
    ("2026-01-09T13:30:00Z", "USD", "T1", "NFP — Dec 2025 data"),
    ("2026-01-14T13:30:00Z", "USD", "T1", "CPI YoY — Dec 2025"),
    ("2026-01-15T13:30:00Z", "USD", "T1", "PPI / Retail Sales"),
    ("2026-01-21T13:30:00Z", "USD", "T2", "Philly Fed / Building Permits"),
    ("2026-01-22T13:30:00Z", "EUR", "T1", "ECB Rate Decision"),
    ("2026-01-29T19:00:00Z", "USD", "T1", "FOMC Rate Decision"),
    ("2026-01-29T19:30:00Z", "USD", "T1", "FOMC Press Conference"),
    ("2026-01-29T13:30:00Z", "USD", "T1", "US GDP Q4 Advance"),
    ("2026-01-30T13:30:00Z", "USD", "T1", "PCE Index"),

    # February 2026
    ("2026-02-04T15:00:00Z", "USD", "T1", "JOLTS"),
    ("2026-02-05T13:30:00Z", "USD", "T2", "Trade Balance / Jobless Claims"),
    ("2026-02-05T12:00:00Z", "GBP", "T1", "BoE Rate Decision"),
    ("2026-02-06T13:30:00Z", "USD", "T1", "NFP — Jan 2026"),
    ("2026-02-12T13:30:00Z", "USD", "T1", "CPI YoY — Jan 2026"),
    ("2026-02-13T13:30:00Z", "USD", "T1", "Retail Sales / PPI"),
    ("2026-02-19T13:30:00Z", "USD", "T2", "FOMC Minutes"),
    ("2026-02-25T15:00:00Z", "USD", "T2", "Consumer Confidence"),
    ("2026-02-27T13:30:00Z", "USD", "T1", "PCE Index"),

    # March 2026
    ("2026-03-05T13:30:00Z", "USD", "T2", "Jobless Claims"),
    ("2026-03-06T13:30:00Z", "USD", "T1", "NFP — Feb 2026"),
    ("2026-03-06T13:15:00Z", "EUR", "T1", "ECB Rate Decision"),
    ("2026-03-12T13:30:00Z", "USD", "T1", "CPI YoY — Feb 2026"),
    ("2026-03-13T13:30:00Z", "USD", "T2", "PPI / Retail Sales"),
    ("2026-03-17T13:30:00Z", "USD", "T2", "Housing Starts"),
    ("2026-03-19T18:00:00Z", "USD", "T1", "FOMC Rate Decision"),
    ("2026-03-19T18:30:00Z", "USD", "T1", "FOMC Press Conference"),
    ("2026-03-19T12:00:00Z", "GBP", "T1", "BoE Rate Decision"),
    ("2026-03-26T13:30:00Z", "USD", "T1", "US GDP Q4 Final"),
    ("2026-03-28T13:30:00Z", "USD", "T1", "PCE Index"),
]


def write_csv(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["utc_datetime", "currency", "tier", "label"])
        for row in EVENTS:
            w.writerow(row)
    print(f"[calendar] wrote {len(EVENTS)} events to {path}")


if __name__ == "__main__":
    write_csv(Path(__file__).resolve().parent.parent / "data" / "calendar" / "Q1_2026.csv")
