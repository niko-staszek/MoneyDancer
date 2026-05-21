"""Inspect the trade-table sections in an MT5 report.htm."""

from pathlib import Path
import re

path = Path(r"C:/Users/nikof/Documents/GitHub/MoneyDancer/.claude/worktrees/reverent-panini-6271e7/runs/F0-5k-heavy-grid/F0-5k-heavy-grid-report.htm")
raw = path.read_bytes()
text = raw.decode("utf-16", errors="replace")
print(f"Total size: {len(text):,} chars")

# All occurrences of each section marker
for marker in ("Zlecenia", "Umowy", "Pozycje", "Orders", "Deals", "Positions",
               "Czas Otwarcia", "Komentarz", "Wolumen", "Cena", "Direction"):
    positions = []
    idx = 0
    while True:
        i = text.find(marker, idx)
        if i < 0: break
        positions.append(i)
        idx = i + 1
        if len(positions) > 5: break
    print(f"{marker!r:20} found at {positions}")

# Find a chunk far into the file — that's where the actual deals table should be
print()
print(f"--- chars 1,500,000-1,503,000 (deep in file) ---")
print(text[1_500_000:1_503_000])
