#!/usr/bin/env bash
# Gentle AI on top of the agents, with the defaults of gentle-ai's own installer and no questions:
#   agents      Claude Code and gentle-shell (Pi, in gentle-shell's own home); Hermes gets the same
#               in modules/92-hermes.sh, with its own copy of the tools
#   preset      full-gentleman: claude-theme, context7, persona, engram, gga, opencode-gentle-logo,
#               permissions and skills
#   persona     neutral (no regional tone; technical artifacts in English)
#   RDD         on (gentle-ai's default)
#   community   CodeGraph (code graph and its MCP for every agent)
# Change any of it later by running `gentle-ai` as dev: its own screens show every option.
# gentle-ai's "permissions" component rewrites Claude Code's rules and sets it to bypass every
# prompt. kit-guardrails runs right after: it merges the kit's deny rules back and moves Claude Code
# to auto mode (a safety classifier instead of prompts), which is what Anthropic recommends for a
# machine with internet access. Output goes to ~/.gentle-ai/kit-install.log.
set -euo pipefail
# shellcheck disable=SC1091
. "$KIT_DIR/lib/common.sh"

h=$(home_of "$DEV_USER")
[ -x "$h/.local/bin/gentle-ai" ] || {
  warn "gentle-ai is not installed yet (see gentle-update): skipped. Later: sudo $KIT_DIR/install.sh --only 88"
  exit 0
}
LOG=$h/.gentle-ai/kit-install.log
install -d -o "$DEV_USER" -g "$DEV_USER" -m 700 "$h/.gentle-ai"

# Pi here is gentle-shell: its own Pi and its own home, never a separate vanilla Pi.
# The log is written by root on purpose (the command runs as dev): hence SC2024.
# shellcheck disable=SC2024
ga() {
  (cd /tmp && sudo -u "$DEV_USER" -H env \
    PATH="$h/src/gentle-shell/node_modules/.bin:$h/.local/share/mise/shims:$h/.local/bin:/usr/local/bin:/usr/bin:/bin" \
    PI_CODING_AGENT_DIR="$h/.gentle-shell/agent" GOBIN="$h/.local/bin" "$@" </dev/null >>"$LOG" 2>&1)
}
fail() { tail -n 15 "$LOG" >&2; die "$1 (full output in $LOG)"; }

: >"$LOG"
chown "$DEV_USER:$DEV_USER" "$LOG"
agents=claude-code
if [ -x "$h/src/gentle-shell/node_modules/.bin/pi" ]; then agents=claude-code,pi
else warn "gentle-shell is not installed yet: Gentle AI goes on Claude Code only (rerun --only 88 later)"
fi
log "Gentle AI for $agents (a few minutes)"
ga gentle-ai install --agents "$agents" --preset full-gentleman --persona neutral ||
  fail "gentle-ai install failed"

log "CodeGraph"
ga bash -c 'command -v codegraph >/dev/null || { npm install -g --silent @colbymchenry/codegraph@latest && mise reshim; }' ||
  fail "installing CodeGraph failed"
ga codegraph install --yes || fail "wiring CodeGraph to the agents failed"
# gentle-ai only remembers CodeGraph when it is picked in its own screens: record it, so every
# `gentle-ai sync` keeps it wired (gentle-shell included).
ga python3 -c '
import json, os
p = os.path.expanduser("~/.gentle-ai/state.json")
d = json.load(open(p)) if os.path.exists(p) else {}
d["community_tools"], d["community_tools_configured"] = ["codegraph"], True
json.dump(d, open(p, "w"), indent=2)
'
ga gentle-ai sync || fail "gentle-ai sync failed"

as_user "$DEV_USER" "$KIT_DIR/bin/kit-guardrails"
ok "Gentle AI: neutral persona, full-gentleman preset, CodeGraph (run gentle-ai as $DEV_USER to change it)"
