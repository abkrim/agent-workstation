# Security model

A basic layer that is reasonable for a personal workstation exposed to the internet. Review it against your own needs.

## Getting in

- **Tailscale only.** UFW denies everything incoming except the `tailscale0` interface. The public IP answers nothing, not even SSH.
- **SSH:** keys only (no passwords), no root login, and only `admin` and `dev` may log in (`/etc/ssh/sshd_config.d/00-workstation-kit.conf`).
- **fail2ban** watches SSH. It never bans your tailnet (100.64.0.0/10).
- **Lockout protection:** the installer stops before SSH hardening and before the firewall until you confirm that you can log in over Tailscale.

## Users and privileges

| User | Purpose | sudo | SSH |
|---|---|---|---|
| `root` | Emergencies only, from your provider's web console | No | No |
| `admin` | You, for administration | Yes, with a password | Yes |
| `dev` | Your repos and the coding agents | **No** | Yes |
| `hermes` | Hermes Agent *(optional)* | No | No |
| `restic` | Local backups *(optional)*. It can read everything and write only its repository | No | No |

- `dev` uses **rootless Docker**: its daemon runs as `dev`, so a container escape lands in `dev`, not root. Docker's system daemon stays disabled, and nobody is in the `docker` group, which would amount to root. Published ports default to 127.0.0.1.
- Agents run as `dev`, so a misbehaving agent can damage `dev`'s files, not the system.

## Agents and repos

- **Claude Code runs in auto mode.** A second model, a safety classifier, reviews each action instead of asking you. Anthropic reserves `bypassPermissions` (no checks at all) for isolated containers or VMs without internet access ([permission modes](https://code.claude.com/docs/en/permission-modes)), and this machine is online with your GitHub and NaN credentials. Gentle AI's `permissions` component sets `bypassPermissions`; `kit-guardrails` moves it back to auto after every install and every `gentle-ai sync`. To keep bypass anyway, create `~/.config/workstation-kit/allow-bypass` as `dev`.
- Deny rules apply in every mode, auto included: Gentle AI denies reading or editing secrets (`.env`, `.ssh`, keys, credentials, `gh`'s token) and destructive commands like `rm -rf ~`; the kit adds `git push --no-verify` and `gh repo delete`.
- A `pre-push` hook in every repo blocks **deleting `main`** on the remote.
- `ci-local` (tests plus GGA's review of the whole PR) is the gate before any merge, both for agents and for `wt rm`.
- `claude-trust` only marks folders under `~/work` and `~/trees`, your own repos, as trusted.
- nan-gate holds the machine's NaN key only to add it to GGA's reviews, on its own local port (127.0.0.1:4881). systemd hands it the key as a credential that only the gate can read. Any local user could send requests to that port, so it spends your NaN quota, never more: the users on this machine already hold the key or cannot log in.

## Hermes

- Hermes runs as its own user, with no sudo, no SSH and no GitHub credentials.
- It reads **only** the repos you share with `repo-add --hermes`. They are copies in `/srv/shared/repos`, refreshed hourly by `dev`, that Hermes can read but not write. It cannot see `~dev`.
- Every command it wants to run needs your approval, and scheduled jobs cannot run commands.
- It has its own copy of engram and gentle-ai, built in its own home: nothing from `dev` runs as Hermes.
- Only your Telegram user id can talk to the bot.

## Secrets

- They are asked for by `kit-login`, never put in `kit.conf` or in this repo.
- They are stored with mode 600, readable only by the user that needs them, and never passed on a command line, where other users could see them.

## What you trust

The kit installs software from other projects. Know where it comes from:

- **Ubuntu, Docker, Tailscale, GitHub CLI, mise:** their signed apt repositories.
- **Claude Code and Hermes:** their official install scripts, fetched over HTTPS and run as `dev` and `hermes`, never as root.
- **gentle-shell, engram, gentle-ai, GGA:** built from the `main` branch of their GitHub repositories, as `dev` (and `hermes` for its own copy), every 3 hours. You get fixes fast, and you also get whatever lands on `main`. Pin a version by editing `bin/gentle-update` if you prefer.
- **Pi packages, CodeGraph, context7:** from npm, as `dev`.
- **Models:** your prompts and code go to NaN (and to Anthropic when you use Claude Code). Read their terms.

Nothing runs as root except the kit's own modules and the system services it configures.

## Updates and backups

- Ubuntu security updates install automatically. Reboots are up to you: the installer tells you when one is pending, and later `cat /var/run/reboot-required` does.
- The Gentleman tools follow their `main` branch and refresh every 3 hours. Other tools update when you re-run the installer, and Claude Code updates itself.
- Local backups (optional) are encrypted with restic. **Save the restic password somewhere else**: without it they cannot be read. Since they live on the same disk, they also need your provider's snapshots to protect against losing the server.
