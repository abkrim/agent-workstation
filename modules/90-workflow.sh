#!/usr/bin/env bash
# The daily workflow: wt, repo-add, ci-local, claude-trust and kit-repos on everyone's PATH, the
# folders ~/work (your repos, always clean on main) and ~/trees (one worktree per task), and the
# guardrails every agent shares:
#   - a pre-push hook in each repo blocks deleting main on the remote (repo-add installs it);
#   - Claude Code and OpenCode refuse `git push --no-verify` and `gh repo delete`.
# Agents may push to main, merge PRs and delete branches: ci-local is the gate before a merge.
set -euo pipefail
# shellcheck disable=SC1091
. "$KIT_DIR/lib/common.sh"

for t in wt repo-add ci-local claude-trust kit-repos kit-guardrails shared-repos-sync kit-login; do
  chmod 755 "$KIT_DIR/bin/$t"
  ln -sfn "$KIT_DIR/bin/$t" "/usr/local/bin/$t"
done
chmod 755 "$KIT_DIR/bin/gentle-update"

h=$(home_of "$DEV_USER")
install -d -o "$DEV_USER" -g "$DEV_USER" -m 755 "$h/work" "$h/trees"
install -d -o "$DEV_USER" -g "$DEV_USER" -m 700 "$h/.config/workstation-kit"
if [ ! -f "$h/.config/workstation-kit/repos" ]; then
  cat <<'EOF' | install -o "$DEV_USER" -g "$DEV_USER" -m 600 /dev/stdin "$h/.config/workstation-kit/repos"
# Your repos (~/work/<name>), written by repo-add. One per line: name, owner/repo and options
# separated by commas. Option "hermes": Hermes gets a read-only copy in /srv/shared/repos.
EOF
fi

as_user "$DEV_USER" git config --global init.defaultBranch main
as_user "$DEV_USER" git config --global push.autoSetupRemote true

# Claude Code: deny rules merged into whatever is already there (gentle-ai's rules included).
install -d -o "$DEV_USER" -g "$DEV_USER" -m 700 "$h/.claude"
as_user "$DEV_USER" "$KIT_DIR/bin/kit-guardrails"
ok "workflow: wt, repo-add, ci-local; ~/work and ~/trees; guardrails for every agent"
