"""Embed 2026-Q2 high-impact USD/EUR/GBP events relevant to XAUUSD.

Apr-May 2026 events. Same format as Q1: utc_datetime,currency,tier,label.
Used for the F0 OOS-failure period analysis.
"""

from __future__ import annotations

import csv
from pathlib import Path

EVENTS: list[tuple[str, str, str, str]] = [
    # April 2026
    ("2026-04-01T13:30:00Z", "USD", "T2", "ADP Employment"),
    ("2026-04-02T13:30:00Z", "USD", "T2", "Initial Jobless Claims / ISM Services"),
    ("2026-04-03T13:30:00Z", "USD", "T1", "NFP — Mar 2026 data"),
    ("2026-04-09T13:30:00Z", "USD", "T1", "PPI / Initial Jobless Claims"),
    ("2026-04-10T13:30:00Z", "USD", "T1", "CPI YoY — Mar 2026"),
    ("2026-04-15T13:30:00Z", "USD", "T2", "Retail Sales"),
    ("2026-04-16T11:45:00Z", "EUR", "T1", "ECB Rate Decision"),
    ("2026-04-22T13:30:00Z", "USD", "T2", "Existing Home Sales"),
    ("2026-04-23T13:30:00Z", "USD", "T2", "Initial Jobless Claims / Durable Goods"),
    ("2026-04-29T19:00:00Z", "USD", "T1", "FOMC Rate Decision"),
    ("2026-04-29T19:30:00Z", "USD", "T1", "FOMC Press Conference"),
    ("2026-04-29T13:30:00Z", "USD", "T1", "US GDP Q1 Advance"),
    ("2026-04-30T13:30:00Z", "USD", "T1", "PCE Index"),

    # May 2026
    ("2026-05-01T13:30:00Z", "USD", "T1", "NFP — Apr 2026 data"),
    ("2026-05-07T11:00:00Z", "GBP", "T1", "BoE Rate Decision"),
    ("2026-05-13T13:30:00Z", "USD", "T1", "CPI YoY — Apr 2026"),
    ("2026-05-14T13:30:00Z", "USD", "T1", "PPI / Retail Sales"),
]


def write_csv(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["utc_datetime", "currency", "tier", "label"])
        w.writerows(EVENTS)
    print(f"[calendar] wrote {len(EVENTS)} events to {path}")


if __name__ == "__main__":
    write_csv(Path(__file__).resolve().parent.parent / "data" / "calendar" / "Q2_2026.csv")
