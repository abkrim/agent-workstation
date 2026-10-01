#!/usr/bin/env bash
# SSH hardening: no root, no passwords, keys only, only ADMIN_USER and DEV_USER.
# Stops first until you confirm you can log in over Tailscale from another terminal.
set -euo pipefail
# shellcheck disable=SC1091
. "$KIT_DIR/lib/common.sh"

CONF=/etc/ssh/sshd_config.d/00-workstation-kit.conf  # 00- wins over 50-cloud-init.conf
host=$(tailscale status --json | jq -r .Self.DNSName | sed 's/\.$//')

if [ ! -f "$CONF" ]; then
  echo
  echo "  Before closing root and password logins, check that the new way in works."
  echo "  In ANOTHER terminal on your computer (keep this one open):"
  echo
  echo "      ssh $ADMIN_USER@$host"
  echo
  confirm "Did it log you in?" || die "Stopped before hardening SSH. Resume with: ./install.sh --from 40"
fi

cat > "$CONF" <<EOF
# Managed by workstation-kit (modules/40-ssh.sh)
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey
PermitEmptyPasswords no
AllowUsers $ADMIN_USER $DEV_USER
MaxAuthTries 3
LoginGraceTime 30
X11Forwarding no
EOF
chmod 644 "$CONF"
if ! sshd -t; then
  rm -f "$CONF"
  die "invalid sshd configuration; reverted"
fi
systemctl reload ssh  # open sessions stay open
ok "SSH: keys only, no root, only $ADMIN_USER and $DEV_USER"
