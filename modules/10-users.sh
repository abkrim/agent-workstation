#!/usr/bin/env bash
# Users: ADMIN_USER (sudo with a password) and DEV_USER (no sudo) with your SSH key, the shared
# group "agents" and /srv/shared (where Hermes reads the repos you share with it).
set -euo pipefail
# shellcheck disable=SC1091
. "$KIT_DIR/lib/common.sh"

getent group agents >/dev/null || groupadd agents

# new_user NAME COMMENT — if a group with that name already exists (Ubuntu ships an "admin" group),
# the user joins it instead of failing to create its own.
new_user() {
  id "$1" &>/dev/null && return 0
  if getent group "$1" >/dev/null; then useradd -m -s /bin/bash -g "$1" -c "$2" "$1"
  else useradd -m -s /bin/bash -c "$2" "$1"
  fi
}
new_user "$ADMIN_USER" "Administrator"
usermod -aG sudo "$ADMIN_USER"
new_user "$DEV_USER" "Coding agents"
usermod -aG agents "$DEV_USER"
chmod 750 "$(home_of "$DEV_USER")"

# sudo always asks for the admin password: set one now if it has none.
if [ "$(passwd -S "$ADMIN_USER" | awk '{print $2}')" != P ]; then
  log "Choose a password for $ADMIN_USER (sudo will ask for it)"
  passwd "$ADMIN_USER" </dev/tty
fi

# SSH keys: from kit.conf, or the ones root already has.
keys=${SSH_PUBLIC_KEY:-}
[ -n "$keys" ] || keys=$(cat /root/.ssh/authorized_keys 2>/dev/null || true)
keys=$(printf '%s\n' "$keys" | grep -E '^(ssh-|ecdsa-|sk-)' | awk '!seen[$1 " " $2]++' || true)
[ -n "$keys" ] || die "No SSH public key: set SSH_PUBLIC_KEY in kit.conf or add one to /root/.ssh/authorized_keys"
for u in "$ADMIN_USER" "$DEV_USER"; do
  h=$(home_of "$u")
  install -d -o "$u" -g "$u" -m 700 "$h/.ssh"
  printf '%s\n' "$keys" | install -o "$u" -g "$u" -m 600 /dev/stdin "$h/.ssh/authorized_keys"
done
ok "SSH key(s) installed for $ADMIN_USER and $DEV_USER"

# /srv/shared: only members of agents; setgid so new files keep the group.
install -d -o root -g agents -m 2750 /srv/shared
install -d -o "$DEV_USER" -g agents -m 2750 /srv/shared/repos

# The dev user's services (rootless Docker, timers) run without an open session.
loginctl enable-linger "$DEV_USER"
wait_user_bus "$DEV_USER"
ok "users ready: $ADMIN_USER (sudo), $DEV_USER (no sudo)"
