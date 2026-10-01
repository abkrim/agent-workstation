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
| `root` | Emergencies only, from your provider's web console | — | No |
| `admin` | You, for administration | Yes, with a password | Yes |
| `dev` | Your repos and the coding agents | **No** | Yes |
| `hermes` | Hermes Agent *(optional)* | No | No |
| `restic` | Local backups *(optional)*. It can read everything and write only its repository | No | No |

- Nobody is in the `docker` group, which would amount to root. `dev` uses **rootless Docker**, and published ports default to 127.0.0.1.
- Agents run as `dev`, so a misbehaving agent can damage `dev`'s files, not the system.

## Agents and repos

- A `pre-push` hook in every repo blocks **deleting `main`** on the remote.
- Claude Code and OpenCode refuse `git push --no-verify` and `gh repo delete`.
- `ci-local` (tests plus GGA's review of the whole PR) is the gate before any merge, both for agents and for `wt rm`.
- `claude-trust` only marks folders under `~/work` and `~/trees`, your own repos, as trusted.

## Hermes

- Hermes runs as its own user, with no sudo, no SSH and no GitHub credentials.
- It reads **only** the repos you share with `repo-add --hermes`. They are copies in `/srv/shared/repos`, refreshed hourly by `dev`, that Hermes can read but not write. It cannot see `~dev`.
- Every command it wants to run needs your approval, and scheduled jobs cannot run commands.
- Only your Telegram user id can talk to the bot.

## Secrets

- They are asked for by `kit-login`, never put in `kit.conf` or in this repo.
- They are stored with mode 600, readable only by the user that needs them, and never passed on a command line, where other users could see them.
- `nan-gate` holds no key: each client sends its own.

## Updates and backups

- Ubuntu security updates install automatically. Reboots are up to you.
- The Gentleman tools follow their `main` branch and refresh every 3 hours. Other tools update when you re-run the installer, and Claude Code updates itself.
- Local backups (optional) are encrypted with restic. **Save the restic password somewhere else**: without it they cannot be read. Since they live on the same disk, they also need your provider's snapshots to protect against losing the server.
