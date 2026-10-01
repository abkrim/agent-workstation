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
for line in 'eval "$(mise activate bash)"' 'export PATH="$HOME/.local/bin:$PATH"'; do
  grep -qxF "$line" "$h/.bashrc" || echo "$line" >> "$h/.bashrc"
done
install -d -o "$DEV_USER" -g "$DEV_USER" -m 755 "$h/.local" "$h/.local/bin"

log "installing runtimes for $DEV_USER (several minutes the first time)"
as_user "$DEV_USER" mise use -g --yes node@24 pnpm@latest bun@latest python@3.13 uv@latest go@latest >/dev/null
as_user "$DEV_USER" mise ls --current
ok "runtimes for $DEV_USER"
