"""Parse an MT5 Strategy Tester Report.htm into a metrics dict + trades list.

MT5 generates the report as a UTF-16 HTML with a fixed-ish structure:
- Header table with run setup
- Summary stats table (Net Profit, Profit Factor, Drawdown, ...)
- A detailed deals/orders table

This parser is permissive — it pulls every (label, value) pair from the stats
table by reading <b>label</b><td>value</td> patterns, and parses the deals
table by looking for the row header containing "Time" + "Deal".

Outputs a `result.yaml` matching the graph schema from the plan.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import sys
from pathlib import Path

from html.parser import HTMLParser


def read_html(path: Path) -> str:
    """MT5 writes report.htm as UTF-16 LE (with BOM). Fall back to latin-1."""
    raw = path.read_bytes()
    if raw.startswith(b"\xff\xfe") or raw.startswith(b"\xfe\xff"):
        return raw.decode("utf-16")
    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError:
        return raw.decode("latin-1", errors="ignore")


_NUM_RE = re.compile(r"-?\d[\d ,]*\.?\d*")


def _clean_num(s: str) -> float | None:
    """Extract first numeric token from a string with possible spaces/commas."""
    s = s.replace("\xa0", " ").strip()
    m = _NUM_RE.search(s)
    if not m:
        return None
    raw = m.group(0).replace(" ", "").replace(",", "")
    try:
        return float(raw)
    except ValueError:
        return None


class _StatsExtractor(HTMLParser):
    """Extracts (label, value) pairs from the MT5 report summary table.

    The table cells alternate between bold-label cells (`<b>Net Profit:</b>`)
    and value cells (`<b>123.45</b>`). We grab all <td>...</td> text and pair
    label-with-colon cells to the next non-colon-cell.
    """

    def __init__(self) -> None:
        super().__init__()
        self.cells: list[str] = []
        self._in_td = False
        self._buf: list[str] = []
        self._capture_text = False

    def handle_starttag(self, tag: str, attrs):
        if tag == "td":
            self._in_td = True
            self._buf = []
            self._capture_text = True

    def handle_endtag(self, tag: str):
        if tag == "td" and self._in_td:
            text = "".join(self._buf).strip()
            text = re.sub(r"\s+", " ", text)
            self.cells.append(text)
            self._in_td = False
            self._capture_text = False

    def handle_data(self, data: str):
        if self._capture_text:
            self._buf.append(data)


def extract_polish_summary(html: str) -> dict[str, float]:
    """Robust regex-on-text extraction of summary stats from a Polish MT5 report.

    The summary section uses fixed phrasing; we strip HTML and search the
    flattened text. ASCII fragments survive cp1250 mangling.
    """
    # Flatten HTML to plain text
    text = re.sub(r"<[^>]+>", "\n", html)
    text = re.sub(r"&nbsp;|&#160;", " ", text)
    text = re.sub(r"[ \t]+", " ", text)

    out: dict[str, float] = {}

    # Tighter regexes — each label followed by its value
    patterns = [
        # Polish
        (r"Zysk Netto Og[^:]{0,5}:\s*([+\-]?[\d ,\xa0]+\.\d+)", "net_profit"),
        (r"Zysk Brutto:\s*([+\-]?[\d ,\xa0]+\.\d+)", "gross_profit"),
        (r"Strata Brutto:\s*([+\-]?[\d ,\xa0]+\.\d+)", "gross_loss"),
        (r"Wska[^:]{0,5}Zysku:\s*([+\-]?[\d ,\xa0]+\.\d+)", "profit_factor"),
        (r"Oczekiwany Payoff:\s*([+\-]?[\d ,\xa0]+\.\d+)", "expected_payoff"),
        (r"Wska[^:]{0,5}Odzyskania[^:]+:\s*([+\-]?[\d ,\xa0]+\.\d+)", "recovery_factor"),
        (r"Wska[^:]{0,5}Sharpe[^:]+:\s*([+\-]?[\d ,\xa0]+\.\d+)", "sharpe"),
        (r"Wszystkie Transakcje:\s*([+\-]?[\d ,\xa0]+)", "total_trades"),
        (r"Wszystkie Umowy:\s*([+\-]?[\d ,\xa0]+)", "total_deals"),
        (r"Profit Trades[^:]+:\s*([+\-]?[\d ,\xa0]+)\s*\(([\d.]+)%\)", "profit_trades_pct"),
        (r"Loss Trades[^:]+:\s*([+\-]?[\d ,\xa0]+)\s*\(([\d.]+)%\)", "loss_trades_pct"),
        (r"Najwi[^:]{0,5}zyskowna transakcja:\s*([+\-]?[\d ,\xa0]+\.\d+)", "largest_profit_trade"),
        (r"Najwi[^:]{0,5}stratna transakcja:\s*([+\-]?[\d ,\xa0]+\.\d+)", "largest_loss_trade"),
        (r"Maksimum kolejne wygrane[^:]+:\s*([+\-]?\d+)\s*\(([+\-]?[\d ,\xa0]+\.\d+)\)", "max_consec_wins_pct"),
        (r"Maksimum kolejne straty[^:]+:\s*([+\-]?\d+)\s*\(([+\-]?[\d ,\xa0]+\.\d+)\)", "max_consec_losses_pct"),
        # Balance drawdown rows (Polish): two entries, Absolute then Maximal/Relative
        (r"Obsuni[^:]{0,5}Kapita[^:]{0,5}Salda:\s*([+\-]?[\d ,\xa0]+\.\d+)\s*\(([+\-]?[\d.]+)%\)", "balance_dd_max_pct"),
        (r"Obsuni[^:]{0,5}Kapita[^:]{0,5}Equity:\s*([+\-]?[\d ,\xa0]+\.\d+)\s*\(([+\-]?[\d.]+)%\)", "equity_dd_max_pct"),
        # English fallback
        (r"Total Net Profit:\s*([+\-]?[\d ,\xa0]+\.\d+)", "net_profit"),
        (r"Gross Profit:\s*([+\-]?[\d ,\xa0]+\.\d+)", "gross_profit"),
        (r"Gross Loss:\s*([+\-]?[\d ,\xa0]+\.\d+)", "gross_loss"),
        (r"Profit Factor:\s*([+\-]?[\d ,\xa0]+\.\d+)", "profit_factor"),
        (r"Expected Payoff:\s*([+\-]?[\d ,\xa0]+\.\d+)", "expected_payoff"),
        (r"Recovery Factor:\s*([+\-]?[\d ,\xa0]+\.\d+)", "recovery_factor"),
        (r"Sharpe Ratio:\s*([+\-]?[\d ,\xa0]+\.\d+)", "sharpe"),
        (r"Total Trades:\s*([+\-]?[\d ,\xa0]+)", "total_trades"),
        (r"Total Deals:\s*([+\-]?[\d ,\xa0]+)", "total_deals"),
        (r"Balance Drawdown Maximal:\s*([+\-]?[\d ,\xa0]+\.\d+)\s*\(([+\-]?[\d.]+)%\)", "balance_dd_max_pct"),
        (r"Equity Drawdown Maximal:\s*([+\-]?[\d ,\xa0]+\.\d+)\s*\(([+\-]?[\d.]+)%\)", "equity_dd_max_pct"),
    ]

    for pat, key in patterns:
        m = re.search(pat, text)
        if not m:
            continue
        # Handle paired keys (value + pct)
        if key.endswith("_pct"):
            base = key[:-4]
            v1 = _clean_num(m.group(1))
            v2 = _clean_num(m.group(2)) if m.lastindex and m.lastindex >= 2 else None
            if v1 is not None and base not in out:
                if base in ("balance_dd_max", "equity_dd_max"):
                    out[base] = v1
                    if v2 is not None:
                        out[base.replace("_max", "_rel")] = v2
                elif base in ("profit_trades", "loss_trades"):
                    out[base] = v1
                    if v2 is not None:
                        out[base + "_pct"] = v2
                elif base in ("max_consec_wins", "max_consec_losses"):
                    out[base] = v1
                    if v2 is not None:
                        out[base.replace("_consec", "_consec_value")] = v2
        else:
            v = _clean_num(m.group(1))
            if v is not None and key not in out:
                out[key] = v
    return out


def extract_metrics(html: str) -> dict[str, str | float]:
    # Try the dedicated Polish/English summary extractor first
    summary = extract_polish_summary(html)
    if summary:
        return {k: v for k, v in summary.items()}
    # Fall back to cell walker (rarely used)
    return _extract_metrics_via_cells(html)


def _extract_metrics_via_cells(html: str) -> dict[str, str | float]:
    """Walk the cells from the report and pair label:value entries.

    The layout typically alternates label-cell, value-cell pairs. Some labels
    end with `:`, some don't — we pair every cell that looks like a known
    label with its right neighbor.
    """
    p = _StatsExtractor()
    p.feed(html)
    cells = p.cells

    # Known label fragments → canonical key. Supports English + Polish MT5 builds.
    # We match on lowercase substrings (not exact) so partial matches catch
    # encoding-mangled labels.
    label_substrings: list[tuple[str, str]] = [
        # English
        ("total net profit", "net_profit"),
        ("net profit", "net_profit"),
        ("gross profit", "gross_profit"),
        ("gross loss", "gross_loss"),
        ("profit factor", "profit_factor"),
        ("expected payoff", "expected_payoff"),
        ("recovery factor", "recovery_factor"),
        ("sharpe ratio", "sharpe"),
        ("balance drawdown absolute", "balance_dd_abs"),
        ("balance drawdown maximal", "balance_dd_max"),
        ("balance drawdown relative", "balance_dd_rel"),
        ("equity drawdown absolute", "equity_dd_abs"),
        ("equity drawdown maximal", "equity_dd_max"),
        ("equity drawdown relative", "equity_dd_rel"),
        ("total trades", "total_trades"),
        ("total deals", "total_deals"),
        ("short trades", "short_trades"),
        ("long trades", "long_trades"),
        ("profit trades", "profit_trades"),
        ("loss trades", "loss_trades"),
        ("largest profit trade", "largest_profit_trade"),
        ("largest loss trade", "largest_loss_trade"),
        ("maximum consecutive wins", "max_consec_wins"),
        ("maximum consecutive losses", "max_consec_losses"),
        ("average consecutive wins", "avg_consec_wins"),
        ("average consecutive losses", "avg_consec_losses"),
        # Polish (used by RoboForex MT5 build 5833 in Polish UI). Match on
        # ASCII-stable substrings to survive cp1250↔UTF-16 round-trip mangling.
        ("zysk netto", "net_profit"),
        ("zysk brutto", "gross_profit"),
        ("strata brutto", "gross_loss"),
        ("wska", "_polish_indicator"),  # used as anchor for the next match
        ("oczekiwany payoff", "expected_payoff"),
        ("poziom depozytu", "margin_level"),
        ("obsuni", "_dd_indicator"),  # drawdown — needs context to disambiguate
        ("wszystkie transakcje", "total_trades"),
        ("wszystkie umowy", "total_deals"),
        ("short trades (wygrano", "short_trades"),
        ("long trades (wygrano", "long_trades"),
        ("najwi", "_largest_indicator"),
        ("redni", "_average_indicator"),
        ("maksimum kolejne wygrane", "max_consec_wins"),
        ("maksimum kolejne straty", "max_consec_losses"),
        ("rednia kolejne wygrane", "avg_consec_wins"),
        ("rednia kolejne straty", "avg_consec_losses"),
    ]

    metrics: dict[str, str | float] = {}
    for i, c in enumerate(cells):
        lower = c.lower().rstrip(":").strip()
        if not lower or i + 1 >= len(cells):
            continue
        raw_value = cells[i + 1]
        num = _clean_num(raw_value)
        for sub, key in label_substrings:
            if sub in lower and not key.startswith("_"):
                # Only set if not already set (first match wins, more specific labels first)
                if key not in metrics:
                    metrics[key] = num if num is not None else raw_value
                break

    # Special handling for Polish drawdown rows: they have format
    # "Wzgl. Obsuniecia Kapitalu Salda" → relative balance DD %
    # The value cell may contain "14 684.56 (28.63%)" → extract both
    for i, c in enumerate(cells):
        lower = c.lower()
        if "obsuni" in lower and i + 1 < len(cells):
            raw_v = cells[i + 1]
            if "salda" in lower or "balance" in lower:
                m = re.search(r"([\d., ]+)\s*\(?\s*(-?\d+\.\d+)%?", raw_v)
                if m and "balance_dd_max" not in metrics:
                    abs_v = _clean_num(m.group(1))
                    if abs_v is not None:
                        metrics["balance_dd_max"] = abs_v
                    rel_v = _clean_num(m.group(2))
                    if rel_v is not None:
                        metrics["balance_dd_rel"] = rel_v
            elif "equity" in lower or "kapitalu equity" in lower or "kapita" in lower:
                m = re.search(r"([\d., ]+)\s*\(?\s*(-?\d+\.\d+)%?", raw_v)
                if m and "equity_dd_max" not in metrics:
                    abs_v = _clean_num(m.group(1))
                    if abs_v is not None:
                        metrics["equity_dd_max"] = abs_v
                    rel_v = _clean_num(m.group(2))
                    if rel_v is not None:
                        metrics["equity_dd_rel"] = rel_v

    # Polish "Wskaznik Zysku" = Profit Factor; "Wskaznik Sharpe'a" = Sharpe
    for i, c in enumerate(cells):
        lower = c.lower()
        if "wska" in lower and i + 1 < len(cells):
            if "zysku" in lower and "profit_factor" not in metrics:
                v = _clean_num(cells[i + 1])
                if v is not None:
                    metrics["profit_factor"] = v
            elif "sharpe" in lower and "sharpe" not in metrics:
                v = _clean_num(cells[i + 1])
                if v is not None:
                    metrics["sharpe"] = v
            elif "odzyskania" in lower and "recovery_factor" not in metrics:
                v = _clean_num(cells[i + 1])
                if v is not None:
                    metrics["recovery_factor"] = v

    # Largest trades — Polish "najwi" prefix
    for i, c in enumerate(cells):
        lower = c.lower()
        if i + 1 >= len(cells):
            continue
        if "najwi" in lower and "zyskowna" in lower and "largest_profit_trade" not in metrics:
            v = _clean_num(cells[i + 1])
            if v is not None:
                metrics["largest_profit_trade"] = v
        elif "najwi" in lower and "stratna" in lower and "largest_loss_trade" not in metrics:
            v = _clean_num(cells[i + 1])
            if v is not None:
                metrics["largest_loss_trade"] = v

    # Profit/Loss trades counts — Polish format
    for i, c in enumerate(cells):
        lower = c.lower()
        if i + 1 >= len(cells):
            continue
        if "profit trades" in lower and "profit_trades" not in metrics:
            # value like "220 (74.83%)"
            v = _clean_num(cells[i + 1])
            if v is not None:
                metrics["profit_trades"] = v
        elif "loss trades" in lower and "loss_trades" not in metrics:
            v = _clean_num(cells[i + 1])
            if v is not None:
                metrics["loss_trades"] = v
    return metrics


def parse_trade_count_estimate(metrics: dict[str, str | float]) -> int | None:
    """Best-effort trade count from whichever field MT5 populated."""
    for key in ("total_trades", "total_deals"):
        v = metrics.get(key)
        if isinstance(v, (int, float)):
            return int(v)
    return None


def to_result_yaml(
    run_id: str,
    story_id: str,
    set_file: str,
    metrics: dict[str, str | float],
    symbol: str,
    deposit: float,
    from_date: str,
    to_date: str,
) -> str:
    """Format as result.yaml per the graph schema."""
    trades = parse_trade_count_estimate(metrics) or 0

    def f(key: str) -> str:
        v = metrics.get(key)
        if v is None:
            return "null"
        if isinstance(v, float):
            return f"{v:g}"
        return f'"{v}"'

    lines = [
        f"run_id: {run_id}",
        f"story_id: {story_id}",
        f"set_file: {set_file}",
        f"symbol: {symbol}",
        f"account_size: {deposit:g}",
        f"data_window: ['{from_date}', '{to_date}']",
        "metrics:",
        f"  net_profit: {f('net_profit')}",
        f"  profit_factor: {f('profit_factor')}",
        f"  expected_payoff: {f('expected_payoff')}",
        f"  recovery_factor: {f('recovery_factor')}",
        f"  sharpe: {f('sharpe')}",
        f"  balance_dd_max: {f('balance_dd_max')}",
        f"  balance_dd_rel: {f('balance_dd_rel')}",
        f"  equity_dd_max: {f('equity_dd_max')}",
        f"  equity_dd_rel: {f('equity_dd_rel')}",
        f"  trades: {trades}",
        f"  profit_trades: {f('profit_trades')}",
        f"  loss_trades: {f('loss_trades')}",
        f"  largest_profit_trade: {f('largest_profit_trade')}",
        f"  largest_loss_trade: {f('largest_loss_trade')}",
        f"  max_consec_losses: {f('max_consec_losses')}",
        f"  initial_deposit: {f('initial_deposit')}",
        "raw_metrics:",
    ]
    for k, v in sorted(metrics.items()):
        if isinstance(v, float):
            lines.append(f"  {k}: {v:g}")
        else:
            lines.append(f"  {k}: '{v}'")
    return "\n".join(lines) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--report", required=True, type=Path)
    ap.add_argument("--run-id", required=True)
    ap.add_argument("--story-id", default="F0")
    ap.add_argument("--set-file", default="")
    ap.add_argument("--symbol", default="XAUUSD")
    ap.add_argument("--deposit", type=float, default=0)
    ap.add_argument("--from-date", default="")
    ap.add_argument("--to-date", default="")
    ap.add_argument("--out", type=Path, default=None)
    args = ap.parse_args()

    if not args.report.exists():
        print(f"[parse] ERROR: report not found: {args.report}")
        return 2

    html = read_html(args.report)
    metrics = extract_metrics(html)
    yaml = to_result_yaml(
        run_id=args.run_id,
        story_id=args.story_id,
        set_file=args.set_file,
        metrics=metrics,
        symbol=args.symbol,
        deposit=args.deposit,
        from_date=args.from_date,
        to_date=args.to_date,
    )

    out = args.out or args.report.with_suffix(".result.yaml")
    out.write_text(yaml, encoding="utf-8")
    print(f"[parse] Wrote {out}")
    # Also dump raw JSON for inspection
    json_out = out.with_suffix(".raw.json")
    json_out.write_text(json.dumps(metrics, indent=2, default=str), encoding="utf-8")
    print(f"[parse] Wrote {json_out}")
    # Print a quick summary
    print(json.dumps(
        {k: metrics.get(k) for k in (
            "net_profit", "profit_factor", "balance_dd_max", "balance_dd_rel",
            "equity_dd_max", "equity_dd_rel", "total_trades", "profit_trades",
            "loss_trades", "max_consec_losses",
        )},
        indent=2, default=str,
    ))
    return 0


if __name__ == "__main__":
    sys.exit(main())
