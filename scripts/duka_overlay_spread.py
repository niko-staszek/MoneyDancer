"""Overlay broker-style spread distribution onto Dukascopy tick CSV.

Preserves mid-price exactly (so price action is unchanged) and rewrites
bid/ask so the resulting spread distribution matches a target broker
(RoboForex-Pro on 100k or Axi on 1k). Each tick's spread percentile in the
source distribution is mapped to the equivalent percentile in the target
distribution -- so news spikes still spike, just to the target broker's scale.

Output CSV schema matches input: utc_datetime,bid,ask,bid_vol,ask_vol.

Usage:
    python duka_overlay_spread.py \
        --input  data/duka/XAUUSD_2026_jan-may.csv \
        --output data/duka/XAUUSD_2026_jan-may_robo.csv \
        --target robo
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
import pandas as pd


# Target spread distributions in MT5 points (1 pt = $0.01 on 2-digit gold).
# Numbers are reasonable estimates from user-stated medians + plausible
# quantile shapes for retail brokers. Refine when real RoboForex / Axi
# tick captures arrive (F3 open item).
TARGETS: dict[str, dict[str, list[float]]] = {
    "robo": {  # RoboForex-Pro (100k account); user-reported 20-35 pts typical
        "percentiles": [0.05, 0.10, 0.25, 0.50, 0.75, 0.90, 0.95, 0.99],
        "spreads_pts": [16,   18,   22,   25,   30,   40,   55,   80],
    },
    "axi": {   # Axi (1k account); user-reported 16-18 pts typical
        "percentiles": [0.05, 0.10, 0.25, 0.50, 0.75, 0.90, 0.95, 0.99],
        "spreads_pts": [11,   13,   15,   17,   22,   30,   40,   55],
    },
}

POINT_SIZE = 0.01  # dollars per point on 2-digit gold after MT5 import


def sample_source_spreads(input_path: Path, sample_every: int) -> np.ndarray:
    """Return source spreads (in MT5 points) sampled every Nth row."""
    print(f"[overlay] sampling source spreads (1 of every {sample_every} rows)")
    df = pd.read_csv(
        input_path,
        usecols=["bid", "ask"],
        skiprows=lambda i: i > 0 and ((i - 1) % sample_every != 0),
    )
    spreads_pts = ((df["ask"] - df["bid"]) / POINT_SIZE).round().astype(np.int32).to_numpy()
    spreads_pts = spreads_pts[spreads_pts >= 0]
    print(
        f"[overlay] sampled {len(spreads_pts):,} spreads -> "
        f"median={int(np.median(spreads_pts))} "
        f"p75={int(np.percentile(spreads_pts, 75))} "
        f"p90={int(np.percentile(spreads_pts, 90))} "
        f"p99={int(np.percentile(spreads_pts, 99))} pts"
    )
    return spreads_pts


def build_lookup_table(source_spreads: np.ndarray, target_name: str,
                       lut_size: int = 1001) -> np.ndarray:
    """Index = src spread (pts), value = remapped target spread (pts)."""
    target = TARGETS[target_name]
    sorted_src = np.sort(source_spreads)
    n = len(sorted_src)
    tgt_pcts = np.asarray(target["percentiles"])
    tgt_vals = np.asarray(target["spreads_pts"], dtype=np.float64)

    indices = np.arange(lut_size)
    ranks = np.searchsorted(sorted_src, indices, side="right") / n
    lut = np.interp(ranks, tgt_pcts, tgt_vals)
    return lut


def overlay(input_path: Path, output_path: Path, target_name: str,
            sample_every: int, chunksize: int) -> None:
    src_spreads = sample_source_spreads(input_path, sample_every)
    lut = build_lookup_table(src_spreads, target_name)
    lut_max = len(lut) - 1

    target = TARGETS[target_name]
    tgt_median = target["spreads_pts"][target["percentiles"].index(0.50)]
    print(f"[overlay] target '{target_name}': median={tgt_median} pts")
    print(f"[overlay] modulating -> {output_path}")
    output_path.parent.mkdir(parents=True, exist_ok=True)

    written = 0
    written_million = 0
    first_chunk = True
    for chunk in pd.read_csv(input_path, chunksize=chunksize):
        mid = (chunk["bid"] + chunk["ask"]) / 2.0
        src_pts = ((chunk["ask"] - chunk["bid"]) / POINT_SIZE).round().astype(np.int64)
        idx = src_pts.clip(0, lut_max).to_numpy()
        tgt_pts = lut[idx]
        half = tgt_pts * POINT_SIZE / 2.0
        new_bid = (mid - half).round(3)
        new_ask = (mid + half).round(3)
        chunk["bid"] = new_bid.map("{:.3f}".format)
        chunk["ask"] = new_ask.map("{:.3f}".format)

        chunk.to_csv(
            output_path,
            mode="w" if first_chunk else "a",
            header=first_chunk,
            index=False,
        )
        first_chunk = False
        written += len(chunk)
        cur_million = written // 1_000_000
        if cur_million != written_million:
            print(f"  ...{written:,} ticks")
            written_million = cur_million

    print(f"[overlay] done. {written:,} ticks -> {output_path}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True, type=Path,
                    help="Source Dukascopy CSV (utc_datetime,bid,ask,bid_vol,ask_vol)")
    ap.add_argument("--output", required=True, type=Path,
                    help="Output CSV with modulated spreads")
    ap.add_argument("--target", required=True, choices=sorted(TARGETS.keys()),
                    help="Target broker spread profile")
    ap.add_argument("--sample-every", type=int, default=70,
                    help="Sample 1 of every N rows for source distribution "
                         "(default 70 -> ~500k from 36M ticks)")
    ap.add_argument("--chunksize", type=int, default=500_000,
                    help="Pandas read_csv chunk size")
    args = ap.parse_args()

    overlay(args.input, args.output, args.target,
            args.sample_every, args.chunksize)
    return 0


if __name__ == "__main__":
    sys.exit(main())
