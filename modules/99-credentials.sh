#!/usr/bin/env bash
# Accounts: GitHub, NaN, Claude Code and Hermes on Telegram, through kit-login. Any step can be
# skipped and done later with: sudo kit-login <step>
set -euo pipefail
# shellcheck disable=SC1091
. "$KIT_DIR/lib/common.sh"

if { : </dev/tty; } 2>/dev/null; then
  "$KIT_DIR/bin/kit-login"
else
  log "no terminal: connect your accounts later with sudo kit-login"
fi
