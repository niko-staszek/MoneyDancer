from pathlib import Path

raw = Path(r"C:/Users/nikof/Documents/GitHub/MoneyDancer/.claude/worktrees/reverent-panini-6271e7/runs/F0-35k-pyramid/F0-35k-pyramid-report.htm").read_bytes()
text = raw.decode("utf-16", errors="replace")

# Find Polish/English labels for key stats
labels = ["Zysk", "Profit", "Strata", "Loss", "Saldo", "Balance", "Wynik", "Obni",
          "transakcj", "trades", "Liczba", "Wsp", "depozyt", "Deposit", "czynnik",
          "Drawdown", "Ulcer", "Sharpe", "Recovery", "Expected", "PayOff", "Faktor", "Maksymalny", "Maximal"]
for lab in labels:
    idx = 0
    found = 0
    while True:
        i = text.find(lab, idx)
        if i < 0:
            break
        print(f"{lab!r:20} @ {i}: ...{text[max(0,i-30):i+150]}...")
        idx = i + len(lab)
        found += 1
        if found > 3:
            break
    print()
