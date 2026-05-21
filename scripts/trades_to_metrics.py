"""Compute summary metrics directly from a parsed trades.csv.

Fallback when MT5's Report=name.htm doesn't materialize where we expect.
Reconstructs basket P/L, equity curve, max DD, win/loss counts from the
trade-event stream produced by parse_tester_log.py.

XAUUSD specifics (2-digit, contract 100 oz, tick value $1/lot/price-point):
  pl_per_lot = (close_price - open_price) × 100 × side_sign
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
from collections import defaultdict
from pathlib import Path


# Per-symbol contract specs (extend as needed)
SYMBOL_SPECS: dict[str, dict] = {
    "XAUUSD": {"contract_size": 100, "digits": 2},
    "EURUSD": {"contract_size": 100000, "digits": 5},
}


def lot_pnl(symbol: str, side: str, open_price: float, close_price: float, lot: float) -> float:
    """Approximate P/L assuming USD-quoted symbol on USD account.

    For XAUUSD: contract size 100 oz, so 1 lot × ($X price move) = $100 × X.
    """
    spec = SYMBOL_SPECS.get(symbol, {"contract_size": 100, "digits": 2})
    sign = 1 if side == "buy" else -1
    return lot * spec["contract_size"] * (close_price - open_price) * sign


def compute_metrics(trades: list[dict], deposit: float) -> dict:
    """Build equity curve and metrics from a chronological trade-event stream.

    Heuristic: pair each opening 'deal' (ticket→opening price/side/lot) with the
    closing event ('tp_triggered' / 'sl_triggered' for original position; close
    deals reference the closing ticket which we don't always match cleanly).

    We approximate by assuming TP/SL triggered events close the entry they
    reference (ticket field in the trigger line).
    """
    # Build a map: opening_ticket -> (open_price, side, lot, symbol, sim_dt)
    opens: dict[str, dict] = {}
    closed: list[dict] = []
    deals = [t for t in trades if t["action"] == "deal"]
    triggers = [t for t in trades if t["action"] in ("tp_triggered", "sl_triggered")]

    # First pass: collect openings (each deal performed is an open OR a close fill)
    # Approximation: a 'deal' that's a closing fill follows a tp/sl trigger. We
    # treat ALL 'deal' rows as candidates for opens and rely on trigger pairings
    # to detect closes.
    for d in deals:
        ticket = d.get("ticket")
        if not ticket:
            continue
        try:
            price = float(d.get("price") or 0)
            lot = float(d.get("lot") or 0)
        except (ValueError, TypeError):
            continue
        if ticket in opens:
            # Could be a closing leg — skip for simplicity
            continue
        opens[ticket] = {
            "ticket": ticket,
            "open_price": price,
            "side": d.get("side") or "",
            "lot": lot,
            "symbol": d.get("symbol") or "XAUUSD",
            "open_dt": d.get("sim_dt") or "",
        }

    # Second pass: pair triggers with their opens
    for trig in triggers:
        tk = trig.get("ticket")
        if not tk or tk not in opens:
            continue
        op = opens.pop(tk)
        try:
            close_price = float(trig.get("price") or 0)
        except (ValueError, TypeError):
            continue
        pnl = lot_pnl(op["symbol"], op["side"], op["open_price"], close_price, op["lot"])
        closed.append({
            **op,
            "close_price": close_price,
            "close_dt": trig.get("sim_dt") or "",
            "close_reason": "tp" if trig["action"] == "tp_triggered" else "sl",
            "pnl": pnl,
        })

    # Sort closed by close_dt for equity curve construction
    closed.sort(key=lambda x: x["close_dt"])

    equity = deposit
    peak = deposit
    max_dd_abs = 0.0
    max_dd_rel = 0.0
    daily_pnl: dict[str, float] = defaultdict(float)
    wins = losses = 0
    gross_profit = gross_loss = 0.0
    largest_win = largest_loss = 0.0
    equity_curve: list[tuple[str, float]] = [("0", deposit)]

    for c in closed:
        equity += c["pnl"]
        if equity > peak:
            peak = equity
        dd_abs = peak - equity
        if dd_abs > max_dd_abs:
            max_dd_abs = dd_abs
            max_dd_rel = (dd_abs / peak) * 100.0 if peak else 0
        day = c["close_dt"][:10]
        daily_pnl[day] += c["pnl"]
        if c["pnl"] > 0:
            wins += 1
            gross_profit += c["pnl"]
            if c["pnl"] > largest_win:
                largest_win = c["pnl"]
        else:
            losses += 1
            gross_loss += c["pnl"]
            if c["pnl"] < largest_loss:
                largest_loss = c["pnl"]
        equity_curve.append((c["close_dt"], equity))

    daily_returns = sorted(daily_pnl.items())
    pf = (gross_profit / abs(gross_loss)) if gross_loss != 0 else float("inf")
    net = equity - deposit

    # Worst rolling 60-day return — approximate by daily sum
    daily_vals = [v for _, v in daily_returns]
    worst_60d = 0.0
    for i in range(len(daily_vals)):
        window_sum = sum(daily_vals[i:i + 60])
        if window_sum < worst_60d:
            worst_60d = window_sum

    return {
        "deposit": deposit,
        "final_equity": equity,
        "net_profit": net,
        "net_return_pct": (net / deposit) * 100 if deposit else 0,
        "gross_profit": gross_profit,
        "gross_loss": gross_loss,
        "profit_factor": pf if pf != float("inf") else None,
        "max_dd_abs": max_dd_abs,
        "max_dd_rel_pct": max_dd_rel,
        "trades_closed": len(closed),
        "trades_opened_unclosed": len(opens),
        "wins": wins,
        "losses": losses,
        "win_rate_pct": (100 * wins / (wins + losses)) if (wins + losses) else 0,
        "largest_win": largest_win,
        "largest_loss": largest_loss,
        "worst_60d_return": worst_60d,
        "trading_days": len(daily_returns),
        "best_day": max(daily_returns, key=lambda x: x[1]) if daily_returns else None,
        "worst_day": min(daily_returns, key=lambda x: x[1]) if daily_returns else None,
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--trades", required=True, type=Path)
    ap.add_argument("--deposit", type=float, default=100000)
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()

    with args.trades.open("r", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    metrics = compute_metrics(rows, args.deposit)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(metrics, indent=2, default=str), encoding="utf-8")
    print(f"[trades_metrics] wrote {args.out}")
    for k, v in metrics.items():
        if isinstance(v, float):
            print(f"  {k}: {v:.2f}")
        else:
            print(f"  {k}: {v}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
