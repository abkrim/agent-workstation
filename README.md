# workstation-kit

Turn a fresh Ubuntu 24.04 server into a private, secure workstation for AI coding agents, in one command.

You get Claude Code, Pi (through gentle-shell), OpenCode and the Gentleman ecosystem side by side, with open-source models from [NaN](https://nan.builders) ready to use. One workflow fits all of them: one task, one worktree, one Herdr workspace, and checks that run on your own machine before every merge. Optionally, Hermes runs as a Telegram assistant that can read, but never write, the repos you choose.

Nothing here is tied to one AI. Pick whichever agent you like for each task. They all follow the same repo rules (`AGENTS.md`).

## What you need

- A fresh **Ubuntu 24.04** server (a VPS works well; 4 GB of RAM or more, 8+ if you run several agents at once).
- Your **SSH public key** on the server's root account (most VPS panels ask for it when you create the server).
- A free **[Tailscale](https://tailscale.com)** account, with Tailscale on the computer you connect from.
- A **GitHub** account.
- Optional, depending on what you use: a **NaN** API key, a **Claude** plan, a **Telegram** account for Hermes.

## Install

As root on the new server:

```bash
git clone https://github.com/lvega05/workstation-kit
./workstation-kit/install.sh
```

That's it. The console asks you everything along the way:

1. **A few settings:** user names, time zone, the machine's name, and whether you want Hermes and backups. Enter keeps the defaults.
2. **A password** for your admin user.
3. **A Tailscale link** to approve the machine in your tailnet.
4. **Two safety stops**, one before hardening SSH and one before turning the firewall on, so you can never lock yourself out. Each time, it asks you to log in over Tailscale from another terminal first.
5. **Your accounts:** GitHub, your NaN key (checked before it is saved), Claude Code, and the Telegram bot for Hermes. You can skip any of them and add it later with `sudo kit-login`.

Your answers are saved in `/opt/workstation-kit/kit.conf`. Edit that file and run the installer again to change anything.

From then on, connect from your computer with:

```bash
ssh -t dev@<machine-name> herdr
```

Then follow **[docs/getting-started.md](docs/getting-started.md)**.

## What it sets up

| Module | What you get |
|---|---|
| `10-users` | `admin` (sudo, with a password) and `dev` (no sudo) with your SSH key. |
| `20-base` | Updates, automatic security updates (no automatic reboots), fail2ban, your time zone. |
| `30-tailscale` | Tailscale: the only way in once the firewall is on. |
| `40-ssh` | SSH with keys only, no root, only `admin` and `dev`. |
| `50-firewall` | UFW: everything incoming denied except Tailscale. |
| `60-docker` | Docker, with nobody in the `docker` group, plus rootless Docker for `dev`. Ports bind to 127.0.0.1. |
| `70-runtimes` | Through [mise](https://mise.jdx.dev): Node 24, pnpm, Bun, Python, uv and Go. Plus the GitHub CLI. |
| `80-agents` | Claude Code; [gentle-shell](https://github.com/Gentleman-Programming/gentle-shell) (Pi) with the NaN provider; engram, gentle-ai and [GGA](https://github.com/Gentleman-Programming/gentleman-guardian-angel), refreshed from `main` every 3 hours; OpenCode; and [Herdr](https://herdr.dev) with the integrations for each agent. |
| `85-nan` | **nan-gate**, so all NaN clients together stay within your plan's limits. OpenCode and GGA on NaN, and two model profiles for gentle-shell: `opensource` (DeepSeek V4 Flash orchestrates) and `opensource-glm` (GLM 5.3 Flash orchestrates). |
| `90-workflow` | `wt`, `repo-add`, `ci-local` and `claude-trust`; `~/work` and `~/trees`; guardrails shared by every agent. |
| `92-hermes` | *(optional)* [Hermes Agent](https://hermes-agent.nousresearch.com) on Telegram, with NaN and read-only copies of the repos you share. |
| `95-backups` | *(optional)* Daily local, encrypted restic snapshots. |
| `99-credentials` | `kit-login`: GitHub, NaN, Claude Code and Hermes. |

## Daily use, in short

```bash
repo-add <owner>/<repo>      # once per repo: clone it, ready for any agent
wt new <repo> <task>         # a branch, folder, ports and Herdr workspace for one task
claude | gentle-shell | opencode
wt rm <repo> <task>          # merges what is left (only if ci-local is green) and cleans up
```

Details in **[docs/getting-started.md](docs/getting-started.md)**.

## Your accounts

`sudo kit-login` asks for each one and can be run again at any time, or one step at a time: `sudo kit-login github | nan | claude | hermes`. Secrets are stored with mode 600, only readable by their owner, and never go into this repo or `kit.conf`.

## Security

See **[docs/security.md](docs/security.md)**. In short: the server is reachable only through your tailnet, with SSH keys only and no root login. `dev`, the user the agents run as, has no sudo, and Docker runs rootless. Hermes can only read what you share with it. Security updates install themselves.

## Updating

```bash
cd /opt/workstation-kit && git pull && sudo ./install.sh
```

Every module is idempotent, so running it again is how you update. Run a single one with `sudo ./install.sh --only 85`. Your own changes to the agents' config files are kept: the kit only copies them when they are missing.

## Credits

workstation-kit puts together great tools made by others: Claude Code (Anthropic), the Gentleman Programming ecosystem (gentle-shell, Pi, engram, gentle-ai, GGA), OpenCode, Herdr, Hermes Agent (Nous Research), NaN, Tailscale, mise and restic. It is not affiliated with any of them.

## License

[MIT](LICENSE)
