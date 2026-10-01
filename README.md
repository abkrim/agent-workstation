# agent-workstation

Turn a fresh Ubuntu 24.04 server into a private workstation for AI coding agents. You clone this repo, run one script and answer a few questions.

You get [Claude Code](https://code.claude.com/docs) and Pi through [gentle-shell](https://github.com/Gentleman-Programming/gentle-shell) side by side, set up with [Gentle AI](https://github.com/Gentleman-Programming/gentle-ai), and open-source models from [NaN](https://nan.builders/docs) ready to use. One workflow fits both: one task, one worktree, one [Herdr](https://herdr.dev) workspace, and checks that run on your own machine before every merge. Optionally, [Hermes](https://hermes-agent.nousresearch.com) runs as your assistant on Telegram, also on NaN, and can read, but never write, the repos you choose.

Pick whichever agent you like for each task. They all follow the same repo rules (`AGENTS.md`).

## What you need

- A fresh **Ubuntu 24.04** server (a VPS works well; 4 GB of RAM or more, 8+ if you run several agents at once).
- Your **SSH public key** on the server's root account (most VPS panels ask for it when you create the server).
- A free **[Tailscale](https://tailscale.com/kb)** account, with Tailscale on the computer you connect from.
- A **GitHub** account.
- A **[NaN](https://nan.builders/docs)** API key, for gentle-shell, Hermes and the reviews of your pull requests.
- Optional: a **Claude** plan for Claude Code, and a **Telegram** account for Hermes.

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

Then follow **[docs/getting-started.md](docs/getting-started.md)**.

## Daily use, in short

```bash
repo-add <owner>/<repo>      # once per repo: clone it, ready for any agent (--new creates it on GitHub first)
wt new <repo> <task>         # a branch, folder, ports and Herdr workspace for one task
claude                       # or gentle-shell; both remember through engram
wt rm <repo> <task>          # merges what is left (only if ci-local is green) and cleans up
```

The whole way of working, from a server with no repos to a merged pull request, is in **[docs/getting-started.md](docs/getting-started.md)**. From a phone, use [Moshi](https://getmoshi.app) over Tailscale: **[docs/phone.md](docs/phone.md)**, with optional push notifications and approvals through `kit-moshi`.

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
| `90-workflow` | `wt`, `repo-add`, `ci-local` and `claude-trust`; `~/work` and `~/trees`; guardrails shared by every agent. |
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

[NaN's API](https://nan.builders/docs/api) is OpenAI-compatible. The kit uses it in three places:

- **gentle-shell:** GLM 5.3 Flash by default, with the two profiles above.
- **Hermes:** GLM 5.3 Flash.
- **GGA**, which reviews each pull request against `AGENTS.md` before it merges: GLM 5.3 Flash, through GGA's OpenAI-compatible provider. GGA runs inside `ci-local`, once per pull request, never on each commit.

All of them go through **nan-gate** (127.0.0.1:4880), which keeps the whole machine within your plan's simultaneous requests and per-minute limit, with Hermes first in line.

## Your accounts

`sudo kit-login` asks for each one and can be run again at any time, or one step at a time: `sudo kit-login github | nan | claude | hermes`. Secrets are stored with mode 600, only readable by their owner, and never go into this repo or `kit.conf`.

## Security

See **[docs/security.md](docs/security.md)**. In short:

- The server is reachable only through your tailnet, with SSH keys only and no root login.
- `dev`, the user the agents run as, has no sudo, and Docker runs rootless.
- Claude Code runs in [auto mode](https://code.claude.com/docs/en/permission-modes): a safety classifier reviews each action instead of asking you, and secrets are denied.
- Hermes asks before running any command, answers only you, and can only read what you share with it.
- Security updates install themselves.

## Updates

Every 3 hours, `gentle-update` brings the agents up to date on its own, as `dev` and at low priority:

- gentle-shell, engram, gentle-ai and GGA from their `main` branch;
- gentle-shell's packages, the NaN provider included;
- what gentle-ai set up in each agent (`gentle-ai sync`), and CodeGraph;
- Claude Code and Herdr, to their latest release.

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
