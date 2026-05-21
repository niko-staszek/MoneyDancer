"""Quick inspection of tester log line format."""

from pathlib import Path

path = Path(
    r"C:/Users/nikof/AppData/Roaming/MetaQuotes/Terminal"
    r"/5FFA568149E88FCD5B44D926DCFEAA79/Tester/logs/20260514.log"
)
raw = path.read_bytes()[:4000]
text = raw.decode("utf-16", errors="replace")
print("--- first 5 lines (decoded) ---")
for line in text.splitlines()[:5]:
    print(repr(line))
print()
print("--- search for 'deal performed' ---")
for line in text.splitlines():
    if "deal performed" in line:
        print(repr(line))
        break

# Also pull a chunk further in
big = path.read_bytes()
text_all = big.decode("utf-16", errors="replace")
print()
print("--- find first 'deal performed' line and dump ---")
for line in text_all.splitlines():
    if "deal performed" in line:
        print(repr(line))
        break
