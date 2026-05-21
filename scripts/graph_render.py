"""Render the research-graph DAG + leaderboard into runs/graph/index.md.

Walks runs/graph/stories/*.md frontmatter, collects status / parent / children /
blocked_by, builds a Mermaid graph and a status table. Also walks runs/<id>/
result.yaml files for the leaderboard (sorted by UPI proxy = net_profit / max_dd).

Only frontmatter parsing — body content is not rendered.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
GRAPH_DIR = REPO_ROOT / "runs" / "graph"
STORIES_DIR = GRAPH_DIR / "stories"
RUNS_DIR = REPO_ROOT / "runs"


STATUS_COLOR = {
    "proposed": "#cccccc",
    "in-progress": "#ffd966",
    "passed": "#9fd9a0",
    "failed": "#ef9a9a",
    "superseded": "#bdbdbd",
    "parked": "#e0e0e0",
}


def read_frontmatter(path: Path) -> dict:
    """Trivial YAML frontmatter reader — only handles flat key: value and key: [list]."""
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---"):
        return {}
    end = text.find("\n---", 4)
    if end < 0:
        return {}
    body = text[3:end]
    fm: dict = {}
    for raw in body.splitlines():
        m = re.match(r"^([a-zA-Z_][a-zA-Z0-9_]*):\s*(.*)$", raw)
        if not m:
            continue
        key, value = m.group(1), m.group(2).strip()
        if value.startswith("[") and value.endswith("]"):
            inner = value[1:-1].strip()
            fm[key] = [x.strip() for x in inner.split(",")] if inner else []
        elif value in ("null", ""):
            fm[key] = None
        else:
            fm[key] = value
    return fm


def collect_stories() -> list[dict]:
    out: list[dict] = []
    for f in sorted(STORIES_DIR.glob("*.md")):
        fm = read_frontmatter(f)
        if not fm:
            continue
        fm["_path"] = f
        out.append(fm)
    return out


def collect_runs() -> list[dict]:
    """Walk runs/<id>/result.yaml — minimal parse."""
    out: list[dict] = []
    for run_dir in sorted(RUNS_DIR.iterdir()):
        if not run_dir.is_dir():
            continue
        yaml = run_dir / "result.yaml"
        if not yaml.exists():
            continue
        # Very crude YAML parse — just pull lines we care about
        info: dict = {"run_id": run_dir.name}
        for line in yaml.read_text(encoding="utf-8").splitlines():
            if ":" not in line:
                continue
            key, _, value = line.partition(":")
            info[key.strip()] = value.strip()
        out.append(info)
    return out


def mermaid_node(s: dict) -> str:
    sid = s.get("id", "?")
    title = (s.get("title") or "").replace('"', "'")[:40]
    status = s.get("status") or "proposed"
    color = STATUS_COLOR.get(status, "#ffffff")
    safe = sid.replace(".", "_").replace("-", "_")
    return f'  {safe}["<b>{sid}</b><br/>{title}<br/><i>{status}</i>"]:::s_{status}'


def mermaid_edges(stories: list[dict]) -> list[str]:
    edges: list[str] = []
    by_id = {s.get("id"): s for s in stories}
    for s in stories:
        sid = s.get("id")
        if not sid:
            continue
        safe_a = sid.replace(".", "_").replace("-", "_")
        for child in (s.get("children") or []):
            if child in by_id:
                safe_b = child.replace(".", "_").replace("-", "_")
                edges.append(f"  {safe_a} --> {safe_b}")
        for blocker in (s.get("blocked_by") or []):
            if blocker in by_id:
                safe_b = blocker.replace(".", "_").replace("-", "_")
                edges.append(f"  {safe_b} -.-> {safe_a}")
    return edges


def render() -> Path:
    stories = collect_stories()
    runs = collect_runs()

    lines: list[str] = []
    lines.append("# Research graph — auto-rendered")
    lines.append("")
    lines.append("Run `python scripts/graph_render.py` to refresh.")
    lines.append("")

    lines.append("## Status table")
    lines.append("")
    lines.append("| ID | Sprint | Title | Status | Blocks | Blocked by |")
    lines.append("|---|---|---|---|---|---|")
    for s in stories:
        sid = s.get("id", "?")
        sprint = s.get("sprint", "?")
        title = (s.get("title") or "").replace("|", "\\|")
        status = s.get("status") or "?"
        blocks = ",".join(s.get("blocks") or []) or "-"
        blocked = ",".join(s.get("blocked_by") or []) or "-"
        lines.append(f"| {sid} | {sprint} | {title} | {status} | {blocks} | {blocked} |")

    lines.append("")
    lines.append("## Leaderboard")
    lines.append("")
    if runs:
        lines.append("| Run | Story | Trades | Net P/L | DD max | DD % |")
        lines.append("|---|---|---|---|---|---|")
        for r in runs:
            lines.append(
                f"| {r.get('run_id','?')} | {r.get('story_id','?')} | "
                f"{r.get('trades','?')} | {r.get('net_profit','?')} | "
                f"{r.get('balance_dd_max','?')} | {r.get('balance_dd_rel','?')} |"
            )
    else:
        lines.append("_no runs landed yet_")

    lines.append("")
    lines.append("## DAG")
    lines.append("")
    lines.append("```mermaid")
    lines.append("graph TD")
    for s in stories:
        lines.append(mermaid_node(s))
    lines.extend(mermaid_edges(stories))
    lines.append("  classDef s_proposed fill:#eeeeee,stroke:#999")
    lines.append("  classDef s_in-progress fill:#ffd966,stroke:#cc9900")
    lines.append("  classDef s_passed fill:#9fd9a0,stroke:#2e7d32")
    lines.append("  classDef s_failed fill:#ef9a9a,stroke:#b71c1c")
    lines.append("  classDef s_superseded fill:#bdbdbd,stroke:#616161")
    lines.append("  classDef s_parked fill:#e0e0e0,stroke:#9e9e9e")
    lines.append("```")
    lines.append("")

    out = GRAPH_DIR / "index.md"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"[graph] rendered {len(stories)} stories, {len(runs)} runs -> {out}")
    return out


if __name__ == "__main__":
    sys.exit(0 if render() else 1)
