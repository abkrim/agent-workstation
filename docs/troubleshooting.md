# First day: what trips people up

Everything here happened to someone on their first run. None of it is broken; each one has a two-line answer.

## Connecting

**I ran `ssh dev@<machine>` and got a plain prompt, `dev@...:~$`, no sidebar.**
You skipped Herdr. Type `herdr` and it attaches to the running session. Next time, `ssh -t dev@<machine-name> herdr` takes you straight there.

**`WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!`**
Your computer remembers an earlier install of this server (same name or IP, new host key). If you did reinstall, run `ssh-keygen -R <machine-name>` on your computer (and the same with the IP if you ever used it) and connect again. If you did not reinstall anything, stop and find out why the key changed before you accept it.

**The machine vanished from my tailnet, and SSH does not answer.**
Most likely Tailscale's node key expired (180 days by default). Log in from your provider's web console as `root` and run `tailscale up`. Then disable key expiry for this machine in Tailscale's admin console so it does not happen again. [security.md](security.md) has the details.

## Repos and tasks

**`repo-add` asked about AGENTS.md and I said `n`.**
Run the same `repo-add` again and answer `Y`. It skips what is already done and only adds what is missing. Agents and GGA follow `AGENTS.md`; without it they have no rules for the repo.

**`ci-local` said "no checks found".**
Expected on a repo with no tests yet. GGA still reviews every pull request. When the repo has checks, put them in an executable `.wt/ci` (or let `ci-local` detect them from the lockfile).

**I opened `claude` or `gentle-shell` and it is on `main`.**
You are in the repo workspace (the one named just `<repo>`) instead of the task's (`<repo>--<task>`). Leave the agent (`/exit`), press `Ctrl-B W` and pick the task workspace. If you had not started a task yet, run `wt new <repo> <task>` in `~` first. If the agent already changed files on `main`, move them: `cd ~/work/<repo> && git stash`, then `cd ~/trees/<repo>--<task> && git stash pop`.

**gentle-shell prints warnings about extensions when it starts.**
Lines like "Extension package ... must be declared in peerDependencies" come from the extensions themselves. They are harmless; the agent works.

**The agent started a dev server. How do I see it?**
Each task has a port in `.env.wt` (`PORT=20010` for the first task). If the server listens on the machine's Tailscale IP, open `http://100.x.y.z:20010` from your laptop. If it listens on `127.0.0.1`, tunnel it: `ssh -L 20010:127.0.0.1:20010 dev@<machine-name>` and open `http://localhost:20010`. "Not secure" in the browser only means plain HTTP; your tailnet already encrypts it.

**`wt rm` says there are uncommitted changes.**
It refuses so nothing is lost. Ask the agent to commit, or do it yourself in `~/trees/<repo>--<task>`, and run `wt rm` again. To drop the task instead: `wt rm <repo> <task> --force`.

**`wt rm` prints "Waiting for LM Studio" and sits there.**
That is GGA reviewing the pull request. "LM Studio" is the name of the OpenAI-compatible adapter it uses to reach NaN through nan-gate; nothing on your machine is involved. A review takes a minute or two on a small server. If NaN does not answer twice, `ci-local` says so and the PR goes without the review.

**`wt rm` was red. What now?**
Read the output: either a check failed or GGA found a problem against `AGENTS.md`. Nothing was removed. Go back to the task workspace, have the agent fix it, commit, and run `wt rm` again.

## Hermes

**I pasted the Telegram token and `kit-login` rejected it.**
The token from @BotFather is one line, `digits:letters`. Make sure the whole line came through, then `sudo kit-login hermes` again. The kit checks the token against Telegram before saving anything.

**It asks for my Telegram user id.**
Send anything to @userinfobot; it answers with your numeric id. Paste the number (pasting the whole message also works, the kit takes the digits). Only that id can talk to your bot.

**The bot does not answer.**
Run `sudo kit-login hermes` again: it restarts Hermes's gateway after saving. If it still says nothing, as `admin`: `sudo journalctl _SYSTEMD_USER_UNIT=hermes-gateway.service -n 50`.

## Phone

**I ran `kit-moshi` from the phone and it shows a QR.**
You cannot scan a QR on the same screen. Press Ctrl+C: the connection step is skipped and it moves on to the pairing token. Add the connection in Moshi by hand instead (host, user `dev`, the phone's key via `kit-phone-key`), or run `kit-moshi connect` from your laptop another time. See [phone.md](phone.md).

**Moshi connected, but I only see a shell.**
Type `herdr`. Or use Moshi's Herdr tab, which lists the running sessions.

## Install

**I pasted my SSH key twice.**
The installer keeps one copy. Each accepted key prints "✓ added: <comment>"; Enter on an empty line continues.

**GitHub says "Permission denied" right after I added the key.**
GitHub takes a few seconds to pick up a new key. `kit-login` retries on its own; if it gives up, run `sudo kit-login github` again.

**The installer stopped at a module.**
It prints the exact command to resume, for example `sudo /opt/agent-workstation/install.sh --from 80`. Modules that already ran are safe to run again.
