"""Cross-reference parsed trade events with the Q1 2026 calendar.

For each calendar event, find all trades in [T-60min, T+120min] and summarize:
  - count of buys / sells fired in pre-window vs post-window
  - count of TPs / SLs triggered in post-window
  - rough proxy for "EA reaction to event": did positions accumulate during the
    blackout? Did the basket close on a TP wave immediately after?

Broker server (RoboForex-Pro) runs GMT+2 in winter (EET) and GMT+3 in summer
(EEST). Q1 2026 is winter → broker_offset_hours = +2 from UTC.

Output: event_impact.csv with one row per (event, .set run) pair.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
from pathlib import Path


BROKER_OFFSET_HOURS = 2  # RoboForex-Pro winter time = GMT+2


def parse_iso_utc(s: str) -> dt.datetime:
    return dt.datetime.fromisoformat(s.replace("Z", "+00:00"))


def parse_sim_dt(s: str) -> dt.datetime:
    """MT5 log sim time format: YYYY.MM.DD HH:MM:SS in broker time."""
    return dt.datetime.strptime(s, "%Y.%m.%d %H:%M:%S")


def event_to_broker_dt(event_utc_iso: str, broker_offset: int) -> dt.datetime:
    """Convert event UTC time to broker server time (naive)."""
    utc_dt = parse_iso_utc(event_utc_iso)
    broker = utc_dt + dt.timedelta(hours=broker_offset)
    return broker.replace(tzinfo=None)


def load_trades(trades_csv: Path) -> list[dict]:
    """Load a per-run trades.csv. Supports both formats:
       - report-derived (cols: time, deal, direction, type, ...)
       - log-derived (cols: sim_dt, action, side, ...)"""
    rows: list[dict] = []
    with trades_csv.open("r", encoding="utf-8") as f:
        for r in csv.DictReader(f):
            ts_str = r.get("time") or r.get("sim_dt")
            if not ts_str:
                continue
            r["sim_ts"] = parse_sim_dt(ts_str)
            # Normalize action/side fields across the two formats
            if "action" not in r:
                # report-derived: direction in/out maps to action
                direction = r.get("direction", "")
                r["action"] = "deal_open" if direction == "in" else (
                    "deal_close" if direction == "out" else "other"
                )
                # type field is buy/sell already; copy to side
                r.setdefault("side", r.get("type", ""))
            rows.append(r)
    return rows


def load_calendar(cal_csv: Path) -> list[dict]:
    rows: list[dict] = []
    with cal_csv.open("r", encoding="utf-8") as f:
        for r in csv.DictReader(f):
            r["broker_ts"] = event_to_broker_dt(r["utc_datetime"], BROKER_OFFSET_HOURS)
            rows.append(r)
    return rows


def summarize_event(event: dict, trades: list[dict],
                    pre_min: int = 60, post_min: int = 120) -> dict:
    """Count trades in the windows around the event."""
    t0 = event["broker_ts"]
    pre_lo = t0 - dt.timedelta(minutes=pre_min)
    post_hi = t0 + dt.timedelta(minutes=post_min)

    pre_buy = pre_sell = post_buy = post_sell = 0
    tp_in_post = sl_in_post = 0
    post_close_profit = 0.0
    for tr in trades:
        ts = tr["sim_ts"]
        if ts < pre_lo or ts > post_hi:
            continue
        action = tr.get("action", "")
        side = tr.get("side", "")
        # In the report-derived format, action is deal_open / deal_close.
        # In the log-derived format, action is deal / tp_triggered / sl_triggered.
        is_open = action in ("deal_open", "deal")
        is_close = action == "deal_close"
        if ts < t0:
            if is_open:
                if side == "buy":
                    pre_buy += 1
                elif side == "sell":
                    pre_sell += 1
        else:
            if is_open:
                if side == "buy":
                    post_buy += 1
                elif side == "sell":
                    post_sell += 1
            if is_close:
                try:
                    profit = float(tr.get("profit", "0"))
                except ValueError:
                    profit = 0.0
                post_close_profit += profit
                comment = tr.get("comment", "")
                if "tp" in comment.lower():
                    tp_in_post += 1
                elif "sl" in comment.lower() or "sl " in comment:
                    sl_in_post += 1
            # Log-derived format markers
            if action == "tp_triggered":
                tp_in_post += 1
            elif action == "sl_triggered":
                sl_in_post += 1

    return {
        "event_utc": event["utc_datetime"],
        "event_broker": t0.isoformat(),
        "currency": event["currency"],
        "tier": event["tier"],
        "label": event["label"],
        "pre_buy": pre_buy,
        "pre_sell": pre_sell,
        "post_buy": post_buy,
        "post_sell": post_sell,
        "tp_in_post": tp_in_post,
        "sl_in_post": sl_in_post,
        "total_in_window": pre_buy + pre_sell + post_buy + post_sell,
        "post_close_profit": round(post_close_profit, 2),
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--trades", required=True, type=Path)
    ap.add_argument("--calendar", required=True, type=Path)
    ap.add_argument("--out", required=True, type=Path)
    ap.add_argument("--pre-min", type=int, default=60)
    ap.add_argument("--post-min", type=int, default=120)
    ap.add_argument("--tier-filter", default="T1",
                    help="Only events at or above this tier (T1 = top)")
    args = ap.parse_args()

    trades = load_trades(args.trades)
    events = load_calendar(args.calendar)
    tier_rank = {"T1": 1, "T2": 2, "T3": 3, "HOLIDAY": 4}
    keep_tier = tier_rank.get(args.tier_filter, 1)
    events = [e for e in events if tier_rank.get(e["tier"], 9) <= keep_tier]

    args.out.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "event_utc", "event_broker", "currency", "tier", "label",
        "pre_buy", "pre_sell", "post_buy", "post_sell",
        "tp_in_post", "sl_in_post", "total_in_window", "post_close_profit",
    ]
    with args.out.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        for ev in events:
            row = summarize_event(ev, trades, args.pre_min, args.post_min)
            w.writerow(row)
    print(f"[overlay] wrote {len(events)} event rows to {args.out}")

    # Summary: which event had the most trade activity?
    summaries = [summarize_event(ev, trades, args.pre_min, args.post_min) for ev in events]
    summaries.sort(key=lambda x: x["total_in_window"], reverse=True)
    print("[overlay] top 5 events by trade activity in window:")
    for s in summaries[:5]:
        print(f"  {s['event_broker']}  {s['label']:40s}  total={s['total_in_window']:3d}  "
              f"pre=({s['pre_buy']}/{s['pre_sell']})  post=({s['post_buy']}/{s['post_sell']})  "
              f"TPs={s['tp_in_post']}  SLs={s['sl_in_post']}")
    return 0


if __name__ == "__main__":
    import sys
    sys.exit(main())
