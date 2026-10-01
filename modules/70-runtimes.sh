#!/usr/bin/env bash
# Languages for DEV_USER through mise: Node 24, pnpm, Bun, Python 3.13, uv (brings any other Python
# a project asks for) and Go. Also the GitHub CLI (gh) for everyone.
set -euo pipefail
# shellcheck disable=SC1091
. "$KIT_DIR/lib/common.sh"

if ! command -v mise >/dev/null; then
  install -d -m 755 /etc/apt/keyrings
  curl -fsSL https://mise.jdx.dev/gpg-key.pub -o /etc/apt/keyrings/mise-archive-keyring.asc
  echo "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.asc arch=$(dpkg --print-architecture)] https://mise.jdx.dev/deb stable main" \
    > /etc/apt/sources.list.d/mise.list
  apt-get update -qq
  apt_install mise
fi

if ! command -v gh >/dev/null; then
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    -o /etc/apt/keyrings/githubcli-archive-keyring.gpg
  chmod 644 /etc/apt/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list
  apt-get update -qq
  apt_install gh
fi

h=$(home_of "$DEV_USER")
# The tools go on PATH at the very top of .bashrc. Ubuntu's .bashrc stops early in non-interactive
# shells, which is what `ssh dev@host herdr` gets: anything added at the end is never read there.
marker="# agent-workstation: tools on PATH"
if ! grep -qF "$marker" "$h/.bashrc"; then
  { echo "$marker, also for 'ssh $DEV_USER@host <command>' (must stay above the interactive check)"
    echo 'export PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"'
    echo
    cat "$h/.bashrc"
  } > "$h/.bashrc.kit" && mv "$h/.bashrc.kit" "$h/.bashrc"
  chown "$DEV_USER:$DEV_USER" "$h/.bashrc"
fi
line='eval "$(mise activate bash)"'
grep -qxF "$line" "$h/.bashrc" || echo "$line" >> "$h/.bashrc"
install_user_env "$DEV_USER"
install -d -o "$DEV_USER" -g "$DEV_USER" -m 755 "$h/.local" "$h/.local/bin"

log "installing runtimes for $DEV_USER (several minutes the first time)"
as_user "$DEV_USER" mise use -g --yes node@24 pnpm@latest bun@latest python@3.13 uv@latest go@latest >/dev/null
as_user "$DEV_USER" mise ls --current
ok "runtimes for $DEV_USER"
