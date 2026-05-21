"""Extract the deals table from an MT5 Strategy Tester Report.htm.

MT5 reports have three tables (after the summary stats): Orders, Deals,
Positions. We pull the Deals table — that's the canonical trade record with
real fill prices, commissions, swaps, and PnL per deal.

Deals row format (13 cells):
  time | deal# | symbol | type(buy/sell) | direction(in/out) | volume |
  price | order# | commission | swap | profit | balance | comment

We detect deal rows by the in|out token in the 5th cell (orders use a state
token like "filled" in a different position).

Output: trades.csv per run, with columns suitable for calendar/event overlay
and downstream analysis.
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path


# Match a <tr ...> row and capture its inner content
TR_RE = re.compile(
    r"<tr[^>]*>(.*?)</tr>",
    re.DOTALL | re.IGNORECASE,
)
TD_RE = re.compile(r"<td[^>]*>(.*?)</td>", re.DOTALL | re.IGNORECASE)
TAG_RE = re.compile(r"<[^>]+>")


def read_html(path: Path) -> str:
    raw = path.read_bytes()
    if raw.startswith(b"\xff\xfe") or raw.startswith(b"\xfe\xff"):
        return raw.decode("utf-16", errors="replace")
    return raw.decode("utf-8", errors="replace")


def _clean(s: str) -> str:
    s = TAG_RE.sub("", s)
    return re.sub(r"\s+", " ", s).strip()


def _clean_num(s: str) -> float | None:
    s = s.replace("\xa0", " ").replace(" ", "").replace(",", "")
    try:
        return float(s)
    except ValueError:
        return None


def extract_deals(html: str) -> list[dict]:
    """Return one dict per deal row. Skips non-deal rows."""
    rows: list[dict] = []
    for m in TR_RE.finditer(html):
        cells_raw = TD_RE.findall(m.group(1))
        if len(cells_raw) != 13:
            continue
        cells = [_clean(c) for c in cells_raw]
        direction = cells[4].lower()
        if direction not in ("in", "out", "in/out"):
            continue
        ts = cells[0]
        if not re.match(r"^\d{4}\.\d{2}\.\d{2}\s+\d{2}:\d{2}:\d{2}$", ts):
            continue
        try:
            deal_id = int(cells[1])
        except ValueError:
            continue
        rows.append({
            "time": ts,
            "deal": deal_id,
            "symbol": cells[2],
            "type": cells[3],
            "direction": direction,
            "volume": _clean_num(cells[5]),
            "price": _clean_num(cells[6]),
            "order": cells[7],
            "commission": _clean_num(cells[8]) or 0.0,
            "swap": _clean_num(cells[9]) or 0.0,
            "profit": _clean_num(cells[10]) or 0.0,
            "balance": _clean_num(cells[11]) or 0.0,
            "comment": cells[12],
        })
    return rows


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--report", required=True, type=Path)
    ap.add_argument("--out", required=True, type=Path)
    args = ap.parse_args()

    html = read_html(args.report)
    deals = extract_deals(html)

    if not deals:
        print(f"[extract_trades] no deals found in {args.report}")
        return 1

    args.out.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "time", "deal", "symbol", "type", "direction",
        "volume", "price", "order",
        "commission", "swap", "profit", "balance",
        "comment",
    ]
    with args.out.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        w.writerows(deals)
    print(f"[extract_trades] wrote {len(deals):,} deals to {args.out}")
    # Brief summary
    by_dir: dict[str, int] = {}
    cum_profit = 0.0
    for d in deals:
        by_dir[d["direction"]] = by_dir.get(d["direction"], 0) + 1
        cum_profit += d["profit"]
    print(f"  in:  {by_dir.get('in', 0):,}")
    print(f"  out: {by_dir.get('out', 0):,}")
    print(f"  cumulative profit (out-deals only): {cum_profit:,.2f}")
    print(f"  first: {deals[0]['time']}")
    print(f"  last:  {deals[-1]['time']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
