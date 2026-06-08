# MoneyDancer 3.0 — clean rename of 1.2 — VERIFICATION (bit-identical)

v3.0 = fork of 1.2 with all 131 inputs renamed to frozen PascalCase + story-tags stripped. NO behavior change.

## Verification: 13a set on 1.2 vs 3.0 (XAUUSD.duk_robo M30, 2026.04.06-04.13, 10k, MaxSpreadPts=45, Model=0)
- 1.2 native (TEST 13a M30+.set):       11704 deals, net +1119.44, end balance 11118.97
- 3.0 ported (test13a_3.0.set, via to_3_0): 11704 deals, net +1119.44, end balance 11118.97
- per-deal diff (time,direction,volume,price,profit,balance): **IDENTICAL**
- 3.0 EA compiled: 0 errors, 0 warnings.

## VERDICT: PASS — v3.0 renamed EA behaves byte-identically to 1.2. Rename is behavior-neutral. ACCEPTED.

Naming rule: scripts/v3_namemap.to_v3 (deterministic). Full 131-row map in NAMING.md (FROZEN).
Source rename: scripts/v3_rename.apply_to_tree. Set porter: scripts/translate_set.to_3_0 (shared to_v3 rule).
Commits: 3820d2b (rule+map), 16b6ef5 (fork+rename, compiles), 40f75f4 (NAMING.md+porter).
