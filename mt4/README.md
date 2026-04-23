# mt4/ — legacy MT4 EA

The original MoneyDancer MT4 EA, cleaned for portable use.

## File

```
MoneyDancer_legacy.mq4    Single-file EA (~128 KB)
```

## What was cleaned from the original

- Removed **AXI broker lock** (account / broker name gates).
- Removed **license gating** (date-based kill switches).
- Translated **Polish → English** (comments, labels, dashboard strings).
- Rebranded author tag to `JoJo`.
- **No logic changes** — trade behavior is identical to the original.

## How to run

Copy into your MT4 terminal's data folder:

```
<MT4 data folder>\MQL4\Experts\MoneyDancer_legacy.mq4
```

Open in MetaEditor → **F7** to compile → attach to chart.

## MT4 quirks worth knowing

- `OrderSelect(..., SELECT_BY_POS, MODE_TRADES)` returns closed tickets too in some builds. Guard history-adjacent iteration with `OrderCloseTime() > 0` to avoid error `4108` spam.
