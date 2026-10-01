#!/usr/bin/env bash
# workstation-kit installer. As root, on a fresh Ubuntu 24.04 server:
#
#   ./install.sh               asks a few questions the first time, then runs every module
#   ./install.sh --from 60     resume from module 60
#   ./install.sh --only 85     run a single module
#
# Every module is idempotent: running it again is safe, and it is also how you update.
set -euo pipefail

KIT_DIR=/opt/workstation-kit
FROM=00
ONLY=""
case "${1:-}" in
  --from) FROM=${2:?--from needs a module number} ;;
  --only) ONLY=${2:?--only needs a module number} ;;
  "") ;;
  *) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac

[ "$(id -u)" = 0 ] || { echo "Run as root: sudo ./install.sh" >&2; exit 1; }
# shellcheck disable=SC1091
. /etc/os-release
[ "$ID $VERSION_ID" = "ubuntu 24.04" ] || { echo "Ubuntu 24.04 only (this is $PRETTY_NAME)" >&2; exit 1; }

# The kit lives in /opt/workstation-kit, where every user can read it. Cloned somewhere else, it
# copies itself there and carries on from the copy.
SRC=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
if [ "$SRC" != "$KIT_DIR" ]; then
  if [ ! -e "$KIT_DIR" ]; then
    cp -a "$SRC" "$KIT_DIR"
    echo "Copied the kit to $KIT_DIR"
  else
    echo "Using the kit already in $KIT_DIR (update it with: git -C $KIT_DIR pull)"
  fi
  exec "$KIT_DIR/install.sh" "$@"
fi
chown -R root:root "$KIT_DIR"
chmod -R go-w "$KIT_DIR"

ask() {  # ask VAR "question" default
  local answer
  read -r -p "  $2 [$3]: " answer </dev/tty
  printf -v "$1" '%s' "${answer:-$3}"
}
yes_no() {  # yes_no VAR "question" default(yes|no)
  local answer
  read -r -p "  $2 [$([ "$3" = yes ] && echo Y/n || echo y/N)]: " answer </dev/tty
  case "${answer:-$3}" in [Yy]*) printf -v "$1" yes ;; *) printf -v "$1" no ;; esac
}

if [ ! -f "$KIT_DIR/kit.conf" ]; then
  printf '\n\033[1mworkstation-kit setup\033[0m — Enter keeps the value in brackets.\n\n'
  ask ADMIN_USER "Your admin user (sudo)" admin
  ask DEV_USER "User for your repos and the coding agents (no sudo)" dev
  ask TIMEZONE "Time zone (e.g. America/Mexico_City)" "$(timedatectl show -p Timezone --value 2>/dev/null || echo UTC)"
  timedatectl list-timezones | grep -qx "$TIMEZONE" || { echo "  unknown time zone, using UTC"; TIMEZONE=UTC; }
  ask TAILSCALE_HOSTNAME "Name of this machine in your tailnet" workstation
  # SSH keys for both users: root's (what the VPS panel set up) and/or any you paste.
  SSH_PUBLIC_KEY=""
  key_re='^(ssh-|ecdsa-|sk-)'
  if grep -qE "$key_re" /root/.ssh/authorized_keys 2>/dev/null; then
    echo "  SSH keys on root: $(grep -E "$key_re" /root/.ssh/authorized_keys | awk '{print $3}' | paste -sd, -)"
    reuse=yes
    yes_no reuse "Allow them for $ADMIN_USER and $DEV_USER?" yes
    [ "$reuse" = no ] || SSH_PUBLIC_KEY=$(grep -E "$key_re" /root/.ssh/authorized_keys)
  fi
  while :; do
    read -r -p "  Paste another SSH public key to allow (Enter when done): " extra </dev/tty
    [ -n "$extra" ] || break
    if [[ "$extra" =~ $key_re ]]; then
      SSH_PUBLIC_KEY=$(printf '%s\n%s' "$SSH_PUBLIC_KEY" "$extra" | sed '/^$/d' | awk '!seen[$1 " " $2]++')
    else
      echo "  that is not an SSH public key (it starts with ssh-ed25519, ssh-rsa, ecdsa-...)"
    fi
  done
  [ -n "$SSH_PUBLIC_KEY" ] || { echo "At least one SSH key is needed to log in." >&2; exit 1; }
  yes_no INSTALL_HERMES "Install Hermes, a Telegram assistant that can read the repos you share?" yes
  yes_no INSTALL_BACKUPS "Daily local backups of your work (restic)?" yes
  ask NAN_MAX_CONCURRENT "NaN: simultaneous requests this machine may use (your plan's limit)" 4

  sed -e "s|^ADMIN_USER=.*|ADMIN_USER=$ADMIN_USER|" \
      -e "s|^DEV_USER=.*|DEV_USER=$DEV_USER|" \
      -e "s|^TIMEZONE=.*|TIMEZONE=$TIMEZONE|" \
      -e "s|^TAILSCALE_HOSTNAME=.*|TAILSCALE_HOSTNAME=$TAILSCALE_HOSTNAME|" \
      -e "s|^INSTALL_HERMES=.*|INSTALL_HERMES=$INSTALL_HERMES|" \
      -e "s|^INSTALL_BACKUPS=.*|INSTALL_BACKUPS=$INSTALL_BACKUPS|" \
      -e "s|^NAN_MAX_CONCURRENT=.*|NAN_MAX_CONCURRENT=$NAN_MAX_CONCURRENT|" \
      "$KIT_DIR/kit.conf.example" |
    KEYS="$SSH_PUBLIC_KEY" awk '/^SSH_PUBLIC_KEY=/ { print "SSH_PUBLIC_KEY=\"" ENVIRON["KEYS"] "\""; next } { print }' \
    > "$KIT_DIR/kit.conf"
  chmod 644 "$KIT_DIR/kit.conf"
  printf '\n  Saved in %s (edit it and run ./install.sh again to change anything).\n' "$KIT_DIR/kit.conf"
  printf '  Next: the install itself. It stops to ask for a password, a Tailscale login and your accounts.\n\n'
  read -r -p "  Press Enter to start (Ctrl+C to stop here) " _ </dev/tty
fi

for m in "$KIT_DIR"/modules/[0-9][0-9]-*.sh; do
  n=$(basename "$m"); n=${n%%-*}
  if [ -n "$ONLY" ]; then [ "$n" = "$ONLY" ] || continue
  elif (( 10#$n < 10#$FROM )); then continue
  fi
  printf '\n\033[1m══════ %s ══════\033[0m\n' "$(basename "$m" .sh)"
  KIT_DIR=$KIT_DIR bash "$m" || {
    echo
    echo "Module $(basename "$m") failed. Fix the cause and resume with: sudo $KIT_DIR/install.sh --from $n" >&2
    exit 1
  }
done

if [ -z "$ONLY" ]; then
  # shellcheck disable=SC1091
  . "$KIT_DIR/kit.conf"
  host=$(tailscale status --json 2>/dev/null | jq -r .Self.DNSName | sed 's/\.$//')
  printf '\n\033[1;32mAll set.\033[0m From your computer (with Tailscale on):\n\n'
  printf '    ssh -t %s@%s herdr\n\n' "${DEV_USER:-dev}" "${host:-$TAILSCALE_HOSTNAME}"
  printf 'Then: repo-add <owner>/<repo>, and see %s/docs/getting-started.md\n' "$KIT_DIR"
fi
