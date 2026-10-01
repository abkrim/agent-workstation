#!/usr/bin/env bash
# Tailscale: the only way into the machine once the firewall is on. Prints a login link the first
# time; open it and approve the machine in your tailnet.
set -euo pipefail
# shellcheck disable=SC1091
. "$KIT_DIR/lib/common.sh"

if ! command -v tailscale >/dev/null; then
  codename=$(. /etc/os-release && echo "$VERSION_CODENAME")
  curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/$codename.noarmor.gpg" \
    -o /usr/share/keyrings/tailscale-archive-keyring.gpg
  curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/$codename.tailscale-keyring.list" \
    -o /etc/apt/sources.list.d/tailscale.list
  apt-get update -qq
  apt_install tailscale
fi
systemctl enable --now tailscaled >/dev/null

if ! tailscale status >/dev/null 2>&1; then
  log "Open the link below and approve this machine in your tailnet"
  tailscale up --hostname="${TAILSCALE_HOSTNAME:-workstation}"
fi
ok "Tailscale: $(tailscale_host) ($(tailscale ip -4 | head -1))"
got=$(tailscale status --json | jq -r '.Self.HostName // empty')
[ -z "$got" ] || [ "$got" = "${TAILSCALE_HOSTNAME:-workstation}" ] ||
  warn "the name ${TAILSCALE_HOSTNAME:-workstation} was taken in your tailnet, so this machine is '$got'. Rename it in the Tailscale admin console if you prefer."
tailscale status --json | jq -e '.Self.DNSName != ""' >/dev/null 2>&1 ||
  warn "MagicDNS is off in your tailnet: you will connect by IP. Turn it on in the Tailscale admin console (DNS) to use the name instead."
expiry=$(tailscale status --json | jq -r '.Self.KeyExpiry // empty' | cut -c1-10)
if [ -n "$expiry" ]; then
  echo
  echo "  This machine's Tailscale key expires on $expiry. Once the firewall is on, Tailscale is the only"
  echo "  way in, so an expired key locks you out. In https://login.tailscale.com/admin/machines open"
  echo "  this machine's menu and choose 'Disable key expiry'. Do it now or before that date."
  echo
fi
