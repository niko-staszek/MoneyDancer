# mt4/ — MT4 versioned releases

Each subfolder is a self-contained MT4 release of the EA, named **`MAJOR.MINOR`** to match `mt5/` and the `#property version` field. MT4 1.0 was renamed from the original `MoneyDancer_legacy.mq4`; new features land alongside the matching `mt5/` release.

## Releases

| Version | Status | Folder                       | What's new                                                                |
|---------|--------|------------------------------|---------------------------------------------------------------------------|
| 1.0     | Frozen | `1.0/MoneyDancer_1.0.mq4`    | Cleaned MT4 baseline. Three daily kill-switches.                          |
| 1.1     | Active | `1.1/MoneyDancer_1.1.mq4`    | Adds **Total Profit Target** kill-switch (% of baseline OR fixed USD).    |

Each release ships with:
- `MoneyDancer_<ver>.mq4` — single-file EA (monolithic, no includes)
- `presets/XAUUSD_<ver>.set` — example preset

Both releases can be deployed to the same MT4 terminal simultaneously — they appear as separate items in Navigator.

## What was cleaned from the original (preserved through 1.0 and forward)

- Removed **AXI broker lock** (account / broker name gates).
- Removed **license gating** (date-based kill switches).
- Translated **Polish → English** (comments, labels, dashboard strings).
- Rebranded author tag to `JoJo`.
- **No logic changes** — trade behavior is identical to the original.

## 1.1 highlight: Total Profit Target

Mirrors the [`mt5/1.1/`](../mt5/1.1/MoneyDancer_1.1/) port. A 4th daily kill-switch — stops trading once today's earned + floating P/L hits a target. Selectable mode in `.set` / inputs:

```
ProfitTargetMode=0      ; 0=Off, 1=Percentage of baseline, 2=Fixed USD amount
ProfitTargetPct=5.0     ; used when Mode=1
ProfitTargetUsd=100.0   ; used when Mode=2
```

Default `Mode=0` (off) — a 1.0 `.set` file loaded on 1.1 produces identical behavior.

## How to build

Copy the `.mq4` file into the MT4 terminal data folder:

- 1.0: copy `mt4/1.0/MoneyDancer_1.0.mq4` to `<MT4_DATA>/MQL4/Experts/`
- 1.1: copy `mt4/1.1/MoneyDancer_1.1.mq4` to `<MT4_DATA>/MQL4/Experts/`

Open the matching file in MetaEditor → **F7** to compile → attach to chart.

CLI compile pattern (see [`~/.claude/skills/mt4-cli`](../../../.claude/skills/mt4-cli/SKILL.md)):

```
metaeditor.exe /compile:<path>\MoneyDancer_<ver>.mq4 /log
```

Note: MT4's `metaeditor.exe` exit code is unreliable — always read the `<file>.log` for the actual `Result: 0 errors, 0 warnings` line.

## MT4 quirks worth knowing

- `OrderSelect(..., SELECT_BY_POS, MODE_TRADES)` returns closed tickets too in some builds. Guard history-adjacent iteration with `OrderCloseTime() > 0` to avoid error `4108` spam.
