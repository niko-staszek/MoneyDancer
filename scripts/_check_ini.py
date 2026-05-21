from pathlib import Path
p = Path(r"C:/Users/nikof/AppData/Roaming/MetaQuotes/Terminal/5FFA568149E88FCD5B44D926DCFEAA79/MQL5/Profiles/Tester/F0-test1.3a-scalper.ini")
text = p.read_bytes().decode("utf-16", errors="replace")
print(text[:600])
