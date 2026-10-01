#!/usr/bin/env bash
# workstation-kit installer. As root, on a fresh Ubuntu 24.04 server, from /opt/workstation-kit:
#
#   ./install.sh               every module, in order
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
[ "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)" = "$KIT_DIR" ] ||
  { echo "Clone the kit into $KIT_DIR and run it from there (see README)." >&2; exit 1; }
[ -f "$KIT_DIR/kit.conf" ] ||
  { echo "First: cp kit.conf.example kit.conf, and edit it." >&2; exit 1; }

for m in "$KIT_DIR"/modules/[0-9][0-9]-*.sh; do
  n=$(basename "$m"); n=${n%%-*}
  if [ -n "$ONLY" ]; then [ "$n" = "$ONLY" ] || continue
  elif (( 10#$n < 10#$FROM )); then continue
  fi
  printf '\n\033[1m══════ %s ══════\033[0m\n' "$(basename "$m" .sh)"
  KIT_DIR=$KIT_DIR bash "$m" || {
    echo
    echo "Module $(basename "$m") failed. Fix the cause and resume with: ./install.sh --from $n" >&2
    exit 1
  }
done

[ -n "$ONLY" ] || printf '\n\033[1;32mDone.\033[0m Daily use: docs/getting-started.md\n'
