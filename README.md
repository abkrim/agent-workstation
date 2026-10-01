# agent-workstation

A cloud machine where AI coding agents do the work and you steer, from your laptop or your phone. Clone this repo on a fresh Ubuntu 24.04 VPS, run one script, answer a few questions, and in about half an hour you have the server, the agents, the models, the memory and the workflow set up and kept up to date. Then you spend your time on your ideas instead of on the setup.

Inside: [Claude Code](https://code.claude.com/docs) and Pi through [gentle-shell](https://github.com/Gentleman-Programming/gentle-shell), set up by [Gentle AI](https://github.com/Gentleman-Programming/gentle-ai); [Hermes](https://hermes-agent.nousresearch.com) on Telegram if you want it; [Moshi](https://getmoshi.app) to reach it all from a phone.

The models come from [NaN](https://nan.builders) because of its privacy: it keeps no logs of prompts or responses, trains nothing on your code and processes in the European Union. That is why this project exists. Agents can read your whole codebase all day and your ideas go nowhere. One provider for everything also keeps the setup simple.

It is a workstation, not a production host: enough security that a cheap VPS on the internet does not become somebody else's, and nothing more in the way.

## How you work

1. **Open the workstation.** From your laptop, `ssh -t dev@<machine> herdr`. From your phone, open Moshi and tap the machine. Either way you land in [Herdr](https://herdr.dev), a terminal that keeps a workspace per repo and per task and never loses them when you disconnect.
2. **Start a task.** `wt new my-app login` gives that task its own branch, folder, ports and Herdr workspace. The repo's `main` is never touched.
3. **Hand it to an agent.** Open `claude` or `gentle-shell` in the task and say what you want, as you would to a person: "add login with magic links, run ci-local, open the PR and merge it if it is green."
4. **Go do something else.** The agent works. Herdr's sidebar shows whether it is busy, waiting for you or done. With Moshi, your phone gets a push when it needs an answer or an approval, and you can reply from the notification.
5. **Close the task.** `wt rm my-app login` runs the repo's checks and a review of the whole pull request by GGA against your rules; if everything is green it merges and cleans up. If not, it tells you what failed and leaves things in place.

Several tasks can run at once, each with its own agent. The agents share one memory per repo through engram, so what was decided in one task is known in the next, and the same rules file, `AGENTS.md`, applies to all of them.

## What you stop doing by hand

- **Hardening a server:** users, SSH with keys only, firewall that answers only inside your tailnet, automatic security updates, fail2ban.
- **Installing and updating agents:** Claude Code, gentle-shell, engram, gentle-ai, GGA, Herdr and their configuration, refreshed every 3 hours.
- **Wiring models:** NaN connected to gentle-shell, Hermes and the review step, with one gate so you never exceed your plan's limits.
- **Making agents behave the same:** `AGENTS.md` and `CLAUDE.md` in every repo, memory shared across tasks, guardrails that stop a `git push --no-verify` or a deleted `main`.
- **Juggling branches and ports:** one worktree per task, with ports and a database of its own if the repo asks for one.
- **Checking before merging:** tests and an AI review of every pull request, on your own machine, no paid CI.
- **Getting to it from the phone:** Mosh is installed; Moshi adds the machine from a QR.

## What you need

**Indispensable:**

- **Linux:** a fresh **Ubuntu 24.04** server. A VPS works well: 4 GB of RAM or more, 8+ if you run several agents at once. Your SSH public key on its root account (most VPS panels ask for it when you create the server).

**The models, NaN by default:**

- A **[NaN](https://nan.builders/docs)** API key. gentle-shell, Hermes and the review of every pull request all run on NaN out of the box, so there is one provider to pay, one key to enter and one place where limits are watched. Without it the installer still finishes, but those three sit idle until you add a key (Claude Code works on its own).
- **Why it is the default: privacy.** From NaN's [privacy policy](https://nan.builders/privacy): "The cluster keeps zero logs: we do not store your prompts or the model responses" and "Your code trains no models", with processing in the European Union. Your ideas stay yours while agents work on them all day.
- Want a discount? Sign up with my referral link: [cloud.nan.builders/r/2XHAG6MF](https://cloud.nan.builders/r/2XHAG6MF).

**Free accounts the setup relies on:**

- **[Tailscale](https://tailscale.com/kb)**, the only way into the machine, on the computer you connect from.
- **GitHub**, where your repos live.

**Optional:**

- A **Claude** plan, if you want Claude Code next to gentle-shell.
- A **Telegram** account, for Hermes.
- A phone with **[Moshi](https://getmoshi.app)** (free plan).

What stops the installer: a system other than Ubuntu 24.04, no SSH key, and the two safety stops, which wait until you have logged in over Tailscale. Everything asked by `kit-login` can be skipped and added later with `sudo kit-login <step>`; until then, without GitHub `repo-add` and merges do not work, and without NaN gentle-shell and Hermes have no model and pull requests go unreviewed. A download that fails halfway stops the module; `./install.sh --from <number>` resumes it.

## Install

As root on the new server (about 30 minutes on a small VPS; `apt install -y git` first if git is missing):

```bash
git clone https://github.com/lvega05/agent-workstation
./agent-workstation/install.sh
```

The console asks you everything along the way:

1. **A few settings:** user names, time zone, the machine's name, and whether you want Hermes and backups. Enter keeps the defaults.
2. **A password** for your admin user.
3. **A Tailscale link** to approve the machine in your tailnet.
4. **Two safety stops**, one before hardening SSH and one before turning the firewall on, so you can never lock yourself out. Each time, it asks you to log in over Tailscale from another terminal first.
5. **Your accounts:** GitHub, your NaN key (checked before it is saved), Claude Code, and the Telegram bot for Hermes. You can skip any of them and add it later with `sudo kit-login`.

Your answers are saved in `/opt/agent-workstation/kit.conf`. Edit that file and run the installer again to change anything. If the system updates brought a new kernel, the installer says so at the end: reboot when convenient.

From then on, connect from your computer with:

```bash
ssh -t dev@<machine-name> herdr
```

Then follow **[docs/getting-started.md](docs/getting-started.md)**, which walks through the whole way of working, from a server with no repos to a merged pull request.

## Daily use, in short

```bash
repo-add <owner>/<repo>      # once per repo: clone it, ready for any agent (--new creates it on GitHub first)
wt new <repo> <task>         # a branch, folder, ports and Herdr workspace for one task
claude                       # or gentle-shell; both remember through engram
wt rm <repo> <task>          # merges what is left (only if ci-local is green) and cleans up
```

## From your phone

[Moshi](https://getmoshi.app) (iOS and Android, free plan) is a terminal that connects straight to the machine over SSH or Mosh through Tailscale, with no relay in between. It lists your Herdr sessions in a tab; tap one and you are in the same workspaces as on your laptop, with the same `Ctrl-B` prefix.

Adding the machine takes a QR (`kit-moshi connect`) or one command with the phone's key (`kit-phone-key`). If you also want push notifications and approvals from the agents on your phone, `kit-moshi` installs Moshi's hook with conservative settings: it is a closed-source daemon from getmoshi.app, so the guide spells out exactly what it sends and what it never sends. All of it in **[docs/phone.md](docs/phone.md)**.

## What it sets up

| Module | What you get |
|---|---|
| `10-users` | `admin` (sudo, with a password) and `dev` (no sudo) with your SSH key. |
| `20-base` | Updates, automatic security updates (no automatic reboots), fail2ban, mosh, your time zone. |
| `30-tailscale` | Tailscale: the only way in once the firewall is on. |
| `40-ssh` | SSH with keys only, no root, only `admin` and `dev`. |
| `50-firewall` | UFW: everything incoming denied except Tailscale. |
| `60-docker` | Rootless Docker for `dev` (the system daemon stays off, nobody in the `docker` group). Ports bind to 127.0.0.1. |
| `70-runtimes` | Through [mise](https://mise.jdx.dev): Node 24, pnpm, Bun, Python, uv and Go. Plus the GitHub CLI. |
| `80-agents` | Claude Code; gentle-shell with the NaN provider; [engram](https://github.com/Gentleman-Programming/engram), gentle-ai and [GGA](https://github.com/Gentleman-Programming/gentleman-guardian-angel); Herdr with the integrations for each agent. |
| `85-nan` | **nan-gate**, so everything on the machine that uses NaN stays within your plan's limits. GGA reviews with NaN. Two model profiles for gentle-shell: `opensource-glm` (active, GLM 5.3 Flash orchestrates) and `opensource` (DeepSeek V4 Flash orchestrates); switch with `/gentle:profiles`. |
| `88-gentle-ai` | Gentle AI for Claude Code and gentle-shell, with the defaults of its own installer (see below), plus [CodeGraph](https://github.com/colbymchenry/codegraph). |
| `90-workflow` | `wt`, `repo-add`, `ci-local`, `claude-trust`, `kit-moshi` and `kit-phone-key`; `~/work` and `~/trees`; guardrails shared by every agent. |
| `92-hermes` | *(optional)* Hermes on Telegram, with NaN and GLM 5.3 Flash, Gentle AI, and read-only copies of the repos you share. |
| `95-backups` | *(optional)* Daily local, encrypted [restic](https://restic.net) snapshots. |
| `99-credentials` | `kit-login`: GitHub, NaN, Claude Code and Hermes. |

## Gentle AI

The kit runs gentle-ai for you with the defaults of its own installer, without asking:

| Setting | Value |
|---|---|
| Agents | Claude Code, gentle-shell (Pi), Hermes |
| Preset | `full-gentleman`: claude-theme, context7, persona, engram, gga, permissions, skills |
| Persona | neutral (no regional tone; technical artifacts in English) |
| Receipt-Driven Development | on |
| Community tool | CodeGraph, indexed for each repo and each task |

To change any of it, run `gentle-ai` as `dev`: its own screens show every option. `gentle-ai doctor` reports the health of the setup. It shows `pi not found in PATH`: that is expected, because here Pi is gentle-shell.

## Models and reviews

**Why NaN by default.** First, privacy: NaN states that it keeps no logs of prompts or responses, trains no models on your code and processes in the European Union ([privacy policy](https://nan.builders/privacy)), which is what you want when agents read your whole codebase all day. Then practicality: a provider priced for volume, an OpenAI-compatible API every tool already speaks, and open-source models (GLM, DeepSeek, Qwen) you can switch between freely. One provider for everything also means one key in `kit-login`, one gate for the limits and nothing to reconcile between tools. [NaN's API](https://nan.builders/docs/api) is that provider here; the kit uses it in three places:

- **gentle-shell:** GLM 5.3 Flash by default, with the two profiles above.
- **Hermes:** GLM 5.3 Flash.
- **GGA**, which reviews each pull request against `AGENTS.md` before it merges: GLM 5.3 Flash, through GGA's OpenAI-compatible provider. GGA runs inside `ci-local`, once per pull request, never on each commit.

All of them go through **nan-gate** (127.0.0.1:4880), which keeps the whole machine within your plan's limits, with Hermes first in line. NaN's limits are per key: 60 requests per minute, and 7 requests at once on the base plan or 10 on the premium one ([models](https://nan.builders/docs/models)). The installer asks how many this machine may use, so pick the plan with room for the agents you will run at the same time.

## Your accounts

`sudo kit-login` asks for each one and can be run again at any time, or one step at a time: `sudo kit-login github | nan | claude | hermes`. Secrets are stored with mode 600, only readable by their owner, and never go into this repo or `kit.conf`.

## Security

This is a development machine on the internet, so the goal is simple: nobody but you gets in, agents cannot damage the system, and a compromised piece cannot reach the others. See **[docs/security.md](docs/security.md)**. In short:

- The server is reachable only through your tailnet, with SSH keys only and no root login. The public IP answers nothing.
- `dev`, the user the agents run as, has no sudo, and Docker runs rootless.
- Claude Code runs in [auto mode](https://code.claude.com/docs/en/permission-modes): a safety classifier reviews each action instead of asking you, and secrets are denied.
- Hermes asks before running any command, answers only you, can only read what you share with it, and on the machine can reach only its model gate.
- Security updates install themselves.

For customer data, payments or anything regulated, treat this as a starting point and add what your case needs.

## Security checks done on a real install

Before the first release the kit was installed on a fresh VPS and checked from the outside and from the inside. What was run, so you can repeat it:

| Check | How | Result |
|---|---|---|
| Nothing answers on the public IP | From another server, TCP connects to 22, 80, 443, 2375, 2376, 4880, 4881, 7437, 8000 and 41641 | All closed |
| Only SSH over the tailnet | Same connects to the machine's Tailscale IP | Only 22 answers |
| SSH policy in force | `sshd_config.d/00-agent-workstation.conf`; login attempts as `root` and `hermes` over the tailnet | Both refused; `admin` and `dev` with keys only |
| Privileges | `id` of every user, `sudo -n true` as `dev`, `getent group docker` | Only `admin` has sudo; `dev`'s password locked; nobody in `docker` |
| Local listeners | `ss -tlnu` | nan-gate on 127.0.0.1 only; engram on a unix socket; Docker's system daemon off |
| Secrets | `ls -l` of the NaN key, GitHub token, Claude credentials, Hermes `.env` | All mode 600, owned by their user |
| Hermes isolation | As a Hermes-like user, `curl` to a `dev` service and to nan-gate on loopback | Service refused, nan-gate allowed |
| nan-gate sandbox | `systemd-analyze security nan-gate.service`, then a review through its GGA port | 1.1 (OK); review answered |
| Agent review | A pull request with a hard-coded API key, run through `wt rm` | GGA refused it; nothing merged |
| Firewall rules load | `iptables-restore --test` on the generated `after.rules` | OK |

Repeat the outside checks any time from your computer, with `<ip>` the server's public IP: `nc -zv -w 3 <ip> 22` should fail, and `ssh dev@<machine-name>` over Tailscale should work. `docs/security.md` has the model behind it.

## Updates

Every 3 hours, `gentle-update` brings the agents up to date on its own, as `dev` and at low priority:

- gentle-shell, engram, gentle-ai and GGA from their `main` branch;
- gentle-shell's packages, the NaN provider included;
- what gentle-ai set up in each agent (`gentle-ai sync`), and CodeGraph;
- Claude Code, Herdr and, if you installed it, Moshi's hook, to their latest release.

Hermes has its own copy of engram and gentle-ai, kept current the same way by `hermes-gentle-update`. If one part fails, the rest still update and the next run tries again. See what it did with `journalctl --user -u gentle-update` (as `dev`).

To update the kit itself:

```bash
cd /opt/agent-workstation && sudo git pull && sudo ./install.sh
```

Every module is idempotent, so running it again is how you update. Run a single one with `sudo ./install.sh --only 85`. Your own changes to the agents' config files are kept: the kit only copies them when they are missing.

## If something fails

The installer stops at the module that failed and tells you how to resume, for example `sudo /opt/agent-workstation/install.sh --from 80`. Modules that already ran are safe to run again.

## Learn more

| Tool | Docs |
|---|---|
| NaN | [nan.builders/docs](https://nan.builders/docs) · [API reference](https://nan.builders/docs/api) |
| Gentleman Programming | [github.com/Gentleman-Programming](https://github.com/Gentleman-Programming): [gentle-ai](https://github.com/Gentleman-Programming/gentle-ai), [gentle-shell](https://github.com/Gentleman-Programming/gentle-shell), [engram](https://github.com/Gentleman-Programming/engram), [GGA](https://github.com/Gentleman-Programming/gentleman-guardian-angel) |
| Hermes Agent | [hermes-agent.nousresearch.com/docs](https://hermes-agent.nousresearch.com/docs) |
| Claude Code | [code.claude.com/docs](https://code.claude.com/docs) |
| Tailscale | [tailscale.com/kb](https://tailscale.com/kb) |
| Herdr | [herdr.dev](https://herdr.dev) |
| Moshi | [getmoshi.app/docs](https://getmoshi.app/docs) |
| mise | [mise.jdx.dev](https://mise.jdx.dev) |

## Credits

agent-workstation puts together tools made by others: Claude Code (Anthropic), the Gentleman Programming tools (gentle-shell, Pi, engram, gentle-ai, GGA), Hermes Agent (Nous Research), NaN, Herdr, Moshi, CodeGraph, Tailscale, mise and restic. It is not affiliated with any of them.

## License

[MIT](LICENSE)
