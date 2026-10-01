# Helpers shared by install.sh, the modules and kit-login. Sourced, never executed.
# shellcheck shell=bash

KIT_DIR=${KIT_DIR:-/opt/agent-workstation}
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

# as_user USER CMD...: run a command as USER with its own tools on PATH (mise shims, ~/.local/bin).
as_user() {
  local u=$1 h
  shift
  h=$(home_of "$u")
  (cd /tmp && sudo -u "$u" -H env PATH="$h/.local/share/mise/shims:$h/.local/bin:/usr/local/bin:/usr/bin:/bin" "$@")
}

# as_user_tty USER CMD...: like as_user, for programs you interact with (logins, menus, codes to
# paste). runuser hands them this very terminal; a second sudo would put them behind its own
# pseudo-terminal, where some terminals stop passing keystrokes through. Needs root.
as_user_tty() {
  local u=$1 h
  shift
  h=$(home_of "$u")
  (cd /tmp && runuser -u "$u" -- env HOME="$h" USER="$u" LOGNAME="$u" \
    PATH="$h/.local/share/mise/shims:$h/.local/bin:/usr/local/bin:/usr/bin:/bin" "$@")
}

# user_systemctl USER ARGS...: systemctl --user for USER (needs lingering enabled).
user_systemctl() {
  local u=$1 uid
  shift
  uid=$(id -u "$u")
  (cd /tmp && sudo -u "$u" -H env XDG_RUNTIME_DIR="/run/user/$uid" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" systemctl --user "$@")
}

# wait_user_bus USER: after enable-linger, wait for the user's systemd to be up.
wait_user_bus() {
  local uid
  uid=$(id -u "$1")
  for _ in $(seq 1 20); do [ -S "/run/user/$uid/bus" ] && return 0; sleep 1; done
  die "systemd for $1 did not start (/run/user/$uid/bus)"
}

# engram_env USER: the environment that keeps engram's HTTP API off TCP. By default `engram serve`
# listens on 127.0.0.1:7437 with no authentication for reads, so any local user could read that
# user's memories. On a unix socket inside the user's runtime directory (mode 700) only the user
# itself can connect. Clients (the Claude Code hook, the CLI) honor the same variable.
engram_env() { printf 'ENGRAM_SOCKET=/run/user/%s/engram.sock' "$(id -u "$1")"; }

# install_user_env USER: the same variables for the user's shells (.bashrc, at the top, so they
# also reach `ssh user@host <command>`) and for the user's systemd services (environment.d).
install_user_env() {
  local u=$1 h
  h=$(home_of "$u")
  install -d -o "$u" -g "$u" -m 700 "$h/.config" "$h/.config/environment.d"
  printf '# Managed by agent-workstation (lib/common.sh install_user_env)\n%s\n' "$(engram_env "$u")" |
    install -o "$u" -g "$u" -m 600 /dev/stdin "$h/.config/environment.d/50-agent-workstation.conf"
  local marker="# agent-workstation: engram over a unix socket"
  if ! grep -qF "$marker" "$h/.bashrc" 2>/dev/null; then
    { echo "$marker (only this user can connect)"
      echo "export $(engram_env "$u")"
      echo
      cat "$h/.bashrc" 2>/dev/null
    } > "$h/.bashrc.kit" && mv "$h/.bashrc.kit" "$h/.bashrc"
    chown "$u:$u" "$h/.bashrc"
  fi
  # the user's systemd reads environment.d on start and on daemon-reload
  user_systemctl "$u" daemon-reload >/dev/null 2>&1 || true
}

# tailscale_host: this machine's name in the tailnet (MagicDNS), or its Tailscale IP when MagicDNS
# is off. What people type after ssh user@.
tailscale_host() {
  local h
  h=$(tailscale status --json 2>/dev/null | jq -r '.Self.DNSName // empty' | sed 's/\.$//')
  [ -n "$h" ] || h=$(tailscale ip -4 2>/dev/null | head -1)
  printf '%s' "$h"
}

# confirm "question": true only if the person types yes.
confirm() {
  local ans
  read -r -p "$1 Type 'yes' to continue: " ans </dev/tty
  [ "$ans" = yes ]
}

apt_install() { apt-get install -y -qq "$@" >/dev/null; }
