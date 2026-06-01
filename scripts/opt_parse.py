# scripts/opt_parse.py
"""Parse an MT5 optimization XML (SpreadSheetML) into ranked finalist configs.

parse_opt_xml(path) -> list[dict] (one per pass; values are strings incl. 'Result').
top_configs(rows, n) -> the n highest-Result rows as param-only dicts (Result/stat cols dropped).
"""
import xml.etree.ElementTree as ET
from pathlib import Path

_NS = "{urn:schemas-microsoft-com:office:spreadsheet}"
# non-parameter columns MT5 emits that must not be passed back as EA inputs
_STAT_COLS = {"Result", "Profit", "Expected Payoff", "Profit Factor", "Recovery Factor",
              "Sharpe Ratio", "Custom", "Equity DD %", "Trades", "Pass", "Back Result", "Forward Result"}

def parse_opt_xml(path):
    root = ET.parse(str(path)).getroot()
    rows_xml = root.iter(f"{_NS}Row")
    header = None
    out = []
    for r in rows_xml:
        cells = [(c.find(f"{_NS}Data").text if c.find(f"{_NS}Data") is not None else "")
                 for c in r.findall(f"{_NS}Cell")]
        if header is None:
            header = cells
            continue
        out.append(dict(zip(header, cells)))
    return out

def top_configs(rows, n=8):
    def res(r):
        try: return float(r.get("Result", "nan"))
        except ValueError: return float("-inf")
    ranked = sorted(rows, key=res, reverse=True)[:n]
    return [{k: v for k, v in r.items() if k not in _STAT_COLS} for r in ranked]
