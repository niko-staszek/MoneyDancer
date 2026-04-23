#!/usr/bin/env bash
# Mirror repo MoneyDancer source tree -> MT5 Experts folder.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

if [ ! -d "$MD_REPO_SRC" ]; then
  err "Source missing: $MD_REPO_SRC"
  exit 2
fi

info "Deploying"
info "  from: $MD_REPO_SRC"
info "  to:   $MD_MT5_DEST"

mkdir -p "$MD_MT5_DEST/Include"
cp "$MD_REPO_SRC/MoneyDancer.mq5" "$MD_MT5_DEST/"
cp "$MD_REPO_SRC/Include/"*.mqh "$MD_MT5_DEST/Include/"

main_count=$(ls "$MD_MT5_DEST/"*.mq5 2>/dev/null | wc -l | tr -d ' ')
inc_count=$(ls "$MD_MT5_DEST/Include/"*.mqh 2>/dev/null | wc -l | tr -d ' ')
ok "Deployed $main_count main + $inc_count include(s)"
