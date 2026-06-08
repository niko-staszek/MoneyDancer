# WT/scripts/v3_rename.py
"""Apply a {old:new} name-map to source text: whole-word, longest-old-first (so a short
name never corrupts a longer one), single pass via one alternation regex."""
import re

def apply_map(text, name_map):
    olds = sorted(name_map, key=len, reverse=True)
    pattern = re.compile(r"\b(" + "|".join(re.escape(o) for o in olds) + r")\b")
    return pattern.sub(lambda m: name_map[m.group(1)], text)

def apply_to_tree(root, name_map, suffixes=(".mq5", ".mqh")):
    from pathlib import Path
    for p in Path(root).rglob("*"):
        if p.suffix in suffixes:
            p.write_text(apply_map(p.read_text(errors="ignore"), name_map), encoding="utf-8")
