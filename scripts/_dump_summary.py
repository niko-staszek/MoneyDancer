from pathlib import Path
import re

raw = Path(r"C:/Users/nikof/Documents/GitHub/MoneyDancer/.claude/worktrees/reverent-panini-6271e7/runs/F0-35k-pyramid/F0-35k-pyramid-report.htm").read_bytes()
text = raw.decode("utf-16", errors="replace")

# Find a chunk around "Wynik" (Results) section
idx = text.find("Wynik")
if idx < 0:
    idx = text.find("Result")
if idx >= 0:
    snippet = text[idx: idx + 8000]
    # Strip tags
    clean = re.sub(r"<[^>]+>", " ", snippet)
    clean = re.sub(r"\s+", " ", clean)
    print(clean[:3000])
