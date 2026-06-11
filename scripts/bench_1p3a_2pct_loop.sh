#!/usr/bin/env bash
cd "C:/Users/nikof/Documents/GitHub/MoneyDancer/.claude/worktrees/reverent-panini-6271e7"
for p in $(seq 1 25); do
  N=0; for ym in 2026-01 2026-03 2025-04 2026-02 2025-10 2025-11 2025-09 2025-03 2025-01 2025-08; do
    d="runs/BENCH2-1.3a-$ym"; [ -s "$d/BENCH2-1.3a-$ym-report.htm" ] && N=$((N+1)); done
  echo "=== PASS $p :: $N/10 reports ==="
  [ "$N" -ge 10 ] && { echo "ALL 10 DONE"; break; }
  taskkill //IM terminal64.exe //F 2>/dev/null; taskkill //IM metatester64.exe //F 2>/dev/null; sleep 20
  python scripts/bench_1p3a_2pct.py
done
echo "WRAPPER DONE"
