# MoneyDancer

Bare 1:1 port of the MoneyDancer Expert Advisor from MT4 to MT5.

## Layout

```
mt4/        Cleaned legacy MT4 EA        → mt4/README.md
mt5/        MT5 port (bare, 1:1)         → mt5/README.md
scripts/    Deploy + compile helpers     → scripts/README.md
```

## Quick start

```bash
./scripts/dev.sh    # mirror mt5/MoneyDancer/ → MT5 Experts/ and compile
```

See `scripts/README.md` for paths and exit codes.

## Conventions

- Risk thresholds are always **% of balance**, never fixed dollars.
- The MT5 port is a literal 1:1 translation of `mt4/MoneyDancer_legacy.mq4`. No refactoring, no new features.
