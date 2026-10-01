# Security model

A basic layer that is reasonable for a personal workstation exposed to the internet. Review it against your own needs.

## Getting in

- **Tailscale only.** UFW denies everything incoming except the `tailscale0` interface. The public IP answers nothing, not even SSH.
- **SSH:** keys only (no passwords), no root login, and only `admin` and `dev` may log in (`/etc/ssh/sshd_config.d/00-agent-workstation.conf`).
- **fail2ban** watches SSH. It never bans your tailnet (100.64.0.0/10).
- **Lockout protection:** the installer stops before SSH hardening and before the firewall until you confirm that you can log in over Tailscale.
- **Tailscale key expiry.** Node keys expire after 180 days by default, and an expired key takes the machine off your tailnet: with the firewall on, that is a lockout. Disable key expiry for this machine in the [admin console](https://login.tailscale.com/admin/machines) (machine menu, "Disable key expiry"). The installer prints the date.
- **Your tailnet is the perimeter.** Anyone with a device in your tailnet can reach port 22 (they still need an SSH key). If you share the tailnet with other people, restrict who reaches this machine with a Tailscale ACL, and keep two-factor on your Tailscale login.
- **Provider firewall.** If your VPS provider offers a network firewall, turn it on with no inbound rules: a second layer that holds even if UFW is misconfigured. Tailscale keeps working through outbound connections.

## If you lock yourself out

SSH only answers over Tailscale, so losing Tailscale (expired key, deleted machine) means no SSH. The way back in is your provider's web console: log in as `root` there (console logins are not SSH, so `PermitRootLogin no` does not apply; reset the root password from the provider's panel if you never set one), then `tailscale up` again, or fix whatever broke. Nothing in the kit disables the console.

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

- **Claude Code runs in auto mode.** A second model, a safety classifier, reviews each action instead of asking you. Anthropic reserves `bypassPermissions` (no checks at all) for isolated containers or VMs without internet access ([permission modes](https://code.claude.com/docs/en/permission-modes)), and this machine is online with your GitHub and NaN credentials. Gentle AI's `permissions` component sets `bypassPermissions`; `kit-guardrails` moves it back to auto after every install and every `gentle-ai sync`. To keep bypass anyway, create `~/.config/agent-workstation/allow-bypass` as `dev`.
- Deny rules apply in every mode, auto included: Gentle AI denies reading or editing secrets (`.env`, `.ssh`, keys, credentials, `gh`'s token) and destructive commands like `rm -rf ~`; the kit adds `git push --no-verify` and `gh repo delete`.
- A `pre-push` hook in every repo blocks **deleting `main`** on the remote.
- `ci-local` (tests plus GGA's review of the whole PR) is the gate before any merge, both for agents and for `wt rm`.
- `claude-trust` only marks folders under `~/work` and `~/trees`, your own repos, as trusted.
- engram's HTTP API for `dev` listens on 127.0.0.1:7437 and answers reads with no authentication, because gentle-shell's memory package only speaks HTTP. The Hermes loopback guard (below) is what keeps the other agent user away from it; `admin` is you. Hermes's own engram uses a unix socket in its private runtime directory, off that port.
- nan-gate runs in a strict systemd sandbox (dynamic user, read-only system, no capabilities, filtered system calls, loopback and HTTPS only; `systemd-analyze security` rates it 1.1). It holds the machine's NaN key only to add it to GGA's reviews, on its own local port (127.0.0.1:4881). systemd hands it the key as a credential that only the gate can read. Any local user could send requests to that port, so it spends your NaN quota, never more: the users on this machine already hold the key or cannot log in.

## Hermes

- Hermes runs as its own user, with no sudo, no SSH and no GitHub credentials.
- It reads **only** the repos you share with `repo-add --hermes`. They are copies in `/srv/shared/repos`, refreshed hourly by `dev`, that Hermes can read but not write. It cannot see `~dev`.
- Every command it wants to run needs your approval, and scheduled jobs cannot run commands.
- On this machine it can connect only to nan-gate (its model). A firewall rule for the `hermes` user rejects every other local port, so `dev`'s local services (engram, development servers, Docker ports) are out of its reach even if a prompt injection asks for them.
- It has its own copy of engram and gentle-ai, built in its own home: nothing from `dev` runs as Hermes.
- Only your Telegram user id can talk to the bot.

## Your phone (optional)

- Moshi, the phone terminal, connects over SSH or Mosh through Tailscale, like your computer: nothing new opens on the machine. Mosh listens on UDP ports 60000 to 61000 only on the Tailscale interface, because that is all the firewall lets in.
- `moshi-hook`, installed only if you run `kit-moshi`, is a closed-source daemon from getmoshi.app running as `dev`. It listens on 127.0.0.1:24543 (out of Hermes's reach) and keeps one WebSocket to Moshi's servers, through which your phone receives agent events and sends approvals. An event carries at most 200 characters of your prompt, 80 of the reply and 256 of the command to approve, with project name, model and context use. The kit disables its usage uploads and localhost port scanning. Its pairing secret lives in `~dev/.config/moshi`, mode 600. `kit-moshi remove` takes it out.
- The "Easy Pair" QR (`kit-moshi connect`) is a short-lived credential: whoever scans it gets the phone's SSH key added to `dev`'s `authorized_keys`, through Moshi's service. Treat it like a password while it is on screen. The by-hand alternative, `kit-phone-key`, never involves Moshi's servers.

## Secrets

- They are asked for by `kit-login`, never put in `kit.conf` or in this repo.
- They are stored with mode 600, readable only by the user that needs them, and never passed on a command line, where other users could see them.
- Your email stays out of public repos: `kit-login github` sets git to commit as your GitHub noreply address, and `repo-add --new` makes a repo's first commit from this machine for the same reason. Commits that GitHub itself makes (a README created on the site, a merge done from the web or with `gh pr merge`) carry your account's real email unless you turn on "Keep my email addresses private" in GitHub's email settings. Do that once; it covers all your repos.

## What you trust

The kit installs software from other projects. Know where it comes from:

- **Ubuntu, Docker, Tailscale, GitHub CLI, mise:** their signed apt repositories.
- **Claude Code and Hermes:** their official install scripts, fetched over HTTPS and run as `dev` and `hermes`, never as root.
- **gentle-shell, engram, gentle-ai, GGA:** built from the `main` branch of their GitHub repositories, as `dev` (and `hermes` for its own copy), every 3 hours. You get fixes fast, and you also get whatever lands on `main`. If you would rather choose the moment, turn the automatic updates off (`sudo kit-updates off`) and run them when you want (`sudo kit-updates now`), or pin a version by editing `bin/gentle-update`.
- **Pi packages, CodeGraph, context7:** from npm, as `dev`.
- **Models:** your prompts and code go to NaN, which states it keeps no logs of them, trains nothing on them and processes in the European Union ([privacy policy](https://nan.builders/privacy)), and to Anthropic when you use Claude Code. Read both providers' terms.

Nothing runs as root except the kit's own modules and the system services it configures.

## Updates and backups

- Ubuntu security updates install automatically. Reboots are up to you: the installer tells you when one is pending, and later `cat /var/run/reboot-required` does.
- The Gentleman tools follow their `main` branch and, unless you turned automatic updates off, refresh every 3 hours along with Claude Code, Herdr and Moshi's hook. The rest updates when you re-run the installer. Claude Code also updates itself on its own.
- Local backups (optional) are encrypted with restic. **Save the restic password somewhere else**: without it they cannot be read. Since they live on the same disk, they also need your provider's snapshots to protect against losing the server.
