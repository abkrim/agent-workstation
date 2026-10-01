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
ok "Tailscale: $(tailscale status --json | jq -r .Self.DNSName | sed 's/\.$//') ($(tailscale ip -4))"
