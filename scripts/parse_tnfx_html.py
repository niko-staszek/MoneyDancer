#!/usr/bin/env python3
"""
Parse the TNFX Telegram Desktop HTML chat-export folder into a clean signal CSV.

The TNFX format varies wildly across Nov 2022 - May 2026:
  - early:  "USDCHFBUY: 0.9498TP1:0.9520TP2:...SL- 0.9450"  (no spaces, glued)
  - mid:    "BUY XAUUSD 3011.5-3009TP1 3013TP2 3016..."  (range entry, no colons)
  - recent: "SIGNAL ALERT! BUY XAUUSD 4113.56-4111.56TP1: 4115.06 ... SL: 4106.56"

Strategy:
  1. Walk each <div class="message default"> block
  2. Extract date from `title="DD.MM.YYYY HH:MM:SS UTC+ZZ:ZZ"` attribute
  3. Strip emojis/HTML, normalize, run a tolerant regex stack
  4. Require symbol + direction + entry + SL + >=1 TP to count as a signal
  5. Range entries -> midpoint (most realistic for limit-with-tolerance copying)
  6. Write the same 9-column CSV format the EA already consumes
"""
import argparse
import csv
import re
import sys
from collections import Counter
from pathlib import Path
from datetime import datetime, timezone, timedelta

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

DEFAULT_SRC = Path('C:/Users/nikof/Downloads/Telegram Desktop/ChatExport_2026-05-16')

# ===== Symbol aliasing =====
SYMBOL_ALIASES = {
    'XAUUSD': ['XAUUSD', 'XAU/USD', 'GOLD'],
    'BTCUSD': ['BTCUSD', 'BTC/USD', 'BITCOIN'],
    'ETHUSD': ['ETHUSD', 'ETH/USD', 'ETHEREUM'],
    'EURUSD': ['EURUSD', 'EUR/USD'],
    'GBPUSD': ['GBPUSD', 'GBP/USD'],
    'USDJPY': ['USDJPY', 'USD/JPY'],
    'USDCHF': ['USDCHF', 'USD/CHF'],
    'AUDUSD': ['AUDUSD', 'AUD/USD'],
    'NZDUSD': ['NZDUSD', 'NZD/USD'],
    'USDCAD': ['USDCAD', 'USD/CAD'],
    'EURGBP': ['EURGBP', 'EUR/GBP'],
    'EURJPY': ['EURJPY', 'EUR/JPY'],
    'GBPJPY': ['GBPJPY', 'GBP/JPY'],
    'EURAUD': ['EURAUD', 'EUR/AUD'],
    'AUDNZD': ['AUDNZD', 'AUD/NZD'],
    'AUDCAD': ['AUDCAD', 'AUD/CAD'],
    'CADJPY': ['CADJPY', 'CAD/JPY'],
    'NZDJPY': ['NZDJPY', 'NZD/JPY'],
    'XAGUSD': ['XAGUSD', 'XAG/USD', 'SILVER'],
    'NAS100': ['NAS100', 'NASDAQ', 'US100'],
    'US30':   ['US30', 'DOWJONES', 'DOW'],
    'SPX500': ['SPX500', 'SP500', 'US500'],
}

# ===== Regex stack =====
TAG = re.compile(r'<[^>]+>', re.DOTALL)
HTML_ENT = {'&nbsp;': ' ', '&amp;': '&', '&lt;': '<', '&gt;': '>', '&apos;': "'",
            '&quot;': '"', '&laquo;': '"', '&raquo;': '"'}
DATE_TITLE = re.compile(r'title="(\d{2}\.\d{2}\.\d{4} \d{2}:\d{2}:\d{2}) UTC([+-]\d{2}:\d{2})"')
# Match a message default block (with optional joined-style continuation messages — they share author with previous)
MESSAGE = re.compile(
    r'<div class="message default clearfix(?: joined)?" id="message(\d+)">(.*?)(?=<div class="message |</div>\s*</div>\s*</div>\s*<script)',
    re.DOTALL
)
TEXT_DIV = re.compile(r'<div class="text">(.*?)</div>', re.DOTALL)

DIRECTION_RE = re.compile(r'\b(BUY|SELL|LONG|SHORT)\b', re.IGNORECASE)
SL_RE = re.compile(r'\bSL[\s:\-]*([0-9]+\.?[0-9]*)', re.IGNORECASE)
TP_RE = re.compile(r'\bTP\s*(\d+)[\s:]*([0-9]+\.?[0-9]*)', re.IGNORECASE)
NUMBER_RE = re.compile(r'([0-9]+\.?[0-9]+)')


def clean_html_text(html: str) -> str:
    """HTML -> plain text with emojis removed but punctuation preserved."""
    s = TAG.sub(' ', html)
    for k, v in HTML_ENT.items():
        s = s.replace(k, v)
    # Replace common emoji codepoints with spaces (don't strip — preserve token gaps)
    out = []
    for ch in s:
        if ch.isascii() and (ch.isalnum() or ch in ' .,:;/-_()@%+\n\t#'):
            out.append(ch)
        elif ch in '|\\':
            out.append(' ')
        else:
            out.append(' ')   # anything non-ASCII -> space
    s = ''.join(out)
    s = re.sub(r'[ \t]+', ' ', s)
    s = re.sub(r'\n\s*\n', '\n', s)
    return s.strip()


def normalize_symbol(text_upper: str) -> str | None:
    for canon, aliases in SYMBOL_ALIASES.items():
        for alias in aliases:
            if alias in text_upper:
                return canon
    return None


def parse_signal_text(text: str) -> dict | None:
    """Try to parse one cleaned text block as a signal. None if not a tradable signal."""
    if not text:
        return None
    upper = text.upper()

    # Symbol
    symbol = normalize_symbol(upper)
    if not symbol:
        return None

    # Direction
    dir_match = DIRECTION_RE.search(upper)
    if not dir_match:
        return None
    direction_raw = dir_match.group(1).upper()
    side = 'BUY' if direction_raw in ('BUY', 'LONG') else 'SELL'

    # TPs (must have at least one to count as a signal — filters out "TP1 hit" status messages)
    tp_pairs = TP_RE.findall(text)
    if not tp_pairs:
        return None

    # Filter implausible TPs (e.g. "TP1: 1 pip", where 1 is a label not price)
    tps_by_idx = {}
    for idx_str, val_str in tp_pairs:
        try:
            i = int(idx_str)
            v = float(val_str)
            if v > 0:
                tps_by_idx[i] = v
        except ValueError:
            continue
    if not tps_by_idx:
        return None
    tps = [tps_by_idx[i] for i in sorted(tps_by_idx.keys())][:15]

    # SL (REQUIRED)
    sl_m = SL_RE.search(text)
    if not sl_m:
        return None
    try:
        sl = float(sl_m.group(1))
    except ValueError:
        return None
    if sl <= 0:
        return None

    # Entry: take the first number that appears AFTER the symbol/direction tokens but
    # BEFORE the first TP token. Handles "BUY XAUUSD 4113.56-4111.56 TP1: ..." pattern.
    # Find position after the later of: end of symbol, end of direction.
    sym_pos = upper.find(SYMBOL_ALIASES[symbol][0])
    for alias in SYMBOL_ALIASES[symbol]:
        p = upper.find(alias)
        if p >= 0:
            sym_pos = max(sym_pos, p + len(alias))
            break
    dir_pos = dir_match.end()
    start = max(sym_pos, dir_pos)
    # Limit search up to first TP, SL, or end
    tp_pos = re.search(r'\bTP\s*\d', text[start:], re.IGNORECASE)
    sl_pos_match = re.search(r'\bSL\b', text[start:], re.IGNORECASE)
    end = len(text)
    if tp_pos:
        end = min(end, start + tp_pos.start())
    if sl_pos_match:
        end = min(end, start + sl_pos_match.start())

    entry_chunk = text[start:end]
    nums = NUMBER_RE.findall(entry_chunk)
    if not nums:
        return None

    # Range or single? If two numbers in chunk, treat as range -> midpoint
    try:
        if len(nums) >= 2:
            a, b = float(nums[0]), float(nums[1])
            # Sanity: both within same order of magnitude (rules out "BUY XAU 4113 at 11:30")
            if min(a, b) > 0 and max(a, b) / min(a, b) < 1.05:
                entry = (a + b) / 2.0
            else:
                entry = float(nums[0])
        else:
            entry = float(nums[0])
    except ValueError:
        return None
    if entry <= 0:
        return None

    # SL side validation (cheap typo guard — wrong-side SL is rejected here)
    if side == 'BUY' and sl >= entry:
        return None
    if side == 'SELL' and sl <= entry:
        return None

    # TPs sanity: at least TP1 should be on the right side of entry
    if side == 'BUY' and tps[0] <= entry:
        return None
    if side == 'SELL' and tps[0] >= entry:
        return None

    return {
        'symbol': symbol, 'side': side,
        'entry': entry, 'sl': sl, 'tps': tps,
    }


def parse_export_dir(src_dir: Path, channel_alias: str, only_symbol: str | None = 'XAUUSD'):
    """Walk all messages*.html files, parse signals, return list of dicts."""
    files = sorted(src_dir.glob('messages*.html'),
                   key=lambda p: (0 if p.stem == 'messages' else int(re.findall(r'\d+', p.stem)[0])))
    if not files:
        raise FileNotFoundError(f'No messages*.html in {src_dir}')

    signals = []
    fmt_counter = Counter()
    skip_reason = Counter()
    next_id = 0

    for fp in files:
        html = fp.read_text(encoding='utf-8', errors='replace')
        for mid, block in MESSAGE.findall(html):
            # Date for this message
            d = DATE_TITLE.search(block)
            if not d:
                skip_reason['no-date'] += 1
                continue
            dt_str, tz_str = d.group(1), d.group(2)   # "11.05.2026 17:22:48", "+01:00"
            try:
                naive = datetime.strptime(dt_str, '%d.%m.%Y %H:%M:%S')
            except ValueError:
                skip_reason['bad-date'] += 1
                continue
            offset_h = int(tz_str[:3])
            offset_m = int(tz_str[0] + tz_str[4:6])  # honor sign
            offset = timedelta(hours=offset_h, minutes=offset_m)
            time_utc = naive - offset  # local -> UTC
            time_utc = time_utc.replace(tzinfo=timezone.utc)

            # Text block(s)
            for raw_text in TEXT_DIV.findall(block):
                clean = clean_html_text(raw_text)
                parsed = parse_signal_text(clean)
                if parsed is None:
                    continue
                if only_symbol and parsed['symbol'] != only_symbol:
                    fmt_counter[f'skipped-symbol-{parsed["symbol"]}'] += 1
                    continue
                signals.append({
                    'id': next_id,
                    'time_utc': time_utc,
                    'channel': channel_alias,
                    'symbol': parsed['symbol'],
                    'side': parsed['side'],
                    'entry': parsed['entry'],
                    'sl': parsed['sl'],
                    'tps': parsed['tps'],
                })
                next_id += 1
                fmt_counter[f'parsed-{parsed["symbol"]}'] += 1
    return signals, fmt_counter, skip_reason


def write_csv(signals: list, out_path: Path):
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, 'w', newline='', encoding='ascii') as f:
        w = csv.writer(f)
        w.writerow(['id', 'time_mt5', 'channel', 'symbol', 'side', 'entry', 'sl', 'n_tps', 'tps'])
        for s in signals:
            mt5_time = s['time_utc'].strftime('%Y.%m.%d %H:%M:%S')
            tps_str = '|'.join(f'{t:.5f}' for t in s['tps'])
            w.writerow([s['id'], mt5_time, s['channel'], s['symbol'], s['side'],
                        f'{s["entry"]:.5f}', f'{s["sl"]:.5f}', len(s['tps']), tps_str])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--src', type=Path, default=DEFAULT_SRC,
                    help='TG Desktop ChatExport folder containing messages*.html')
    ap.add_argument('--out', type=Path, required=True,
                    help='Destination CSV path')
    ap.add_argument('--channel', default='TNFXFULL',
                    help='Channel alias for MT order comments (default TNFXFULL)')
    ap.add_argument('--symbol', default='XAUUSD',
                    help='Only export this symbol; empty = all')
    args = ap.parse_args()

    sym = args.symbol if args.symbol else None
    print(f'Parsing {args.src}')
    sigs, fmt, skip = parse_export_dir(args.src, args.channel, only_symbol=sym)
    print(f'\nParsed {len(sigs)} signals')
    print(f'Format counters: {dict(fmt.most_common(20))}')
    print(f'Skip reasons:    {dict(skip)}')

    if sigs:
        dates = [s['time_utc'] for s in sigs]
        print(f'Date range: {min(dates)} -> {max(dates)}')
        sides = Counter(s['side'] for s in sigs)
        print(f'Sides: {dict(sides)}')
        # Per-year counts
        years = Counter(s['time_utc'].year for s in sigs)
        print(f'Per-year:   {dict(sorted(years.items()))}')

    write_csv(sigs, args.out)
    print(f'\nWrote {args.out}')


if __name__ == '__main__':
    main()
