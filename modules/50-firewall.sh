#!/usr/bin/env bash
# Firewall: everything incoming is denied except what arrives over Tailscale. After this, the
# server's public IP answers nothing (SSH included): you reach it only from your tailnet.
set -euo pipefail
# shellcheck disable=SC1091
. "$KIT_DIR/lib/common.sh"

apt_install ufw
if ! ufw status | grep -q "Status: active"; then
  host=$(tailscale status --json | jq -r .Self.DNSName | sed 's/\.$//')
  echo
  echo "  After this step the public IP stops answering. Your way in is: ssh $ADMIN_USER@$host"
  echo "  (this session survives; new ones must come through Tailscale)"
  echo
  confirm "Turn the firewall on?" || die "Stopped before the firewall. Resume with: ./install.sh --from 50"
fi

ufw default deny incoming >/dev/null
ufw default allow outgoing >/dev/null
ufw default deny routed >/dev/null
ufw allow in on tailscale0 comment 'Tailscale' >/dev/null
ufw --force enable >/dev/null
ok "firewall: only Tailscale gets in"
