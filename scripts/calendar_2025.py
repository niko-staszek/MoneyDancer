"""Embed 2025 high-impact USD/EUR/GBP events relevant to XAUUSD.

For Sprint 7 walk-forward validation we need a historical 2025 calendar to
overlay onto trades. UTC times. The MT5 server uses GMT+2/+3 (RoboForex-Pro:
EET/EEST); conversion happens in `overlay_calendar.py`.

Source: published 2025 calendars for FOMC, ECB, BoE; BLS NFP first-Friday
schedule; routine release patterns for CPI/PCE/PPI/Retail Sales. Dates
verified against public Fed/ECB/BoE calendars; CPI/PCE/PPI dates approximate
to the standard release pattern.

DST notes:
  US (ET): EST -> EDT on 2025-03-09; EDT -> EST on 2025-11-02
  EU (CET): CET -> CEST on 2025-03-30; CEST -> CET on 2025-10-26
  UK (GMT): GMT -> BST on 2025-03-30; BST -> GMT on 2025-10-26
"""

from __future__ import annotations

import csv
import sys
from pathlib import Path


# (utc_datetime, currency, tier, label)
EVENTS: list[tuple[str, str, str, str]] = [
    # ===== January 2025 =====
    ("2025-01-10T13:30:00Z", "USD", "T1", "NFP - Dec 2024"),
    ("2025-01-15T13:30:00Z", "USD", "T1", "CPI YoY - Dec 2024"),
    ("2025-01-16T13:30:00Z", "USD", "T2", "PPI / Retail Sales"),
    ("2025-01-29T19:00:00Z", "USD", "T1", "FOMC Rate Decision"),
    ("2025-01-29T19:30:00Z", "USD", "T1", "FOMC Press Conference"),
    ("2025-01-30T13:30:00Z", "USD", "T1", "US GDP Q4 Advance"),
    ("2025-01-30T13:15:00Z", "EUR", "T1", "ECB Rate Decision"),
    ("2025-01-31T13:30:00Z", "USD", "T1", "PCE Index"),

    # ===== February 2025 =====
    ("2025-02-06T12:00:00Z", "GBP", "T1", "BoE Rate Decision"),
    ("2025-02-07T13:30:00Z", "USD", "T1", "NFP - Jan 2025"),
    ("2025-02-12T13:30:00Z", "USD", "T1", "CPI YoY - Jan 2025"),
    ("2025-02-13T13:30:00Z", "USD", "T2", "PPI"),
    ("2025-02-14T13:30:00Z", "USD", "T2", "Retail Sales"),
    ("2025-02-19T19:00:00Z", "USD", "T2", "FOMC Minutes"),
    ("2025-02-28T13:30:00Z", "USD", "T1", "PCE Index"),

    # ===== March 2025 =====
    ("2025-03-06T13:15:00Z", "EUR", "T1", "ECB Rate Decision"),
    ("2025-03-07T13:30:00Z", "USD", "T1", "NFP - Feb 2025"),
    ("2025-03-12T12:30:00Z", "USD", "T1", "CPI YoY - Feb 2025"),  # DST active
    ("2025-03-13T12:30:00Z", "USD", "T2", "PPI"),
    ("2025-03-17T12:30:00Z", "USD", "T2", "Retail Sales"),
    ("2025-03-19T18:00:00Z", "USD", "T1", "FOMC Rate Decision"),
    ("2025-03-19T18:30:00Z", "USD", "T1", "FOMC Press Conference"),
    ("2025-03-20T12:00:00Z", "GBP", "T1", "BoE Rate Decision"),
    ("2025-03-27T12:30:00Z", "USD", "T1", "US GDP Q4 Final"),
    ("2025-03-28T12:30:00Z", "USD", "T1", "PCE Index"),

    # ===== April 2025 =====
    ("2025-04-04T12:30:00Z", "USD", "T1", "NFP - Mar 2025"),
    ("2025-04-10T12:30:00Z", "USD", "T1", "CPI YoY - Mar 2025"),
    ("2025-04-11T12:30:00Z", "USD", "T2", "PPI"),
    ("2025-04-16T12:30:00Z", "USD", "T2", "Retail Sales"),
    ("2025-04-17T12:15:00Z", "EUR", "T1", "ECB Rate Decision"),
    ("2025-04-30T12:30:00Z", "USD", "T1", "US GDP Q1 Advance"),
    ("2025-04-30T12:30:00Z", "USD", "T1", "PCE Index"),

    # ===== May 2025 =====
    ("2025-05-02T12:30:00Z", "USD", "T1", "NFP - Apr 2025"),
    ("2025-05-07T18:00:00Z", "USD", "T1", "FOMC Rate Decision"),
    ("2025-05-07T18:30:00Z", "USD", "T1", "FOMC Press Conference"),
    ("2025-05-08T11:00:00Z", "GBP", "T1", "BoE Rate Decision"),
    ("2025-05-13T12:30:00Z", "USD", "T1", "CPI YoY - Apr 2025"),
    ("2025-05-15T12:30:00Z", "USD", "T2", "Retail Sales / PPI"),
    ("2025-05-30T12:30:00Z", "USD", "T1", "PCE Index"),

    # ===== June 2025 =====
    ("2025-06-05T12:15:00Z", "EUR", "T1", "ECB Rate Decision"),
    ("2025-06-06T12:30:00Z", "USD", "T1", "NFP - May 2025"),
    ("2025-06-11T12:30:00Z", "USD", "T1", "CPI YoY - May 2025"),
    ("2025-06-12T12:30:00Z", "USD", "T2", "PPI"),
    ("2025-06-17T12:30:00Z", "USD", "T2", "Retail Sales"),
    ("2025-06-18T18:00:00Z", "USD", "T1", "FOMC Rate Decision"),
    ("2025-06-18T18:30:00Z", "USD", "T1", "FOMC Press Conference"),
    ("2025-06-19T11:00:00Z", "GBP", "T1", "BoE Rate Decision"),
    ("2025-06-27T12:30:00Z", "USD", "T1", "PCE Index"),

    # ===== July 2025 =====
    ("2025-07-03T12:30:00Z", "USD", "T1", "NFP - Jun 2025 (early; Jul 4 holiday)"),
    ("2025-07-15T12:30:00Z", "USD", "T1", "CPI YoY - Jun 2025"),
    ("2025-07-16T12:30:00Z", "USD", "T2", "PPI"),
    ("2025-07-17T12:30:00Z", "USD", "T2", "Retail Sales"),
    ("2025-07-24T12:15:00Z", "EUR", "T1", "ECB Rate Decision"),
    ("2025-07-30T12:30:00Z", "USD", "T1", "US GDP Q2 Advance"),
    ("2025-07-30T18:00:00Z", "USD", "T1", "FOMC Rate Decision"),
    ("2025-07-30T18:30:00Z", "USD", "T1", "FOMC Press Conference"),
    ("2025-07-31T12:30:00Z", "USD", "T1", "PCE Index"),

    # ===== August 2025 =====
    ("2025-08-01T12:30:00Z", "USD", "T1", "NFP - Jul 2025"),
    ("2025-08-07T11:00:00Z", "GBP", "T1", "BoE Rate Decision"),
    ("2025-08-12T12:30:00Z", "USD", "T1", "CPI YoY - Jul 2025"),
    ("2025-08-14T12:30:00Z", "USD", "T2", "PPI / Retail Sales"),
    ("2025-08-22T14:00:00Z", "USD", "T1", "Jackson Hole - Powell remarks"),
    ("2025-08-29T12:30:00Z", "USD", "T1", "PCE Index"),

    # ===== September 2025 =====
    ("2025-09-05T12:30:00Z", "USD", "T1", "NFP - Aug 2025"),
    ("2025-09-11T12:30:00Z", "USD", "T1", "CPI YoY - Aug 2025"),
    ("2025-09-11T12:15:00Z", "EUR", "T1", "ECB Rate Decision"),
    ("2025-09-12T12:30:00Z", "USD", "T2", "PPI"),
    ("2025-09-16T12:30:00Z", "USD", "T2", "Retail Sales"),
    ("2025-09-17T18:00:00Z", "USD", "T1", "FOMC Rate Decision"),
    ("2025-09-17T18:30:00Z", "USD", "T1", "FOMC Press Conference"),
    ("2025-09-18T11:00:00Z", "GBP", "T1", "BoE Rate Decision"),
    ("2025-09-26T12:30:00Z", "USD", "T1", "PCE Index"),

    # ===== October 2025 =====
    ("2025-10-03T12:30:00Z", "USD", "T1", "NFP - Sep 2025"),
    ("2025-10-15T12:30:00Z", "USD", "T1", "CPI YoY - Sep 2025"),
    ("2025-10-16T12:30:00Z", "USD", "T2", "PPI / Retail Sales"),
    ("2025-10-29T18:00:00Z", "USD", "T1", "FOMC Rate Decision"),
    ("2025-10-29T18:30:00Z", "USD", "T1", "FOMC Press Conference"),
    ("2025-10-30T12:30:00Z", "USD", "T1", "US GDP Q3 Advance"),
    ("2025-10-30T13:15:00Z", "EUR", "T1", "ECB Rate Decision"),
    ("2025-10-31T12:30:00Z", "USD", "T1", "PCE Index"),

    # ===== November 2025 =====
    ("2025-11-06T12:00:00Z", "GBP", "T1", "BoE Rate Decision"),
    ("2025-11-07T13:30:00Z", "USD", "T1", "NFP - Oct 2025"),  # DST off
    ("2025-11-13T13:30:00Z", "USD", "T1", "CPI YoY - Oct 2025"),
    ("2025-11-14T13:30:00Z", "USD", "T2", "PPI / Retail Sales"),
    ("2025-11-26T13:30:00Z", "USD", "T1", "PCE Index"),

    # ===== December 2025 =====
    ("2025-12-05T13:30:00Z", "USD", "T1", "NFP - Nov 2025"),
    ("2025-12-10T13:30:00Z", "USD", "T1", "CPI YoY - Nov 2025"),
    ("2025-12-10T19:00:00Z", "USD", "T1", "FOMC Rate Decision"),
    ("2025-12-10T19:30:00Z", "USD", "T1", "FOMC Press Conference"),
    ("2025-12-11T13:30:00Z", "USD", "T2", "PPI / Retail Sales"),
    ("2025-12-18T13:15:00Z", "EUR", "T1", "ECB Rate Decision"),
    ("2025-12-18T12:00:00Z", "GBP", "T1", "BoE Rate Decision"),
    ("2025-12-19T13:30:00Z", "USD", "T1", "PCE Index"),
]


def write_split(out_dir: Path) -> None:
    """Write Q1/Q2/Q3/Q4 and a combined 2025_full.csv."""
    out_dir.mkdir(parents=True, exist_ok=True)
    quarters: dict[str, list[tuple[str, str, str, str]]] = {
        "Q1_2025": [], "Q2_2025": [], "Q3_2025": [], "Q4_2025": [],
    }
    for row in EVENTS:
        month = int(row[0][5:7])
        q = "Q1_2025" if month <= 3 else ("Q2_2025" if month <= 6 else ("Q3_2025" if month <= 9 else "Q4_2025"))
        quarters[q].append(row)

    for name, rows in quarters.items():
        path = out_dir / f"{name}.csv"
        with path.open("w", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            w.writerow(["utc_datetime", "currency", "tier", "label"])
            w.writerows(rows)
        print(f"[calendar] wrote {len(rows)} events to {path}")

    combined = out_dir / "2025_full.csv"
    with combined.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["utc_datetime", "currency", "tier", "label"])
        w.writerows(EVENTS)
    print(f"[calendar] wrote {len(EVENTS)} events to {combined}")


if __name__ == "__main__":
    out = Path(__file__).resolve().parent.parent / "data" / "calendar"
    write_split(out)
    sys.exit(0)
