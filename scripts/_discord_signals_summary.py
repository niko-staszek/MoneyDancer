"""Quick summary of the two Discord-exported signal CSVs."""
import re
import sys
from pathlib import Path
from collections import Counter

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

SIGNALS_DIR = Path('C:/Users/nikof/Documents/GitHub/signals')

# The DiscordChatExporter format wraps each row as one comma-separated CSV row,
# but Content has embedded newlines. Each new logical row starts with `"<AuthorID>,`.
ROW_START = re.compile(r'^"(\d{18,20}),"')


def split_records(text: str) -> list[str]:
    """Split the CSV into per-message records based on the AuthorID prefix."""
    lines = text.splitlines()
    records, cur = [], []
    for ln in lines[1:]:  # skip header
        if ROW_START.match(ln):
            if cur:
                records.append('\n'.join(cur))
            cur = [ln]
        else:
            cur.append(ln)
    if cur:
        records.append('\n'.join(cur))
    return records


for fname in ['signals1.csv', 'tnfx.csv']:
    path = SIGNALS_DIR / fname
    text = path.read_text(encoding='utf-8', errors='replace')
    records = split_records(text)
    print(f'=== {fname}: {len(records)} records ===')

    # Extract author + date + symbol + side
    side_counter = Counter()
    sym_counter = Counter()
    authors = Counter()
    dates = []
    for r in records[:5]:
        print(f'  --- sample ---')
        print('  ' + r[:300].replace('\n', ' | '))
        print()
    for r in records:
        # author
        a = re.search(r'"\d+","([^"]+)"', r)
        if a:
            authors[a.group(1)] += 1
        # date
        d = re.search(r'"(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+[+-]\d{2}:\d{2})"', r)
        if d:
            dates.append(d.group(1))
        # symbol
        sym = re.search(r'(XAUUSD|BTCUSD|ETHUSD|EURUSD|GBPUSD|EURAUD|USDJPY|XAGUSD|NAS100|US30|US100|GER40)', r)
        if sym:
            sym_counter[sym.group(1)] += 1
        # side
        if re.search(r'(SELL|🔴)', r) and not re.search(r'(BUY|🟢)', r):
            side_counter['SELL'] += 1
        elif re.search(r'(BUY|🟢)', r):
            side_counter['BUY'] += 1

    print(f'  Authors: {dict(authors)}')
    print(f'  Symbols: {dict(sym_counter)}')
    print(f'  Sides:   {dict(side_counter)}')
    if dates:
        print(f'  Date range: {min(dates)} -> {max(dates)}')
    print()
