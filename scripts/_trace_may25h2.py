"""Trace timing of basket-SL events in may25-H2 (the breach cell)."""
import re
from collections import Counter
from pathlib import Path

log_path = Path("runs/STEP-OOS-5k-may25-H2/20260521.log")
raw = log_path.read_bytes().replace(b"\x00", b"").decode("utf-8", errors="ignore")

# First basket-SL fired event
m = re.search(r"(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2})[^\n]*\[S1\.0\] basket SL fired", raw)
print("First basket-SL fired:", m.group(0)[:160] if m else "none")
print()

# First CRITICAL
m2 = re.search(r"(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2})[^\n]*\[S1\.0\] CRITICAL", raw)
print("First CRITICAL:", m2.group(0)[:160] if m2 else "none")
print()

# Hour distribution of CRITICAL events
hours = re.findall(r"\d{4}\.\d{2}\.\d{2} (\d{2}):\d{2}:\d{2}[^\n]*\[S1\.0\] CRITICAL", raw)
c = Counter(hours)
print("CRITICAL events by hour:")
for h, n in sorted(c.items()):
    print(f"  {h}:xx  {n}")
print()

# Hour distribution of basket-SL FIRED (not CRITICAL)
hours2 = re.findall(r"\d{4}\.\d{2}\.\d{2} (\d{2}):\d{2}:\d{2}[^\n]*\[S1\.0\] basket SL fired", raw)
c2 = Counter(hours2)
print("basket-SL fired by hour:")
for h, n in sorted(c2.items()):
    print(f"  {h}:xx  {n}")
print()

# WARN series close 0 — when does close fail?
warns = re.findall(r"\d{4}\.\d{2}\.\d{2} (\d{2}):\d{2}:\d{2}[^\n]*\[S1\.0\] WARN series close returned 0", raw)
c3 = Counter(warns)
print("WARN close returned 0 by hour:")
for h, n in sorted(c3.items()):
    print(f"  {h}:xx  {n}")
