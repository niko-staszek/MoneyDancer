# WT/scripts/v3_namemap.py
"""Deterministic 1.2 -> 3.0 input-name rule + map generator (spec 3.0 naming scheme)."""
import re
from pathlib import Path

def to_v3(name):
    s = name[0].upper() + name[1:]
    while "_" in s:                       # drop underscores, capitalize next letter
        i = s.index("_")
        s = s[:i] + (s[i+1].upper() + s[i+2:] if i + 1 < len(s) else "")
    # acronym run (2+ uppercase) -> Title-case: TP->Tp, DD->Dd, ADX->Adx, EMA->Ema
    # Pass 1: acronym run immediately before a CamelWord (e.g. TPPoints -> TpPoints, not Tppoints)
    s = re.sub(r"[A-Z]{2,}(?=[A-Z][a-z])", lambda m: m.group(0)[0] + m.group(0)[1:].lower(), s)
    # Pass 2: remaining standalone acronym runs (e.g. DD, BE at end or before non-alpha)
    s = re.sub(r"[A-Z]{2,}", lambda m: m.group(0)[0] + m.group(0)[1:].lower(), s)
    return s

def build_map(inputs_mqh):
    names = re.findall(r"^\s*input\s+\S+\s+(\w+)", Path(inputs_mqh).read_text(errors="ignore"), re.M)
    m = {n: to_v3(n) for n in names}
    dupes = [v for v in m.values() if list(m.values()).count(v) > 1]
    if dupes:
        raise ValueError(f"name collisions: {sorted(set(dupes))}")
    return m
