# DiscoSignalReplay (MT4 port)

Functional parity with the MT5 version at
`C:\Users\nikof\AppData\Roaming\MetaQuotes\Terminal\5FFA568149E88FCD5B44D926DCFEAA79\MQL5\Experts\DiscoSignalReplay\`.

## Files

```
mt4/DiscoSignalReplay/
  DiscoSignalReplay.mq4         # source (~430 lines)
  README.md
  presets/
    tnfx_best.set
    tnfx_safe.set
    signals1_safe.set
```

## Differences vs MT5 version

| Concern | MT4 implementation |
|---|---|
| Signal storage | Parallel arrays (`g_sig_*`) instead of struct array — avoids MT4 struct-array quirks |
| Trade API | Direct `OrderSend` / `OrderSelect` (no CTrade) |
| Account info | `AccountEquity()`, `AccountBalance()`, `AccountFreeMargin()` |
| Symbol info | `MarketInfo(sym, MODE_*)` instead of `SymbolInfoDouble` |
| Margin check | `MarketInfo(MODE_MARGINREQUIRED) * lots` (no `OrderCalcMargin`) |
| Slippage | `int Slippage` input (default 100 points) |
| Iteration | `OrdersTotal()` + `OrderSelect(i, SELECT_BY_POS, MODE_TRADES)` |
| Same TimeCurrent semantics | Yes - server time, `ServerTzOffsetHours` applied at CSV load |

Everything else (exit policies, sizing, daily guard, typo+cancel come from Python preprocessor, BE cascade via comment parsing) is functionally identical.

## Deployment to MT4 terminal

Replace `<MT4_DATA>` with your MT4 terminal's data folder (find via Terminal -> File -> Open Data Folder).

```
<MT4_DATA>/MQL4/Experts/DiscoSignalReplay/
  DiscoSignalReplay.mq4
  DiscoSignalReplay.ex4  (after compile)
  presets/...

<MT4_DATA>/MQL4/Files/disco/
  signals1_processed.csv
  tnfx_processed.csv
```

### Generate signal CSVs

The same Python preprocessor handles both terminals. From the MoneyDancer worktree:

```bash
# Default: writes to MT5 terminal Files/disco/
python scripts/prepare_mt5_signals.py

# Override for MT4: point --out-dir at your MT4 Files/disco/
python scripts/prepare_mt5_signals.py \
    --out-dir "C:/Users/nikof/AppData/Roaming/MetaQuotes/Terminal/<MT4_HASH>/MQL4/Files/disco"
```

(The script writes the same MT5-friendly format — MT4 reads it identically since the file API and CSV format are common.)

### Compile

```
"<MT4_INSTALL>/metaeditor.exe" /compile:"<MT4_DATA>/MQL4/Experts/DiscoSignalReplay/DiscoSignalReplay.mq4" /log
```

Check the `.log` file in the same folder (`grep -E 'errors|warnings'`). Exit code is unreliable - go by the log.

The MT5 metaeditor (`MetaEditor64.exe`) can NOT compile MT4 source. You need a separate MT4 install with its own `metaeditor.exe`.

### Run

1. MT4 terminal -> open XAUUSD chart (right symbol on right account)
2. Drag `DiscoSignalReplay` onto the chart
3. Inputs tab -> Load -> pick a preset
4. Common tab -> "Allow live trading" (for forward test on demo) OR run via Tester first
5. Click OK

For Strategy Tester:
1. View -> Strategy Tester (Ctrl+R)
2. Expert: `DiscoSignalReplay`, Symbol: `XAUUSD`, Period: `M1`
3. Model: **Every tick** (most accurate; needs M1 history downloaded for the date range)
4. Set initial deposit `100000`, date range matching signals
5. Start

## Live forward-test mode (Discord -> EA)

Set `CsvReloadIntervalSec=5` (default `0` = static for Strategy Tester). EA
re-reads the CSV every N seconds and picks up any new `msg_id` rows.

Pair with `scripts/discord_poller.py` (REST poll of Discord, parses + typo +
cancel, appends to inbox CSV). See the MT5 README for full setup steps —
process is identical except `MQL4/Files/disco/` instead of `MQL5/`.

Quick start for the 30-day demo:

```
1. Copy scripts/discord_poller_config.example.json -> discord_poller_config.json
2. Fill: token, channel IDs, out_csv = "<MT4_DATA>/MQL4/Files/disco/live_inbox.csv"
3. Run:  python scripts/discord_poller.py --config discord_poller_config.json
4. Attach DiscoSignalReplay with SignalCsvPath=disco/live_inbox.csv, CsvReloadIntervalSec=5
```

## Same caveats as MT5 version

- tnfx is 12 days — anecdotal. Do not commit big risk live until ≥3 months of fresh data.
- DST: signals span Mar 29 2026 boundary. If broker shifts with DST, split tests by side.
- For live, second MT4 install on demo account (portable mode if you want isolation).
- No live signal ingestion built in — EA only reads the CSV at OnInit. For live, pair with a Python Telegram poller that appends to the CSV + an EA modification to re-read periodically (or restart EA after each new signal).
