#!/usr/bin/env bash
# Compile MoneyDancer.mq5 via MetaEditor CLI.
# Exits 0 on clean compile, 1 on errors, 2 on missing source, 3 on MetaEditor failure.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

if [ ! -f "$MT5_METAEDITOR" ]; then
  err "MetaEditor not found at $MT5_METAEDITOR"
  exit 3
fi

if [ ! -f "$MD_MAIN_MQ5" ]; then
  err "Main file not deployed yet: $MD_MAIN_MQ5"
  err "Run scripts/deploy.sh first."
  exit 2
fi

rm -f "$COMPILE_LOG"

WIN_MAIN=$(unix_to_win "$MD_MAIN_MQ5")
WIN_LOG=$(unix_to_win "$COMPILE_LOG")

info "Compiling $WIN_MAIN"
"$MT5_METAEDITOR" /compile:"$WIN_MAIN" /log:"$WIN_LOG" >/dev/null 2>&1 || true

# MetaEditor is GUI-spawned; give it a moment to flush the log.
for i in 1 2 3 4 5 6 7 8 9 10; do
  [ -f "$COMPILE_LOG" ] && break
  sleep 0.5
done

if [ ! -f "$COMPILE_LOG" ]; then
  err "MetaEditor did not produce a compile log."
  err "  Expected: $COMPILE_LOG"
  err "  Try opening MetaEditor and running /compile manually to debug."
  exit 3
fi

# Render log (UTF-16 LE -> UTF-8)
LOG_TXT=$(render_log "$COMPILE_LOG")

# Show the log (dimmed)
echo -e "${C_DIM}---- compile log ----${C_RESET}"
echo "$LOG_TXT"
echo -e "${C_DIM}---------------------${C_RESET}"

# Parse result line: "Result     N error(s), M warning(s)"
RESULT_LINE=$(echo "$LOG_TXT" | grep -E "^Result" | tail -1 || true)

if [ -z "$RESULT_LINE" ]; then
  warn "Couldn't find 'Result' line in log — assuming success."
  exit 0
fi

# Extract error count (first number before 'error')
ERR_COUNT=$(echo "$RESULT_LINE" | grep -oE "[0-9]+ error" | head -1 | grep -oE "[0-9]+" | head -1)
WARN_COUNT=$(echo "$RESULT_LINE" | grep -oE "[0-9]+ warning" | head -1 | grep -oE "[0-9]+" | head -1)

ERR_COUNT=${ERR_COUNT:-"?"}
WARN_COUNT=${WARN_COUNT:-"?"}

if [ "$ERR_COUNT" = "0" ] && [ "$WARN_COUNT" = "0" ]; then
  ok  "Compile clean: 0 errors, 0 warnings"
  exit 0
elif [ "$ERR_COUNT" = "0" ]; then
  warn "Compile ok with $WARN_COUNT warning(s)"
  exit 0
else
  err "Compile failed: $ERR_COUNT error(s), $WARN_COUNT warning(s)"
  exit 1
fi
