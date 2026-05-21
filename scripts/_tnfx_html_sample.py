"""Pull a few sample signal messages from each TG HTML page to see format variation."""
import re, sys
from pathlib import Path
from html.parser import HTMLParser

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

SRC = Path("C:/Users/nikof/Downloads/Telegram Desktop/ChatExport_2026-05-16")
FILES = sorted(SRC.glob("messages*.html"), key=lambda p: int(re.findall(r'\d+', p.stem)[0]) if re.findall(r'\d+', p.stem) else 0)

# Crude extractor: find <div class="text"> blocks containing TP1
TEXT_BLOCK = re.compile(r'<div class="text">(.*?)</div>', re.DOTALL)
TAG = re.compile(r'<[^>]+>')

def clean(html_text: str) -> str:
    s = TAG.sub('', html_text)
    s = (s.replace('&nbsp;', ' ').replace('&laquo;', '"').replace('&raquo;', '"')
           .replace('&amp;', '&').replace('&lt;', '<').replace('&gt;', '>'))
    return re.sub(r'\n\s*\n', '\n', s).strip()

print(f'Files: {len(FILES)} (first={FILES[0].name}, last={FILES[-1].name})')
for fp in [FILES[0], FILES[len(FILES)//4], FILES[len(FILES)//2], FILES[3*len(FILES)//4], FILES[-1]]:
    print(f'\n========== {fp.name} ==========')
    text = fp.read_text(encoding='utf-8', errors='replace')
    blocks = TEXT_BLOCK.findall(text)
    sig_blocks = [b for b in blocks if 'TP1' in b]
    print(f'  {len(blocks)} text blocks total, {len(sig_blocks)} contain TP1')
    for b in sig_blocks[:3]:
        c = clean(b)
        print('  ---')
        for line in c.splitlines()[:18]:
            print(f'    {line}')
