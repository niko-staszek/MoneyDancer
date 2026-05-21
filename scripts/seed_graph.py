"""Seed the research graph with one node per story listed in the plan.

Reads the plan markdown, extracts story IDs and titles, writes a stub story node
file per story under runs/graph/stories/<id>.md with status=proposed.

Re-runnable: if a story file already exists it's left alone (so manual edits
survive). Only creates missing nodes.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


PLAN_PATH = Path(r"C:\Users\nikof\.claude\plans\have-a-look-at-velvet-marble.md")
GRAPH_DIR = Path(__file__).resolve().parent.parent / "runs" / "graph" / "stories"


# Each story line in the plan looks like:
#   ### S1.5  Auto-scaled LotsBase (compounding hook)  *(required)*
# or
#   ### F2  1k profile margin & lot-quantization feasibility  *(required, go/no-go gate)*
STORY_RE = re.compile(
    r"^### +([SF]-?\d+(?:\.\d+|\.[A-Z]|\.\d+[a-z])?)\s+(.+?)(?:\s*\*\([^)]*\)\*)?\s*$",
)


def parse_stories(plan_text: str) -> list[tuple[str, str, int]]:
    """Extract (story_id, title, sprint) tuples from the plan."""
    stories: list[tuple[str, str, int]] = []
    current_sprint: int | None = None
    for line in plan_text.splitlines():
        m_sprint = re.match(r"^## +Sprint +(-?\d+)", line)
        if m_sprint:
            current_sprint = int(m_sprint.group(1))
            continue
        m_story = STORY_RE.match(line)
        if not m_story:
            continue
        sid = m_story.group(1).strip()
        title = m_story.group(2).strip().rstrip("*").strip()
        # Skip superseded placeholders
        if title.startswith("(superseded"):
            continue
        sprint = current_sprint if current_sprint is not None else -2
        stories.append((sid, title, sprint))
    return stories


def write_story(sid: str, title: str, sprint: int) -> bool:
    """Create the story node file if absent. Returns True if created."""
    path = GRAPH_DIR / f"{sid}.md"
    if path.exists():
        return False
    body = f"""---
id: {sid}
sprint: {sprint}
title: {title}
status: proposed
parent: null
children: []
blocked_by: []
blocks: []
supersedes: []
superseded_by: null
hypothesis: see plan
acceptance: see plan
decision_rule: see plan
best_run: null
---

# {sid} — {title}

Status: **proposed**

See `C:\\Users\\nikof\\.claude\\plans\\have-a-look-at-velvet-marble.md` for full
hypothesis, change, test config, success metric, and decision rule.

## Run log

_(populated as runs land — newest first)_

## Decisions

_(linked decision nodes — newest first)_
"""
    path.write_text(body, encoding="utf-8")
    return True


def main() -> int:
    if not PLAN_PATH.exists():
        print(f"[seed] plan not found: {PLAN_PATH}")
        return 2
    GRAPH_DIR.mkdir(parents=True, exist_ok=True)
    plan = PLAN_PATH.read_text(encoding="utf-8")
    stories = parse_stories(plan)
    created = 0
    skipped = 0
    for sid, title, sprint in stories:
        if write_story(sid, title, sprint):
            created += 1
            print(f"[seed] created {sid}")
        else:
            skipped += 1
    print(f"[seed] {created} created, {skipped} existed, {len(stories)} total")
    return 0


if __name__ == "__main__":
    sys.exit(main())
