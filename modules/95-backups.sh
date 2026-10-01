#!/usr/bin/env bash
# Local backups (optional, INSTALL_BACKUPS=yes): encrypted restic snapshots every day of your repos
# and work in progress, the agents' settings, Hermes, and the machine's security settings. Weekly
# integrity check. Keeps 7 daily, 4 weekly and 6 monthly snapshots.
# They live on this same disk: they undo mistakes (a deleted folder, a broken config), they do NOT
# protect against losing the server. For that, use your provider's snapshots or copy
# /srv/backups/restic elsewhere. Runs as its own user "restic", which can read everything and write
# only its repository.
set -euo pipefail
# shellcheck disable=SC1091
. "$KIT_DIR/lib/common.sh"

enabled INSTALL_BACKUPS || { log "INSTALL_BACKUPS is not yes: skipped"; exit 0; }

apt_install restic
id restic &>/dev/null || useradd -m -s /usr/sbin/nologin -c "restic backups" restic
chmod 700 /home/restic
install -d -o restic -g restic -m 700 /srv/backups /srv/backups/restic /home/restic/.cache
if [ ! -f /home/restic/.restic-password ]; then
  sudo -u restic sh -c 'umask 377; openssl rand -base64 48 > /home/restic/.restic-password'
fi
if [ ! -f /srv/backups/restic/config ]; then
  sudo -u restic env RESTIC_REPOSITORY=/srv/backups/restic RESTIC_PASSWORD_FILE=/home/restic/.restic-password \
    restic init --quiet
fi

d=$(home_of "$DEV_USER")
install -d -m 755 /etc/workstation-kit
cat > /etc/workstation-kit/backup-paths <<EOF
# What restic saves (modules/95-backups.sh). One path per line; missing ones are skipped.
$d/work
$d/trees
$d/.config
$d/.gentle-shell/agent/auth.json
$d/.gentle-shell/agent/settings.json
$d/.pi
$d/.claude/settings.json
$d/.claude/projects
/home/hermes/.hermes
/opt/workstation-kit/kit.conf
/etc/workstation-kit
/etc/ssh/sshd_config.d
/etc/ufw
EOF
cat > /etc/workstation-kit/backup-excludes <<'EOF'
# Rebuilt or reinstalled, so not saved.
node_modules
.venv
.next
dist
.astro
.turbo
.cache
/home/hermes/.hermes/hermes-agent
/home/hermes/.hermes/cache
EOF
install -m 755 "$KIT_DIR/bin/kit-backup" /usr/local/sbin/kit-backup

svc() {  # svc NAME DESCRIPTION ARG CALENDAR
  cat > "/etc/systemd/system/$1.service" <<EOF
# Managed by workstation-kit (modules/95-backups.sh)
[Unit]
Description=$2

[Service]
Type=oneshot
User=restic
Group=restic
AmbientCapabilities=CAP_DAC_READ_SEARCH
CapabilityBoundingSet=CAP_DAC_READ_SEARCH
NoNewPrivileges=yes
ProtectSystem=strict
ReadWritePaths=/srv/backups/restic /home/restic/.cache
PrivateTmp=yes
ExecStart=/usr/local/sbin/kit-backup $3
Nice=10
IOSchedulingClass=idle
EOF
  cat > "/etc/systemd/system/$1.timer" <<EOF
# Managed by workstation-kit (modules/95-backups.sh)
[Unit]
Description=$2 ($4)

[Timer]
OnCalendar=$4
Persistent=true
RandomizedDelaySec=15min

[Install]
WantedBy=timers.target
EOF
}
svc kit-backup "Local restic backup" backup "*-*-* 03:30:00"
svc kit-backup-check "restic repository check" check "Sun *-*-* 05:00:00"
systemctl daemon-reload
systemctl enable --now kit-backup.timer kit-backup-check.timer >/dev/null 2>&1
ok "daily local backups in /srv/backups/restic"
warn "save a copy of the restic password somewhere safe (sudo cat /home/restic/.restic-password): without it the backups cannot be read"
