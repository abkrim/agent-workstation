#!/usr/bin/env bash
# Hermes Agent (optional, INSTALL_HERMES=yes): an assistant you talk to on Telegram, running as its
# own user "hermes" with NaN as its model provider (through nan-gate, ahead of development).
# What it can and cannot do:
#   - read the repos you share with it (repo-add --hermes): read-only copies in /srv/shared/repos,
#     refreshed hourly by the dev user. It cannot write them, push, or see ~/work;
#   - no sudo, no SSH login, no GitHub credentials;
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

hcfg() { as_user "$U" hermes config set "$1" "$2" >/dev/null; }
hcfg model.provider custom
hcfg model.base_url http://127.0.0.1:4880/hermes/v1
hcfg model.default glm5.3-flash
hcfg model.key_env HERMES_CUSTOM_NAN_BUILDERS_API_KEY
hcfg approvals.mode manual
hcfg approvals.cron_mode deny
# Side tasks (summaries, approval checks, reviews) use the same NaN model, never another provider.
for t in compression approval review skills_hub; do hcfg "auxiliary.$t.provider" main; done

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
# Managed by workstation-kit (modules/92-hermes.sh)
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
# Managed by workstation-kit (modules/92-hermes.sh)
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

ok "Hermes $(as_user "$U" hermes --version 2>/dev/null | head -1) (Telegram is set up in kit-login)"
