#!/usr/bin/env bash
# Coding agents for DEV_USER, all side by side; you pick one per task:
#   - Claude Code (official native installer, updates itself)
#   - gentle-shell: Pi with the Gentleman ecosystem, plus the NaN provider for Pi
#   - engram, gentle-ai and GGA (Gentleman Guardian Angel, reviews pull requests)
#   - OpenCode
#   - Herdr, the terminal workspace manager, with its integrations so its sidebar shows what each
#     agent is doing
# The Gentleman tools follow their main branch: gentle-update.timer refreshes them every 3 hours.
set -euo pipefail
# shellcheck disable=SC1091
. "$KIT_DIR/lib/common.sh"

h=$(home_of "$DEV_USER")

# --- Claude Code ---
if [ ! -x "$h/.local/bin/claude" ]; then
  log "Claude Code"
  as_user "$DEV_USER" bash -c 'curl -fsSL https://claude.ai/install.sh | bash' >/dev/null
fi
ok "Claude Code $(as_user "$DEV_USER" claude --version 2>/dev/null | head -1)"

# --- OpenCode and Herdr (releases, through mise) ---
as_user "$DEV_USER" mise use -g --yes github:anomalyco/opencode@latest herdr@latest >/dev/null
ok "OpenCode $(as_user "$DEV_USER" opencode --version 2>/dev/null) · Herdr $(as_user "$DEV_USER" herdr --version 2>/dev/null | awk '{print $NF}')"

# --- gentle-shell (Pi comes with it), engram, gentle-ai, GGA: gentle-update installs or updates ---
log "Gentleman ecosystem from main (several minutes the first time)"
# They follow main, which can break for a while: a failure is reported, not fatal (the timer retries).
as_user "$DEV_USER" bash "$KIT_DIR/bin/gentle-update" ||
  warn "some Gentleman tool failed to install; gentle-update.timer retries every 3 hours"

# NaN provider for Pi, in gentle-shell's own home (~/.gentle-shell/agent).
if [ -x "$h/.local/bin/gentle-shell" ]; then
  if ! as_user "$DEV_USER" gentle-shell list 2>/dev/null | grep -q pi-nan-provider; then
    as_user "$DEV_USER" gentle-shell install npm:@gtrabanco/pi-nan-provider >/dev/null
  fi
  ok "gentle-shell with the NaN provider for Pi"
fi

units="$h/.config/systemd/user"
install -d -o "$DEV_USER" -g "$DEV_USER" -m 755 "$h/.config/systemd" "$units"
cat > "$units/gentle-update.service" <<EOF
# Managed by workstation-kit (modules/80-agents.sh)
[Unit]
Description=Update the Gentleman ecosystem from main
After=network-online.target

[Service]
Type=oneshot
Environment=PATH=%h/.local/share/mise/shims:%h/.local/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=/bin/bash $KIT_DIR/bin/gentle-update
Nice=10
EOF
cat > "$units/gentle-update.timer" <<'EOF'
# Managed by workstation-kit (modules/80-agents.sh)
[Unit]
Description=gentle-update every 3 hours

[Timer]
OnCalendar=00/3:00
RandomizedDelaySec=10min
Persistent=true

[Install]
WantedBy=timers.target
EOF
chown "$DEV_USER:$DEV_USER" "$units"/gentle-update.*
user_systemctl "$DEV_USER" daemon-reload
user_systemctl "$DEV_USER" enable --now gentle-update.timer >/dev/null 2>&1

# --- Herdr integrations: the sidebar shows if each agent is working, blocked or done ---
[ -x "$h/.local/bin/gentle-shell" ] &&
  as_user "$DEV_USER" env PI_CODING_AGENT_DIR="$h/.gentle-shell/agent" herdr integration install pi >/dev/null
as_user "$DEV_USER" herdr integration install claude >/dev/null
as_user "$DEV_USER" herdr integration install opencode >/dev/null
ok "Herdr integrations for Pi, Claude Code and OpenCode"
