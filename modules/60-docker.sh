#!/usr/bin/env bash
# Docker for DEV_USER in rootless mode, which is what the agents use: its daemon runs as dev, in
# its own user namespace, so a container escape lands in dev, not root. Docker's packages bring a
# system daemon too; it stays installed but disabled (nobody is in the docker group, which would
# equal root). Published ports default to 127.0.0.1: Docker bypasses the firewall, so nothing
# gets exposed by accident.
set -euo pipefail
# shellcheck disable=SC1091
. "$KIT_DIR/lib/common.sh"

if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
  install -d -m 755 /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -qq
fi
apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
  docker-ce-rootless-extras uidmap dbus-user-session slirp4netns

DAEMON='{
  "ip": "127.0.0.1",
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" }
}'
install -d -m 755 /etc/docker
printf '%s\n' "$DAEMON" > /etc/docker/daemon.json  # in case someone enables the system daemon later
systemctl disable --now docker.service docker.socket containerd.service >/dev/null 2>&1 || true

members=$(getent group docker | cut -d: -f4)
[ -z "$members" ] || warn "the docker group has members ($members): that is root access for them"

# Ubuntu 24.04 restricts unprivileged user namespaces; Docker's official profile for rootlesskit.
cat > /etc/apparmor.d/usr.bin.rootlesskit <<'EOF'
# Managed by workstation-kit (modules/60-docker.sh)
abi <abi/4.0>,
include <tunables/global>

"/usr/bin/rootlesskit" flags=(unconfined) {
  userns,

  include if exists <local/usr.bin.rootlesskit>
}
EOF
apparmor_parser -r /etc/apparmor.d/usr.bin.rootlesskit

h=$(home_of "$DEV_USER")
install -d -o "$DEV_USER" -g "$DEV_USER" -m 700 "$h/.config" "$h/.config/docker"
printf '%s\n' "$DAEMON" | install -o "$DEV_USER" -g "$DEV_USER" -m 600 /dev/stdin "$h/.config/docker/daemon.json"
uid=$(id -u "$DEV_USER")
if ! user_systemctl "$DEV_USER" is-active --quiet docker; then
  (cd /tmp && sudo -u "$DEV_USER" -H env XDG_RUNTIME_DIR="/run/user/$uid" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" dockerd-rootless-setuptool.sh install >/dev/null)
fi
user_systemctl "$DEV_USER" enable docker >/dev/null 2>&1
user_systemctl "$DEV_USER" restart docker
as_user "$DEV_USER" docker context use rootless >/dev/null
ok "rootless Docker for $DEV_USER (ports on 127.0.0.1); the system daemon stays off"
