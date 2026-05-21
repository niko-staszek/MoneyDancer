"""Per-cell burst frequency, tick density, and burst follow-through.

Burst = N consecutive ticks within a tight time window with cumulative
move >= MinMovePoints. Simulates the EA's tick-burst detector.

Outputs per cell:
- ticks_per_min: raw tick density
- bursts_per_hour: count of detected bursts (matching EA params)
- mean_burst_move: average movement size at burst trigger
- followthrough_pct: % of bursts where price continued ≥TP_Points within 5 min
"""
from __future__ import annotations
import csv
import sys
from collections import deque
from datetime import datetime, timedelta
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

# EA params from ship .set
BURST_TICKS = 14            # ticks in window
BURST_WINDOW_SEC = 11       # TickRateLookbackSec
MIN_MOVE_POINTS = 25        # MinMovePoints
TP_POINTS = 60              # TP_Points
FOLLOWTHROUGH_WINDOW = 300  # 5 min to consider follow-through
POINT = 0.01                # XAUUSD 2-digit point size

CELLS_2025 = [
    ("jan25", "2025-01-01", "2025-01-15"),
    ("feb25", "2025-02-01", "2025-02-15"),
    ("mar25", "2025-03-01", "2025-03-15"),
    ("apr25", "2025-04-01", "2025-04-15"),
    ("may25", "2025-05-01", "2025-05-15"),
    ("jun25", "2025-06-01", "2025-06-15"),
    ("jul25", "2025-07-01", "2025-07-15"),
    ("aug25", "2025-08-01", "2025-08-15"),
    ("sep25", "2025-09-01", "2025-09-15"),
    ("oct25", "2025-10-01", "2025-10-15"),
    ("nov25", "2025-11-01", "2025-11-15"),
    ("dec25", "2025-12-01", "2025-12-15"),
]
CELLS_2026 = [
    ("jan26", "2026-01-01", "2026-01-15"),
    ("feb26", "2026-02-01", "2026-02-15"),
    ("mar26", "2026-03-01", "2026-03-15"),
    ("apr26", "2026-04-01", "2026-04-15"),
    ("may26", "2026-05-01", "2026-05-15"),
]


def parse_ts(s: str) -> datetime | None:
    try:
        return datetime.strptime(s[:19], "%Y-%m-%d %H:%M:%S")
    except ValueError:
        return None


def analyze_cell(ticks: list, label: str) -> dict:
    """ticks: list of (datetime, mid_price) sorted by time."""
    if not ticks:
        return {"label": label, "n_ticks": 0}

    duration_min = (ticks[-1][0] - ticks[0][0]).total_seconds() / 60.0
    if duration_min <= 0:
        return {"label": label, "n_ticks": 0}

    # Simulate burst detection using sliding window
    bursts = []  # (timestamp, dir, move_pts, peak_idx, end_idx)
    window: deque = deque(maxlen=BURST_TICKS)
    last_burst_time = None
    cooldown_sec = 15  # CooldownSec

    for idx, (ts, mid) in enumerate(ticks):
        window.append((ts, mid))
        if len(window) < BURST_TICKS:
            continue
        first_ts, first_mid = window[0]
        if (ts - first_ts).total_seconds() > BURST_WINDOW_SEC:
            continue
        move = mid - first_mid
        move_pts = abs(move) / POINT
        if move_pts < MIN_MOVE_POINTS:
            continue
        # Cooldown check
        if last_burst_time and (ts - last_burst_time).total_seconds() < cooldown_sec:
            continue
        bursts.append((ts, +1 if move > 0 else -1, move_pts, idx, first_mid, mid))
        last_burst_time = ts

    # Follow-through: did price continue in burst direction ≥ TP_Points within 5 min?
    followthroughs = 0
    for b_ts, b_dir, b_move, b_idx, _, b_mid in bursts:
        # Look at ticks within 5 min after burst
        target = b_mid + (b_dir * TP_POINTS * POINT)
        hit = False
        for j in range(b_idx + 1, min(b_idx + 5000, len(ticks))):
            t_ts, t_mid = ticks[j]
            if (t_ts - b_ts).total_seconds() > FOLLOWTHROUGH_WINDOW:
                break
            if b_dir > 0 and t_mid >= target:
                hit = True
                break
            if b_dir < 0 and t_mid <= target:
                hit = True
                break
        if hit:
            followthroughs += 1

    return {
        "label": label,
        "n_ticks": len(ticks),
        "duration_min": duration_min,
        "ticks_per_min": len(ticks) / duration_min,
        "n_bursts": len(bursts),
        "bursts_per_hour": len(bursts) / (duration_min / 60.0) if duration_min > 0 else 0,
        "mean_burst_move": sum(b[2] for b in bursts) / len(bursts) if bursts else 0,
        "followthroughs": followthroughs,
        "followthrough_pct": (followthroughs / len(bursts) * 100) if bursts else 0,
    }


def process_csv(csv_path: Path, cells: list, out: dict) -> None:
    cell_ranges = [(label, f"{f} 00:00:00", f"{t} 00:00:00") for label, f, t in cells]
    # Per-cell tick lists
    cell_ticks: dict[str, list] = {label: [] for label, _, _ in cells}

    with csv_path.open(encoding="utf-8") as f:
        rdr = csv.reader(f)
        next(rdr, None)
        for row in rdr:
            if len(row) < 3:
                continue
            ts_str = row[0]
            if not ts_str:
                continue
            in_label = None
            for label, from_s, to_s in cell_ranges:
                if from_s <= ts_str < to_s:
                    in_label = label
                    break
            if in_label is None:
                continue
            ts = parse_ts(ts_str)
            if ts is None:
                continue
            try:
                bid = float(row[1])
                ask = float(row[2])
            except (ValueError, IndexError):
                continue
            cell_ticks[in_label].append((ts, (bid + ask) / 2.0))

    for label, _, _ in cells:
        out[label] = analyze_cell(cell_ticks[label], label)


def main() -> int:
    results = {}
    print("Processing 2025 ticks...", file=sys.stderr)
    process_csv(REPO / "data" / "duka" / "XAUUSD_2025_robo.csv", CELLS_2025, results)
    print("Processing 2026 ticks...", file=sys.stderr)
    process_csv(REPO / "data" / "duka" / "XAUUSD_2026_jan-may_robo.csv", CELLS_2026, results)

    print(f"\n{'cell':<6} {'ticks/min':>10} {'bursts/hr':>10} {'mean_move':>10} {'follow%':>8}")
    for label, _, _ in CELLS_2025 + CELLS_2026:
        r = results.get(label)
        if not r or r.get("n_ticks", 0) == 0:
            print(f"{label}:  MISSING / empty")
            continue
        print(
            f"{label:<6} {r['ticks_per_min']:>10.1f} {r['bursts_per_hour']:>10.1f} "
            f"{r['mean_burst_move']:>10.1f} {r['followthrough_pct']:>7.1f}%"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
