# Helpers shared by install.sh, the modules and kit-login. Sourced, never executed.
# shellcheck shell=bash

KIT_DIR=${KIT_DIR:-/opt/workstation-kit}
if [ -f "$KIT_DIR/kit.conf" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$KIT_DIR/kit.conf"
  set +a
fi
ADMIN_USER=${ADMIN_USER:-admin}
DEV_USER=${DEV_USER:-dev}
export DEBIAN_FRONTEND=noninteractive
# needrestart: restart services quietly after upgrades instead of printing its scan on every apt run.
export NEEDRESTART_MODE=a NEEDRESTART_SUSPEND=1

log()  { printf '\033[1;34m▸\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m✗\033[0m %s\n' "$*" >&2; exit 1; }

enabled() { [ "${!1:-no}" = yes ]; }
home_of() { getent passwd "$1" | cut -d: -f6; }

# as_user USER CMD... — run a command as USER with its own tools on PATH (mise shims, ~/.local/bin).
as_user() {
  local u=$1 h
  shift
  h=$(home_of "$u")
  (cd /tmp && sudo -u "$u" -H env PATH="$h/.local/share/mise/shims:$h/.local/bin:/usr/local/bin:/usr/bin:/bin" "$@")
}

# as_user_tty USER CMD... — like as_user, for programs you interact with (logins, menus, codes to
# paste). runuser hands them this very terminal; a second sudo would put them behind its own
# pseudo-terminal, where some terminals stop passing keystrokes through. Needs root.
as_user_tty() {
  local u=$1 h
  shift
  h=$(home_of "$u")
  (cd /tmp && runuser -u "$u" -- env HOME="$h" USER="$u" LOGNAME="$u" \
    PATH="$h/.local/share/mise/shims:$h/.local/bin:/usr/local/bin:/usr/bin:/bin" "$@")
}

# user_systemctl USER ARGS... — systemctl --user for USER (needs lingering enabled).
user_systemctl() {
  local u=$1 uid
  shift
  uid=$(id -u "$u")
  (cd /tmp && sudo -u "$u" -H env XDG_RUNTIME_DIR="/run/user/$uid" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" systemctl --user "$@")
}

# wait_user_bus USER — after enable-linger, wait for the user's systemd to be up.
wait_user_bus() {
  local uid
  uid=$(id -u "$1")
  for _ in $(seq 1 20); do [ -S "/run/user/$uid/bus" ] && return 0; sleep 1; done
  die "systemd for $1 did not start (/run/user/$uid/bus)"
}

# confirm "question" — true only if the person types yes.
confirm() {
  local ans
  read -r -p "$1 Type 'yes' to continue: " ans </dev/tty
  [ "$ans" = yes ]
}

apt_install() { apt-get install -y -qq "$@" >/dev/null; }
