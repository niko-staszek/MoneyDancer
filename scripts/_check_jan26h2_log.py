import sys
from pathlib import Path
log = Path("runs/PRECLOSE_C6-OOS-5k-jan26-H2/20260522.log")
raw = log.read_bytes().replace(b"\x00", b"").decode("utf-8", errors="ignore")
print("file length:", len(raw))
print("number of lines:", raw.count("\n"))
print("---- last 30 lines ----")
for line in raw.splitlines()[-30:]:
    print(line[:250])
