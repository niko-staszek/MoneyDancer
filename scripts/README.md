# MoneyDancer build scripts

Bash helpers that eliminate the manual "copy file → MetaEditor F7 → tester"
dance. Each script is small and composable.

## Usage (from repo root)

```bash
./scripts/deploy.sh     # mirror mt5/MoneyDancer/ -> MT5 Experts/MoneyDancer/
./scripts/compile.sh    # run MetaEditor CLI; fail if errors
./scripts/dev.sh        # deploy + compile
```

## Exit codes

| Code | Meaning |
|---|---|
| 0 | success (compile clean) |
| 1 | compile errors (see log printed above) |
| 2 | source or deploy target missing |
| 3 | MetaEditor not found, or no log produced |

## Paths (edit `lib.sh` if any of these change)

| What | Path |
|---|---|
| MT5 install | `C:\Program Files\FTMO Global Markets MT5 Terminal` |
| MT5 data folder | `%APPDATA%\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850` |
| MetaEditor exe | `<MT5 install>\MetaEditor64.exe` |
| Repo source | `mt5/MoneyDancer/` |
| Deploy target | `<data folder>\MQL5\Experts\MoneyDancer\` |
| Compile log | `.compile.log` at repo root (UTF-16 LE from MetaEditor) |

## Notes

- MetaEditor is a GUI app, so `compile.sh` waits up to 5s for it to flush the
  log. Usually done in <1s.
- The log is UTF-16 LE with BOM; `render_log()` in `lib.sh` converts to UTF-8
  for display.
- The script parses the `Result` line (`Result  N error(s), M warning(s)`) to
  determine success.
- If MetaEditor is already open and editing the same file, compile may still
  work — it's idempotent.

## Future additions (when needed)

- `tester.sh` — launch MT5 strategy tester via `terminal64.exe /config:...ini`
  (Phase D).
- `watch.sh` — auto-deploy+compile on file changes (convenience).
