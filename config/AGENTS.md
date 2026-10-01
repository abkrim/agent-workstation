# AGENTS.md — {{NAME}}

Rules for any agent working in this repo (Claude Code, Pi/gentle-shell, OpenCode, ...).
This is the single source: `CLAUDE.md` only imports it, and GGA reviews every PR against it.
Created by `repo-add` (workstation-kit). Fill in the project sections as you learn them.

## Project

What it is, stack and layout: see `README.md`. Add here what an agent needs to know and the README does not say.

## Commands

- Every check, the same ones that run before each merge: `ci-local`
{{COMMANDS}}
## Workflow

- One task = one worktree = one branch: `wt new {{NAME}} <task>`. Never work in `~/work/{{NAME}}`, which stays clean on `main`.
- Branches `feat/`, `fix/` or `chore/`; rebase on `origin/main` often.
- Before merging, `ci-local` must be green (it includes GGA's review of the whole PR). Then open a PR and merge it with `gh pr merge`, and delete the branch.

## Non-negotiables

- Secrets stay out of the repo: no `.env`, keys or tokens in commits.
- No production or customer data in the repo or in worktrees.
- Never `git push --no-verify`, never delete `main`.
