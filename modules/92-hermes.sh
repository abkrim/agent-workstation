#!/usr/bin/env bash
# Hermes Agent (optional, INSTALL_HERMES=yes): an assistant you talk to on Telegram, running as its
# own user "hermes" with NaN as its provider and GLM 5.3 Flash as its model (through nan-gate,
# ahead of development). The NaN key is the one kit-login asks for. Gentle AI is set up for it too
# (same preset and persona as the other agents), with Hermes's own copy of engram and gentle-ai.
# What it can and cannot do:
#   - read the repos you share with it (repo-add --hermes): read-only copies in /srv/shared/repos,
#     refreshed hourly by the dev user. It cannot write them, push, or see ~/work;
#   - no sudo, no SSH login, no GitHub credentials;
#   - on this machine's loopback it can reach only nan-gate (its model): a UFW rule rejects every
#     other local port for the hermes user, so dev's local services (engram, dev servers, Docker
#     ports) are out of its reach;
#   - every command it wants to run asks for your approval (approvals.mode manual), and scheduled
#     jobs cannot run commands (approvals.cron_mode deny);
#   - only your Telegram user can talk to it.
# The bot token and your Telegram user id are asked for by kit-login.
set -euo pipefail
# shellcheck disable=SC1091
. "$KIT_DIR/lib/common.sh"

enabled INSTALL_HERMES || { log "INSTALL_HERMES is not yes: skipped"; exit 0; }

U=hermes
id "$U" &>/dev/null || useradd -m -s /bin/bash -c "Hermes Agent" "$U"
usermod -aG agents "$U"
H=$(home_of "$U")
chmod 750 "$H"
loginctl enable-linger "$U"
wait_user_bus "$U"

if [ ! -x "$H/.local/bin/hermes" ]; then
  log "installing Hermes Agent"
  tmp=$(sudo -u "$U" mktemp)
  as_user "$U" curl -fsSL https://hermes-agent.nousresearch.com/install.sh -o "$tmp"
  as_user "$U" bash "$tmp" --skip-setup >/dev/null
  rm -f "$tmp"
fi
chmod 700 "$H/.hermes"
install_user_env "$U" "$(engram_env "$U")"  # its engram on a socket, off dev's port

hcfg() { as_user "$U" hermes config set "$1" "$2" >/dev/null; }
hcfg model.provider custom
hcfg model.base_url http://127.0.0.1:4880/hermes/v1
hcfg model.default glm5.3-flash
hcfg model.key_env HERMES_CUSTOM_NAN_BUILDERS_API_KEY
hcfg approvals.mode manual
hcfg approvals.cron_mode deny
# Side tasks (summaries, approval checks, reviews) use the same NaN model, never another provider.
for t in compression approval review skills_hub; do hcfg "auxiliary.$t.provider" main; done
# Gentle AI writes about 60 KB into SOUL.md (persona, orchestrator guidance, engram conventions,
# skills); Hermes would cut it at 48,660 characters and lose instructions. GLM 5.3 Flash has the
# context for it.
hcfg context_file_max_chars 120000

ENV=$H/.hermes/.env
[ -f "$ENV" ] || install -o "$U" -g "$U" -m 600 /dev/null "$ENV"
chmod 600 "$ENV"
for k in HERMES_CUSTOM_NAN_BUILDERS_API_KEY TELEGRAM_BOT_TOKEN TELEGRAM_ALLOWED_USERS; do
  grep -q "^$k=" "$ENV" || echo "$k=" >> "$ENV"
done
grep -q '^GATEWAY_ALLOW_ALL_USERS=' "$ENV" || echo "GATEWAY_ALLOW_ALL_USERS=false" >> "$ENV"

# Read-only repos: git in the shared copies works for exactly the repos the dev user shares.
as_user "$U" git config --global --get-all include.path | grep -qx /srv/shared/repos/.gitconfig-safe ||
  as_user "$U" git config --global --add include.path /srv/shared/repos/.gitconfig-safe

units="$(home_of "$DEV_USER")/.config/systemd/user"
cat > "$units/shared-repos.service" <<EOF
# Managed by agent-workstation (modules/92-hermes.sh)
[Unit]
Description=Read-only copies for Hermes in /srv/shared/repos
After=network-online.target

[Service]
Type=oneshot
Environment=PATH=%h/.local/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=/bin/bash $KIT_DIR/bin/shared-repos-sync
Nice=10
EOF
cat > "$units/shared-repos.timer" <<'EOF'
# Managed by agent-workstation (modules/92-hermes.sh)
[Unit]
Description=shared-repos every hour

[Timer]
OnCalendar=hourly
RandomizedDelaySec=5min
Persistent=true

[Install]
WantedBy=timers.target
EOF
chown "$DEV_USER:$DEV_USER" "$units"/shared-repos.*
user_systemctl "$DEV_USER" daemon-reload
user_systemctl "$DEV_USER" enable --now shared-repos.timer >/dev/null 2>&1

# --- Loopback guard: the hermes user may connect on this machine only to nan-gate (127.0.0.1:4880).
# Written into UFW's after.rules, so it survives reloads and reboots. If UFW refuses the new file,
# the previous one is put back: the firewall is never left broken.
guard4="-A ufw-after-output -o lo -p tcp -m owner --uid-owner $U -m multiport ! --dports 4880 -j REJECT --reject-with tcp-reset"
guard6="-A ufw6-after-output -o lo -p tcp -m owner --uid-owner $U -j REJECT --reject-with tcp-reset"
add_after_rule() {  # add_after_rule FILE RULE COMMENT
  grep -qF -- "$2" "$1" && return 0
  cp -a "$1" "$1.kit-backup"
  awk -v r="$2" -v c="# agent-workstation: $3 (modules/92-hermes.sh)" \
    '!done && /^COMMIT/ { print c; print r; done=1 } { print }' "$1" > "$1.kit-new" && mv "$1.kit-new" "$1"
  chmod 640 "$1"
}
add_after_rule /etc/ufw/after.rules "$guard4" "Hermes may reach only nan-gate on loopback"
add_after_rule /etc/ufw/after6.rules "$guard6" "Hermes has no IPv6 loopback"
if ufw status 2>/dev/null | grep -q "Status: active"; then
  if ufw reload >/dev/null 2>&1; then
    ok "loopback guard: $U reaches only 127.0.0.1:4880 on this machine"
  else
    for f in /etc/ufw/after.rules /etc/ufw/after6.rules; do [ -f "$f.kit-backup" ] && mv "$f.kit-backup" "$f"; done
    ufw reload >/dev/null 2>&1 || true
    warn "UFW rejected the loopback guard; previous rules restored (check 'ufw reload' by hand)"
  fi
fi
rm -f /etc/ufw/after.rules.kit-backup /etc/ufw/after6.rules.kit-backup

# --- Gentle AI for Hermes: its own Go to build engram and gentle-ai (Node comes with Hermes) ---
as_user "$U" mise use -g --yes go@latest >/dev/null
log "Gentle AI for Hermes (builds engram and gentle-ai: a few minutes the first time)"
as_user "$U" bash "$KIT_DIR/bin/hermes-gentle-update" ||
  warn "Gentle AI for Hermes did not finish; hermes-gentle-update.timer retries every 3 hours"
hunits="$H/.config/systemd/user"
install -d -o "$U" -g "$U" -m 755 "$H/.config" "$H/.config/systemd" "$hunits"
cat > "$hunits/hermes-gentle-update.service" <<EOF
# Managed by agent-workstation (modules/92-hermes.sh)
[Unit]
Description=Gentle AI for Hermes: engram, gentle-ai and gentle-ai sync
After=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash $KIT_DIR/bin/hermes-gentle-update
Nice=10
EOF
cat > "$hunits/hermes-gentle-update.timer" <<'EOF'
# Managed by agent-workstation (modules/92-hermes.sh)
[Unit]
Description=hermes-gentle-update every 3 hours

[Timer]
OnCalendar=01/3:30
RandomizedDelaySec=10min
Persistent=true

[Install]
WantedBy=timers.target
EOF
chown "$U:$U" "$hunits"/hermes-gentle-update.*
user_systemctl "$U" daemon-reload
if enabled AUTO_UPDATE; then
  user_systemctl "$U" enable --now hermes-gentle-update.timer >/dev/null 2>&1
else
  user_systemctl "$U" disable --now hermes-gentle-update.timer >/dev/null 2>&1 || true
fi

ok "$(as_user "$U" hermes --version 2>/dev/null | head -1), NaN with GLM 5.3 Flash (Telegram is set up in kit-login)"
