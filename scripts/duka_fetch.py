"""Download Dukascopy BI5 tick files and decode them to CSV.

Dukascopy public datafeed URL pattern (UTC time, 0-indexed month and day):
  https://datafeed.dukascopy.com/datafeed/{SYMBOL}/{YEAR}/{MM-1:02d}/{DD-1:02d}/{HH:02d}h_ticks.bi5

Each BI5 file is LZMA-compressed. Decoded body is N × 20-byte ticks, each:
  uint32 BE   time offset (ms from hour start)
  uint32 BE   ask × point_scale
  uint32 BE   bid × point_scale
  float32 BE  ask volume
  float32 BE  bid volume

point_scale for XAUUSD = 1000 (3 decimal places). For 5-digit forex = 100000.

CSV output columns: utc_datetime,bid,ask,bid_vol,ask_vol
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import lzma
import struct
import sys
import time
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


# Point scales per symbol
POINT_SCALES: dict[str, float] = {
    "XAUUSD": 1000.0,    # 3 digits
    "XAGUSD": 1000.0,
    "EURUSD": 100000.0,  # 5 digits
    "GBPUSD": 100000.0,
    "USDJPY": 1000.0,
    "AUDUSD": 100000.0,
    "USDCAD": 100000.0,
    "USDCHF": 100000.0,
    "NZDUSD": 100000.0,
}


def url_for(symbol: str, when: dt.datetime) -> str:
    return (
        f"https://datafeed.dukascopy.com/datafeed/{symbol}/"
        f"{when.year}/{when.month - 1:02d}/{when.day - 1:02d}/"
        f"{when.hour:02d}h_ticks.bi5"
    )


def fetch_one_hour(symbol: str, when: dt.datetime, cache_root: Path,
                   timeout: int = 30, retries: int = 3) -> bytes | None:
    """Return BI5 bytes for the given UTC hour. Caches locally."""
    cache_path = (
        cache_root / symbol /
        f"{when.year}" / f"{when.month:02d}" / f"{when.day:02d}" /
        f"{when.hour:02d}h_ticks.bi5"
    )
    if cache_path.exists():
        return cache_path.read_bytes()

    url = url_for(symbol, when)
    last_err: Exception | None = None
    for attempt in range(retries):
        try:
            req = Request(url, headers={"User-Agent": "Mozilla/5.0 MoneyDancerF0/1.0"})
            with urlopen(req, timeout=timeout) as r:
                data = r.read()
            cache_path.parent.mkdir(parents=True, exist_ok=True)
            cache_path.write_bytes(data)
            return data
        except HTTPError as e:
            if e.code == 404:
                # Some hours have no data (weekends). Treat as empty.
                cache_path.parent.mkdir(parents=True, exist_ok=True)
                cache_path.write_bytes(b"")
                return b""
            last_err = e
            time.sleep(1 + attempt)
        except (URLError, TimeoutError) as e:
            last_err = e
            time.sleep(2 + attempt * 2)
    print(f"[duka] FAIL {url}: {last_err}")
    return None


def decode_bi5(data: bytes, point_scale: float, hour_start: dt.datetime) -> list[dict]:
    """Decompress LZMA-encoded BI5 and parse 20-byte ticks."""
    if not data:
        return []
    try:
        raw = lzma.decompress(data)
    except lzma.LZMAError:
        # Some files (~zero-tick hours) come uncompressed
        raw = data
    ticks: list[dict] = []
    for i in range(0, len(raw), 20):
        chunk = raw[i:i + 20]
        if len(chunk) < 20:
            break
        # Big-endian: uint32, uint32, uint32, float32, float32
        ms, ask_i, bid_i, ask_v, bid_v = struct.unpack(">IIIff", chunk)
        ts = hour_start + dt.timedelta(milliseconds=ms)
        ticks.append({
            "utc_datetime": ts.strftime("%Y-%m-%d %H:%M:%S.") + f"{ms % 1000:03d}",
            "bid": bid_i / point_scale,
            "ask": ask_i / point_scale,
            "bid_vol": bid_v,
            "ask_vol": ask_v,
        })
    return ticks


def fetch_range(symbol: str, start: dt.datetime, end: dt.datetime,
                cache_root: Path, workers: int = 8) -> list[dict]:
    """Fetch every hour from start (inclusive) to end (exclusive). Threaded."""
    from concurrent.futures import ThreadPoolExecutor, as_completed
    scale = POINT_SCALES.get(symbol)
    if scale is None:
        raise ValueError(f"unknown point scale for {symbol}")

    # Build the hour list
    cur = start.replace(minute=0, second=0, microsecond=0)
    hours: list[dt.datetime] = []
    while cur < end:
        hours.append(cur)
        cur += dt.timedelta(hours=1)
    print(f"[duka] fetching {len(hours)} hours of {symbol} with {workers} workers")

    by_hour: dict[dt.datetime, bytes | None] = {}
    done = 0
    with ThreadPoolExecutor(max_workers=workers) as ex:
        futs = {ex.submit(fetch_one_hour, symbol, h, cache_root): h for h in hours}
        for fut in as_completed(futs):
            h = futs[fut]
            try:
                by_hour[h] = fut.result()
            except Exception as e:
                print(f"[duka] exception for {h}: {e}")
                by_hour[h] = None
            done += 1
            if done % 100 == 0 or done == len(hours):
                non_empty = sum(1 for d in by_hour.values() if d)
                print(f"[duka] {done}/{len(hours)} (non-empty: {non_empty})")

    # Decode in chronological order
    all_ticks: list[dict] = []
    for h in hours:
        data = by_hour.get(h)
        if not data:
            continue
        all_ticks.extend(decode_bi5(data, scale, h))
    print(f"[duka] decoded {len(all_ticks)} total ticks")
    return all_ticks


def write_csv(ticks: list[dict], out: Path) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=["utc_datetime", "bid", "ask", "bid_vol", "ask_vol"])
        w.writeheader()
        w.writerows(ticks)
    print(f"[duka] wrote {len(ticks)} ticks to {out}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--symbol", default="XAUUSD")
    ap.add_argument("--start", required=True, help="YYYY-MM-DD UTC")
    ap.add_argument("--end", required=True, help="YYYY-MM-DD UTC (exclusive)")
    ap.add_argument("--out", required=True, type=Path)
    ap.add_argument("--cache-dir", default="data/duka_cache", type=Path)
    args = ap.parse_args()

    start = dt.datetime.fromisoformat(args.start).replace(tzinfo=dt.timezone.utc)
    end = dt.datetime.fromisoformat(args.end).replace(tzinfo=dt.timezone.utc)
    # Use naive for hour math (Dukascopy URLs are UTC by convention)
    start = start.replace(tzinfo=None)
    end = end.replace(tzinfo=None)

    ticks = fetch_range(args.symbol, start, end, args.cache_dir)
    write_csv(ticks, args.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
