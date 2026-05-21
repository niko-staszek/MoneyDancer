"""Parse an MT5 Strategy Tester log file into a trade-event CSV.

MT5 tester logs are UTF-16 LE with the format per line:
  <prefix>\t0\t<HH:MM:SS.fff>\tCore NN\t<SIM_DATETIME>   <event text>

We extract only the events that matter for F0 analysis:
- deal performed  → a buy/sell fill
- take profit triggered
- stop loss triggered
- position closed
- expert init / deinit, balance updates, errors

Position-modified spam is dropped (those are TP retargeting events).

Output: trades.csv with columns [sim_dt, real_time, action, ticket, side, lot,
price, sl, tp, source].
"""

from __future__ import annotations

import argparse
import csv
import re
from pathlib import Path


SIM_RE = re.compile(r"^(?P<sim>\d{4}\.\d{2}\.\d{2}\s+\d{2}:\d{2}:\d{2})\s+(?P<text>.+)$")


def read_utf16(path: Path) -> list[str]:
    raw = path.read_bytes()
    if raw.startswith(b"\xff\xfe") or raw.startswith(b"\xfe\xff"):
        text = raw.decode("utf-16", errors="replace")
    else:
        text = raw.decode("utf-8", errors="replace")
    return text.splitlines()


def parse_deal_text(text: str) -> dict | None:
    """Pull the structured bits from a 'deal performed' or TP/SL trigger line."""
    out: dict = {}
    # examples:
    #   deal performed [#1290 buy 0.01 XAUUSD at 4903.29]
    #   take profit triggered #183 buy 0.01 XAUUSD 4583.45 tp: 4584.43 [#184 sell 0.01 XAUUSD at 4584.43]
    #   stop loss triggered #100 buy 0.01 XAUUSD 4500.00 sl: 4499.00 [#101 sell ...]
    if "deal performed" in text:
        out["action"] = "deal"
        m = re.search(r"deal performed \[#(\d+)\s+(buy|sell)\s+([\d.]+)\s+(\S+)\s+at\s+([\d.]+)\]", text)
        if m:
            out["ticket"] = m.group(1)
            out["side"] = m.group(2)
            out["lot"] = m.group(3)
            out["symbol"] = m.group(4)
            out["price"] = m.group(5)
            return out
    elif "take profit triggered" in text:
        out["action"] = "tp_triggered"
        m = re.search(r"take profit triggered #(\d+)\s+(buy|sell)\s+([\d.]+)\s+\S+\s+([\d.]+)\s+tp:\s+([\d.]+)", text)
        if m:
            out["ticket"] = m.group(1)
            out["side"] = m.group(2)
            out["lot"] = m.group(3)
            out["entry_price"] = m.group(4)
            out["price"] = m.group(5)
            return out
    elif "stop loss triggered" in text:
        out["action"] = "sl_triggered"
        m = re.search(r"stop loss triggered #(\d+)\s+(buy|sell)\s+([\d.]+)\s+\S+\s+([\d.]+)\s+sl:\s+([\d.]+)", text)
        if m:
            out["ticket"] = m.group(1)
            out["side"] = m.group(2)
            out["lot"] = m.group(3)
            out["entry_price"] = m.group(4)
            out["price"] = m.group(5)
            return out
    elif "position closed" in text or "[#" in text and "out by " in text:
        out["action"] = "close"
        return out
    elif "Initial balance" in text or "balance" in text.lower() and "deposit" in text.lower():
        out["action"] = "init_balance"
        return out
    elif "final balance" in text.lower() or "ending balance" in text.lower():
        out["action"] = "final_balance"
        return out
    return None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--log", required=True, type=Path)
    ap.add_argument("--out", required=True, type=Path)
    args = ap.parse_args()

    lines = read_utf16(args.log)
    rows: list[dict] = []
    for line in lines:
        # Tester log lines are tab-separated: <prefix>\t0\t<time>\t<source>\t<message>
        parts = line.split("\t")
        if len(parts) < 5:
            continue
        source = parts[3].strip()
        if not source.startswith("Core"):
            continue  # only Core lines have sim_datetime + event detail
        message = parts[4]
        m = SIM_RE.match(message)
        if not m:
            continue
        text = m.group("text").strip()
        # Drop the noisy modification logs
        if "position modified" in text:
            continue
        parsed = parse_deal_text(text)
        if parsed is None:
            continue
        parsed["sim_dt"] = m.group("sim")
        parsed["raw"] = text[:200]
        rows.append(parsed)

    args.out.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "sim_dt", "action", "ticket", "side", "lot", "symbol", "price",
        "entry_price", "sl", "tp", "raw",
    ]
    with args.out.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)
    print(f"[parse_log] wrote {len(rows)} events to {args.out}")

    # Quick summary
    by_action: dict[str, int] = {}
    for r in rows:
        by_action[r["action"]] = by_action.get(r["action"], 0) + 1
    print("[parse_log] events by action:")
    for k, v in sorted(by_action.items(), key=lambda x: -x[1]):
        print(f"  {k}: {v}")
    return 0


if __name__ == "__main__":
    import sys
    sys.exit(main())
