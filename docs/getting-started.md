# Getting started

How work happens on this machine, from the first connection to a merged pull request. Read it once; the cheat sheet at the end is what you will come back to.

## The pieces

| Piece | What it is |
|---|---|
| **Herdr** | The terminal you work in. It keeps a workspace per repo and per task, shows in its sidebar what each agent is doing, and keeps everything running when you disconnect. |
| `~/work/<repo>` | A clean copy of each repo, always on `main`. Nobody works here: it is the base that tasks start from. |
| `~/trees/<repo>--<task>` | One folder per task (a git worktree) with its own branch, its own ports, and its own Herdr workspace. This is where agents work. |
| **Agents** | `claude` (Claude Code) and `gentle-shell` (Pi). Pick either, per task. Both read the same rules, `AGENTS.md` in the repo. |
| **engram** | Memory. Decisions and findings that persist across sessions. One memory per repo, shared by all its tasks and by both agents. |
| `ci-local` + **GGA** | The gate before any merge: the repo's checks, then GGA reviews the whole pull request against `AGENTS.md`, with NaN. |

## 1. Connect

From your computer:

```bash
ssh -t dev@<machine-name> herdr
```

> `-t` gives Herdr a real terminal. If Herdr was already open, you land where you left it.

The left sidebar lists your workspaces. `~` is a plain shell: that is where you run the commands below. Each repo and each task gets its own entry.

## 2. Add a repo (once per repo)

In the `~` workspace.

**You already have a repo on GitHub:**

```bash
repo-add <owner>/<repo>
```

**You are starting from nothing:**

```bash
repo-add <owner>/<new-name> --new
```

This creates the repo on GitHub first, private with a README (`--public` for a public one), then continues like any other repo.

Add `--hermes` to either if you want Hermes to be able to read it.

What `repo-add` leaves behind:

- the repo in `~/work/<repo>`, with a hook that blocks deleting `main` on GitHub;
- `AGENTS.md` (the rules every agent follows) and `CLAUDE.md` (which imports it), pushed to `main` if they were missing;
- a workspace for the repo in Herdr, and a CodeGraph index of the code;
- a first run of `ci-local`, so you know the repo is green before anyone touches it.

Open `AGENTS.md` and fill in what an agent needs to know about the project: stack, conventions, what never to touch. The template has the sections. The agents, GGA and Hermes all read it.

## 3. Start a task

A task is one thing you want done, with a short name you make up: `login`, `fix-prices`, `docs`. Still in `~`:

```bash
wt new <repo> <task>
```

Example: `wt new my-app login`. Use `wt new my-app typo fix` for a fix, or `chore` for housekeeping; `feat` is the default.

This creates the branch `feat/login`, the folder `~/trees/my-app--login`, ports of its own (in `.env.wt`), a Herdr workspace named `my-app--login`, and a CodeGraph index for it. `main` is not touched.

Click the new workspace in the sidebar. It already sits in the task's folder.

> Never work in the workspace named just `<repo>`. That is the clean copy for looking things up.

## 4. Open an agent

In the task's workspace:

```bash
claude
```

or

```bash
gentle-shell
```

Both follow `AGENTS.md`, both remember through engram, both can run the repo's checks. Open a second tab in the same workspace (`Ctrl+b`, release, `c`) if you want a shell beside the agent, for a dev server or for `git log`.

## 5. Tell it what you want

Explain the task as you would to a person: what should change, what should not, how you will know it is done. End with:

> When you are done, run ci-local, open the PR and merge it if it is green.

If you want to review the change yourself first:

> Open the PR but do not merge it.

While it works, the sidebar shows whether the agent is busy, waiting for you, or done. Answer its questions in its workspace.

## 6. Memory: engram is always on

Gentle AI connects engram to Claude Code, gentle-shell and Hermes, so every agent can save and search memories without any setup from you. The memory belongs to the repo: a task in `~/trees/my-app--login` reads and writes the same memory as `~/work/my-app` and every other task of `my-app`, and it survives `wt rm`.

Make it work for you:

- **At the start of a task**, tell the agent: *"Check engram for earlier decisions about this before you start."*
- **When you decide something** that should outlive the task (an architecture choice, a convention, a dead end): *"Save that in engram."* Agents also save on their own as they work.
- **Browse or search it yourself**, from any folder of the repo:

```bash
engram tui
engram search "payments"
```

Hermes runs as its own user, so it has its own engram memory: what it learns from the repos you share stays on its side.

## 7. Close the task

When the work is merged, or when you want it merged:

```bash
wt rm <repo> <task>
```

If the branch still has unmerged work, `wt rm` runs `ci-local` (checks, then GGA's review of the whole pull request), pushes, opens the PR and merges it, only when everything is green. Then it removes the folder, the database if the task had one, the branch (here and on GitHub) and the Herdr workspace, and brings `~/work/<repo>` up to date.

If something is red, it removes nothing and tells you why. Fix it in the task and run `wt rm` again.

- Going to continue another day? Do not run `wt rm`. Just leave Herdr.
- Want to throw the task away without merging? `wt rm <repo> <task> --force`
- Uncommitted changes? `wt rm` refuses until the agent commits them, so nothing is lost by accident.

## 8. Several tasks at once

Each task has its own folder, branch, ports and workspace, so you can run several in parallel, each with its own agent. Four to six at a time is realistic on a small server. Tasks that touch the same files are better done one after another.

```bash
wt ls
```

shows what is open, with ports and containers.

## From your phone

Moshi (iOS and Android, free) attaches to the same Herdr sessions over Tailscale, and can notify you when an agent needs you. See [phone.md](phone.md).

## Leaving and coming back

Leave Herdr with `Ctrl+b`, release, `q`. Agents, servers and tests keep running. Come back with the same `ssh -t ... herdr` command and everything is where you left it, even if your connection dropped.

## Herdr keys

| Action | Keys |
|---|---|
| Switch workspace | Click it in the left sidebar |
| New tab in this workspace | `Ctrl+b`, release, `c` |
| Leave without closing anything | `Ctrl+b`, release, `q` |
| Show every key | `Ctrl+b`, release, `?` |

## Optional, per repo

`wt` and `ci-local` look for these files in a repo:

| File | What it does |
|---|---|
| `.wt/config` with `WT_PG_IMAGE=postgres:17` | Each task gets its own Postgres, and `DATABASE_URL` goes into `.env.wt`. |
| `.wt/compose.yaml` | Started with `docker compose` for each task, using the task's ports. |
| `.wt/setup` (executable) | Runs once when the task is created: dependencies, migrations, seed. |
| `.wt/ci` (executable) | The repo's own checks for `ci-local`. Without it, `ci-local` works them out from the lockfile (uv, pnpm, npm). |

## Cheat sheet

```bash
ssh -t dev@<machine-name> herdr          # connect (or come back)

repo-add <owner>/<repo>                   # existing repo
repo-add <owner>/<name> --new             # new repo, created on GitHub for you
repo-add <owner>/<repo> --hermes          # ... and let Hermes read it

wt new <repo> <task>                      # start a task, then click its workspace
claude                                    # or: gentle-shell
wt ls                                     # open tasks
wt rm <repo> <task>                       # merge what is left (if green) and clean up
wt rm <repo> <task> --force               # throw the task away

engram tui                                # browse the repo's memory
sudo kit-login <github|nan|claude|hermes> # change an account
```
