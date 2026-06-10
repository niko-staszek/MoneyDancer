#!/usr/bin/env bash
# Self-relaunching wrapper: re-invoke the bench batch until all 50 reports exist.
# Each fresh process clears what it can; hard-reset MT5 between passes.
cd "C:/Users/nikof/Documents/GitHub/MoneyDancer/.claude/worktrees/reverent-panini-6271e7"
for p in $(seq 1 40); do
  N=0; for d in runs/BENCH-*/; do r=$(basename "$d"); [ -s "$d$r-report.htm" ] && N=$((N+1)); done
  echo "=== PASS $p :: $N/50 reports done ==="
  [ "$N" -ge 50 ] && { echo "ALL 50 DONE"; break; }
  taskkill //IM terminal64.exe //F 2>/dev/null; taskkill //IM metatester64.exe //F 2>/dev/null; sleep 20
  python scripts/bench_worst_months.py
done
echo "WRAPPER DONE"
