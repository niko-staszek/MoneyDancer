"""Scan all WT and STEP tester logs for market-closed / CRITICAL events.

Reveals which cells were affected by the S5.5f bug (basket-SL rail spinning
during XAU daily-break window).
"""
from __future__ import annotations
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
RUNS = REPO / "runs"

CELL_PREFIXES = ["S3.2b-WT-5k", "STEP-5k", "BM-STEP-5k", "STEP-OOS-5k"]


def scan_log(path: Path) -> dict:
    if not path.exists():
        return None
    try:
        # UTF-16 with embedded nulls (typical MT5 log)
        raw = path.read_bytes()
    except Exception:
        return None
    # Strip nulls and try utf-8
    text = raw.replace(b"\x00", b"").decode("utf-8", errors="ignore")

    # Find CRITICAL events
    critical = re.findall(r"\[S1\.0\] CRITICAL cannot close any positions", text)
    market_closed = re.findall(r"\[market closed\]|\[Market closed\]", text)
    warn_close = re.findall(r"\[S1\.0\] WARN series close returned 0", text)

    # Date of first CRITICAL (if any)
    first_critical_match = re.search(r"(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2}).*?\[S1\.0\] CRITICAL", text)
    first_critical_date = first_critical_match.group(1) if first_critical_match else None

    return {
        "n_critical": len(critical),
        "n_market_closed_text": len(market_closed),
        "n_warn_close_zero": len(warn_close),
        "first_critical_at": first_critical_date,
    }


def main() -> int:
    results = []
    for cell_dir in sorted(RUNS.iterdir()):
        if not cell_dir.is_dir():
            continue
        # Check if folder matches our prefix patterns
        if not any(cell_dir.name.startswith(p) for p in CELL_PREFIXES):
            continue
        # Find log file
        logs = list(cell_dir.glob("*.log"))
        if not logs:
            continue
        log = logs[0]
        scan = scan_log(log)
        if scan is None:
            continue
        # Only report cells with non-zero CRITICAL or warn-close events
        if scan["n_critical"] > 0 or scan["n_warn_close_zero"] > 0 or scan["n_market_closed_text"] > 0:
            results.append((cell_dir.name, scan))

    if not results:
        print("No cells with CRITICAL/market-closed events found.")
        return 0

    print(f"{'cell':<40} {'CRITICAL':>10} {'mkt_closed':>11} {'warn_close=0':>13} {'first':>22}")
    for name, s in results:
        first = s["first_critical_at"] or "-"
        print(f"{name:<40} {s['n_critical']:>10} {s['n_market_closed_text']:>11} {s['n_warn_close_zero']:>13} {first:>22}")
    print(f"\nTotal cells affected: {len(results)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
