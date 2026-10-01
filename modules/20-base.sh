#!/usr/bin/env bash
# Base system: updates, common packages, time zone, automatic security updates (no automatic
# reboots), fail2ban for SSH, and mosh (SSH that survives a phone changing networks; only ever
# reached over Tailscale, like SSH).
set -euo pipefail
# shellcheck disable=SC1091
. "$KIT_DIR/lib/common.sh"

log "updating the system (a few minutes on a fresh server)"
apt-get update -qq
apt-get full-upgrade -y -qq >/dev/null
apt_install curl git jq unzip ca-certificates gnupg build-essential python3 python3-venv \
  libatomic1 unattended-upgrades fail2ban mosh

timedatectl set-timezone "${TIMEZONE:-UTC}"

cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF
cat > /etc/apt/apt.conf.d/52workstation-kit <<'EOF'
// Managed by workstation-kit (modules/20-base.sh). Ubuntu's security origins stay the default.
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
// You decide when to reboot.
Unattended-Upgrade::Automatic-Reboot "false";
EOF

# fail2ban never bans the tailnet (100.64.0.0/10): after the firewall step, SSH only arrives there.
cat > /etc/fail2ban/jail.d/00-workstation-kit.local <<'EOF'
# Managed by workstation-kit (modules/20-base.sh)
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1 100.64.0.0/10
bantime  = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
backend = systemd
EOF
systemctl enable --now unattended-upgrades fail2ban >/dev/null
systemctl restart fail2ban
ok "base system, automatic security updates and fail2ban"
