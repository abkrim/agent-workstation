# Getting started

## 1. Connect

From your computer:

```bash
ssh -t dev@<machine-name> herdr
```

> `-t` gives Herdr a real terminal. If Herdr was already open, you land where you left it.

## 2. New repo? (once per repo)

```bash
repo-add <owner>/<repo>
```

This makes the repo ready for any agent. Add `--hermes` to let Hermes read it.

## 3. Start a task

A task is **what you want to do**, with a short name you make up: `login`, `fix-prices`…

```bash
wt new <repo> <task>
```

Example: `wt new my-app first-task`

This creates a branch and a folder just for that task, so `main` is never touched. Click the new workspace in the left sidebar: `<repo>--<task>`.

> Never work in the workspace named just `<repo>`: that one is for looking.

## 4. Open an agent

Whichever you like:

- `claude`
- `gentle-shell` (Pi)

Both follow the same repo rules. Hermes, if you installed it, is on Telegram: message your bot.

## 5. Tell it what you want

Explain the task as you would to a person. End with:

> When you are done, run ci-local, open the PR and merge it if it is green.

If you want to review it yourself first, say: *"open the PR but do not merge it"*.

## 6. When you are done

```bash
wt rm <repo> <task>
```

If anything is left unmerged, `wt rm` runs `ci-local`, opens the PR and merges it, only when everything passes. Then it removes the task. If something fails, it removes nothing and tells you why.

- Going to continue another day? Do not run `wt rm`: just leave Herdr.
- Want to throw the task away without merging? `wt rm <repo> <task> --force`
- Which tasks are open? `wt ls`

## Herdr keys

| Action | Keys |
|---|---|
| Switch workspace | Click it in the left sidebar |
| Leave without closing anything | `Ctrl+b`, release, `q` |
| New tab | `Ctrl+b`, release, `c` |
| Show every key | `Ctrl+b`, release, `?` |

---

If your connection drops, nothing is lost: everything keeps running. Go back to step 1.

## Optional, per repo

`wt` and `ci-local` look for these files in a repo:

| File | What it does |
|---|---|
| `.wt/config` with `WT_PG_IMAGE=postgres:17` | Each task gets its own Postgres, and `DATABASE_URL` goes into `.env.wt`. |
| `.wt/compose.yaml` | Started with `docker compose` for each task, using the task's ports. |
| `.wt/setup` (executable) | Runs once when the task is created: dependencies, migrations, seed. |
| `.wt/ci` (executable) | Your repo's own checks for `ci-local`. Without it, `ci-local` works them out from the lockfile (uv, pnpm, npm). |
