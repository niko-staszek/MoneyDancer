from pathlib import Path

raw = Path(r"C:/Users/nikof/Documents/GitHub/MoneyDancer/.claude/worktrees/reverent-panini-6271e7/runs/F0-35k-pyramid/F0-35k-pyramid-report.htm").read_bytes()
print("first 200 bytes:", raw[:200])
print()
print("size:", len(raw))
for enc in ("utf-16", "utf-8", "cp1252", "latin-1"):
    try:
        text = raw.decode(enc, errors="replace")
        if "<html" in text.lower() or "<table" in text.lower() or "profit" in text.lower():
            print(f"### {enc} works:")
            print(text[:2000])
            print("...")
            print(text[len(text)//2:len(text)//2 + 2000])
            break
    except Exception as e:
        print(f"{enc} failed: {e}")
