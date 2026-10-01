# Getting started

How work happens on this machine, from the first connection to a merged pull request. Read it once; the cheat sheet at the end is what you will come back to. If something looks off along the way, [troubleshooting.md](troubleshooting.md) covers what people hit on their first day.

## The pieces

| Piece | What it is |
|---|---|
| **Herdr** | The terminal you work in. One workspace per repo and one per task, a sidebar that shows what each agent is doing, and nothing is lost when you disconnect. Its server runs all the time as `dev`, so the workspaces exist before you open it. |
| `~/work/<repo>` | A clean copy of each repo, always on `main`. Nobody works here: it is the base that tasks start from. |
| `~/trees/<repo>--<task>` | One folder per task (a git worktree) with its own branch, ports and Herdr workspace. This is where agents work. |
| **Agents** | `claude` (Claude Code) and `gentle-shell` (Pi). Pick either, per task. Both read the same rules, `AGENTS.md` in the repo. |
| **engram** | Memory. One per repo, shared by all its tasks and by both agents, kept across sessions. |
| `ci-local` + **GGA** | The gate before any merge: the repo's checks, then GGA reviews the whole pull request against `AGENTS.md`, with NaN. |
| **Hermes** *(optional)* | An assistant on Telegram, on NaN, that can read the repos you share with it. |
| **Moshi** *(optional)* | The same Herdr from your phone, with a push when an agent needs you. |

## Herdr in two minutes

Herdr is a terminal with a sidebar. Each entry in the sidebar is a **workspace**: a shell parked in one folder. Click a workspace, or press `Ctrl-B W` and pick it, and you are there. Three kinds show up:

- `~`, your home. Run the kit's commands here: `repo-add`, `wt new`, `wt rm`.
- `<repo>`, for example `mi-landing`: the clean copy of a repo, on `main`. Look things up here, do not work here.
- `<repo>--<task>`, for example `mi-landing--pagina`: a task. This is where you open an agent.

Under "agents" in the sidebar, Herdr lists every agent that is running, in which task, and whether it is working, waiting for you, or done.

| Action | How |
|---|---|
| Switch workspace | Click it in the sidebar, or `Ctrl-B W` and choose |
| New tab in the current workspace | `Ctrl-B C` |
| Leave Herdr (everything keeps running) | `Ctrl-B Q` |
| Come back | `ssh -t dev@<machine-name> herdr` |
| Landed in a plain shell, `dev@...:~$`, no sidebar? | Type `herdr`: it attaches to the running session |
| Every key | `Ctrl-B ?` |

`Ctrl-B` is a prefix: press it, release, then press the letter.

## 1. Connect

From your computer:

```bash
ssh -t dev@<machine-name> herdr
```

`<machine-name>` is the name Tailscale gave the machine; the installer printed it at the end, something like `workstation-1.tail1234.ts.net`. `-t` gives Herdr a real terminal. If Herdr was already open, you land where you left it.

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

It asks one question: *Create AGENTS.md and CLAUDE.md and push them to main?* Answer **Y**. `AGENTS.md` is the rules file that every agent and GGA's review follow; without it they work blind. If you answered `n`, run the same `repo-add` again: it only does what is missing.

Add `--hermes` to let Hermes read the repo.

What `repo-add` leaves behind: the repo in `~/work/<repo>` with a hook that blocks deleting `main` on GitHub, the two rules files on `main`, a `<repo>` workspace in Herdr, a CodeGraph index of the code, and a first `ci-local` run. On a brand-new repo `ci-local` says it found no checks: expected until the repo has tests. GGA still reviews every pull request.

Open `AGENTS.md` and fill in what an agent needs to know about the project: stack, conventions, what never to touch. The template has the sections.

## 3. Start a task

A task is one thing you want done, with a short name you make up: `login`, `fix-prices`, `docs`. In `~`:

```bash
wt new <repo> <task>
```

Example: `wt new mi-landing pagina`. Use `wt new mi-landing typo fix` for a fix, or `chore` for housekeeping; `feat` is the default.

This creates the branch `feat/pagina`, the folder `~/trees/mi-landing--pagina`, ports of its own (in `.env.wt`), a workspace `mi-landing--pagina` in Herdr and a CodeGraph index. `main` is not touched.

Now **switch to the new workspace**: click `mi-landing--pagina` in the sidebar, or `Ctrl-B W`. It already sits in the task's folder. The one named just `mi-landing` is the clean copy on `main`; an agent opened there works on `main`, which is not what you want. Herdr's agent list shows the branch, so you can always tell which is which.

## 4. Open an agent

In the task's workspace:

```bash
claude
```

or

```bash
gentle-shell
```

gentle-shell prints a few lines of warnings from its extensions when it starts; they are harmless. Both agents follow `AGENTS.md`, both remember through engram, both can run the repo's checks. `Ctrl-B C` opens a second tab beside the agent when you want a shell for `git log` or a dev server.

## 5. Tell it what you want

Explain the task as you would to a person: what should change, what should not, how you will know it is done. End with one of these:

- **Let `wt rm` merge it** (the usual way): *"Commit when you are done. Do not push and do not open a PR."*
- **Let the agent merge it itself:** *"When you are done, run ci-local, open the PR and merge it if it is green."*

While it works, the sidebar shows whether the agent is busy, waiting for you, or done. Answer its questions in its workspace. When it is done, leave the agent with `/exit`.

**Seeing a dev server from your computer.** Each task has a port in `.env.wt` (`PORT=20010` for the first task). If the agent serves on the machine's Tailscale IP (`100.x.y.z:20010`), open that in your browser. If it serves on `127.0.0.1`, tunnel it: `ssh -L 20010:127.0.0.1:20010 dev@<machine-name>`, then open `http://localhost:20010`. The browser may call it "not secure": it is plain HTTP inside your tailnet, which Tailscale already encrypts.

## 6. Memory: engram is always on

Gentle AI connects engram to Claude Code, gentle-shell and Hermes. The memory belongs to the repo: a task in `~/trees/mi-landing--pagina` reads and writes the same memory as `~/work/mi-landing` and every other task of `mi-landing`, and it survives `wt rm`.

- **At the start of a task:** *"Check engram for earlier decisions about this before you start."*
- **When you decide something** that should outlive the task: *"Save that in engram."* Agents also save on their own.
- **Browse it yourself**, from any folder of the repo: `engram tui`, or `engram search "payments"`.

Hermes runs as its own user, so it has its own engram memory.

## 7. Close the task

In `~`:

```bash
wt rm <repo> <task>
```

If the branch has unmerged work, `wt rm` runs `ci-local` (the checks, then GGA's review of the whole pull request), pushes, opens the PR and merges it, only when everything is green. Then it removes the folder, the database if the task had one, the branch (here and on GitHub) and the Herdr workspace, and brings `~/work/<repo>` up to date. On a small server the review takes a minute or two; "Waiting for LM Studio" in its output is the name of the adapter GGA uses to talk to NaN, nothing to do with your machine.

If something is red, it removes nothing and tells you why. Fix it in the task and run `wt rm` again.

- Going to continue another day? Do not run `wt rm`. Just leave Herdr.
- Want to throw the task away without merging? `wt rm <repo> <task> --force`
- Uncommitted changes? `wt rm` refuses until the agent commits them, so nothing is lost by accident.

## 8. Several tasks at once

Each task has its own folder, branch, ports and workspace, so you can run several in parallel, each with its own agent. Four to six at a time is realistic on a small server. Tasks that touch the same files are better done one after another. `wt ls` shows what is open.

## 9. Coming back

Leave with `Ctrl-B Q`. Agents, servers and tests keep running. Come back with the same `ssh -t ... herdr` command and everything is where you left it, even if your connection dropped. The task workspaces you closed with `wt rm` are gone; the repo workspaces stay.

## Two days, end to end

Exactly what you type, with a repo called `mi-landing`. Lines without a prompt are what happens.

**Day one: a new repo, one task, done.**

```
ssh -t dev@<machine-name> herdr
                                  in ~:
repo-add <you>/mi-landing --new
                                  Create AGENTS.md ...? Y
                                  edit AGENTS.md if you have rules already
wt new mi-landing pagina
                                  Ctrl-B W, pick mi-landing--pagina
gentle-shell
                                  "Build a one-page landing for ... Serve it on
                                   the Tailscale IP, port 20010, so I can check it.
                                   Commit when done; do not push or open a PR."
                                  look at http://100.x.y.z:20010 from your laptop
/exit
                                  Ctrl-B W, back to ~
wt rm mi-landing pagina
                                  ci-local, GGA review, PR, merge, cleanup
Ctrl-B Q
```

**Day two: come back, another task, the agent remembers.**

```
ssh -t dev@<machine-name> herdr
                                  in ~:
wt new mi-landing contacto
                                  Ctrl-B W, pick mi-landing--contacto
claude
                                  "Check engram for what was decided about this
                                   site, then add a contact form. Commit when done;
                                   do not push or open a PR."
/exit
wt rm mi-landing contacto
```

## From your phone

Moshi attaches to the same Herdr session over Tailscale and can notify you when an agent needs you. See [phone.md](phone.md).

## Optional, per repo

`wt` and `ci-local` look for these files in a repo:

| File | What it does |
|---|---|
| `.wt/config` with `WT_PG_IMAGE=postgres:17` | Each task gets its own Postgres, and `DATABASE_URL` goes into `.env.wt`. |
| `.wt/compose.yaml` | Started with `docker compose` for each task, using the task's ports. |
| `.wt/setup` (executable) | Runs once when the task is created: dependencies, migrations, seed. |
| `.wt/ci` (executable) | Your repo's own checks for `ci-local`. Without it, `ci-local` works them out from the lockfile (uv, pnpm, npm), or runs only GGA's review if there is none. |

## Cheat sheet

```bash
ssh -t dev@<machine-name> herdr          # connect (or come back); in a plain shell: herdr

repo-add <owner>/<repo>                   # existing repo (answer Y to the rules files)
repo-add <owner>/<name> --new             # new repo, created on GitHub for you
repo-add <owner>/<repo> --hermes          # ... and let Hermes read it

wt new <repo> <task>                      # start a task, then switch to its workspace (Ctrl-B W)
claude                                    # or: gentle-shell, inside the task workspace
wt ls                                     # open tasks
wt rm <repo> <task>                       # merge what is left (if green) and clean up
wt rm <repo> <task> --force               # throw the task away

engram tui                                # browse the repo's memory
sudo kit-login <github|nan|claude|hermes> # change an account (plain ssh, as admin)
kit-moshi                                 # notifications on your phone
```
