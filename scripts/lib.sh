#!/usr/bin/env bash
# Common paths + helpers. Source this from other scripts; don't run directly.

# Repo root (two levels up from this file)
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# MT5 install + data locations
MT5_TERMINAL_DIR="/c/Program Files/FTMO Global Markets MT5 Terminal"
MT5_METAEDITOR="$MT5_TERMINAL_DIR/MetaEditor64.exe"
MT5_TERMINAL_EXE="$MT5_TERMINAL_DIR/terminal64.exe"
MT5_DATA_DIR="/c/Users/nikof/AppData/Roaming/MetaQuotes/Terminal/81A933A9AFC5DE3C23B15CAB19C63850"

# MoneyDancer source + deploy target
MD_REPO_SRC="$REPO_DIR/mt5/MoneyDancer"
MD_MT5_DEST="$MT5_DATA_DIR/MQL5/Experts/MoneyDancer"
MD_MAIN_MQ5="$MD_MT5_DEST/MoneyDancer.mq5"

# Compile log (written by MetaEditor via /log:)
COMPILE_LOG="$REPO_DIR/.compile.log"

# Convert "/c/foo/bar" -> "C:/foo/bar" for Windows executables.
unix_to_win() {
  echo "$1" | sed -E 's|^/([a-zA-Z])/|\1:/|'
}

# ANSI colors when stdout is a TTY
if [ -t 1 ]; then
  C_RED='\033[31m'
  C_GREEN='\033[32m'
  C_YELLOW='\033[33m'
  C_BLUE='\033[34m'
  C_DIM='\033[2m'
  C_RESET='\033[0m'
else
  C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_DIM=''; C_RESET=''
fi

info() { printf '%b[info]%b %s\n' "$C_BLUE"  "$C_RESET" "$*"; }
ok()   { printf '%b[ok]%b   %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '%b[warn]%b %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
err()  { printf '%b[err]%b  %s\n' "$C_RED"   "$C_RESET" "$*" >&2; }

# Convert UTF-16-with-BOM text (which MetaEditor writes) to UTF-8 on stdout.
# Uses `-f UTF-16` so iconv auto-detects + strips the BOM, and pipes through
# `tr -d '\0'` as a belt-and-braces null-byte scrub (bash command substitution
# warns about nulls otherwise).
render_log() {
  local f="$1"
  [ -f "$f" ] || return 1
  iconv -f UTF-16 -t UTF-8 "$f" 2>/dev/null | tr -d '\0' \
    || tr -d '\0' < "$f"
}
