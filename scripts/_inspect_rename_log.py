raw = open("runs/RENAME_VERIFY-5k-mar25/20260527.log", "rb").read().replace(b"\x00", b"").decode("utf-8", errors="ignore")
lines = raw.split("\n")
hits = [L for L in lines if any(k in L for k in ["error", "ERROR", "cannot", "refus", "fail", "CRITICAL", "PL.3", "init", "Init", "Money"])]
for L in hits[:30]:
    print(L[:200])
