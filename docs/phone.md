# From your phone

[Moshi](https://getmoshi.app) is a terminal for iOS and Android that connects straight to this machine over SSH or Mosh, with no relay in between. Its free plan has everything this needs: the full terminal, Mosh, unlimited sessions and push notifications. It knows Herdr, so your workspaces show up as a list you tap.

Two separate things, and you can stop after the first:

1. **The connection:** Moshi reaching the machine. Nothing to install on the server.
2. **The notifications:** a push when an agent finishes, asks something or wants an approval. This one installs `moshi-hook` on the machine (`kit-moshi`).

## 1. Tailscale on the phone

Install Tailscale on the phone and sign in to the same tailnet as this machine. That is the only way in.

## 2. Connect Moshi to the machine

Pick one:

- **QR from your computer.** In Herdr's `~` workspace, on your laptop, run `kit-moshi connect` and scan the QR with Moshi. It adds the connection (this machine, user `dev`, your Tailscale address) and the phone's SSH key. The QR and its link grant SSH access to whoever scans them, so never share or screenshot them; they expire in a few minutes, and the pairing goes through Moshi's service.
- **By hand.** In Moshi, add a connection: host is the machine's name in your tailnet (or its Tailscale IP, `100.x.y.z`), user `dev`, key authentication. Moshi shows the phone's public key; allow it on the machine from any `dev` shell:

  ```bash
  kit-phone-key "ssh-ed25519 AAAA... phone"
  ```

Use the Tailscale address, never the public IP: the firewall does not answer there. Connection type **Auto** picks Mosh when it can, which keeps the session alive when the phone changes networks.

## 3. Work from the phone

Connect. If Moshi drops you in a plain shell (`dev@...:~$`), type `herdr`: it attaches to the running session, sidebar and all. Moshi also lists the running Herdr sessions under a **Herdr** tab; tap one and you are in the same workspaces as on your computer.

The prefix is the same `Ctrl-B` (Moshi's settings, Shortcuts > Herdr, has it ready): `Ctrl-B W` to switch workspace, `Ctrl-B C` for a new tab. Moshi's toolbar has the keys a phone keyboard lacks, Ctrl and Esc among them.

Everything else is the same as on your computer: `wt new`, then switch to the task's workspace, then `claude` or `gentle-shell`, then `wt rm`. See [getting-started.md](getting-started.md).

## 4. Optional: notifications and approvals on the phone

With `moshi-hook` on the machine, your phone gets a push when an agent finishes a turn, asks a question or needs an approval, and you can answer from the notification. In Herdr's `~` workspace:

```bash
kit-moshi
```

It installs the daemon with conservative settings, adds the hooks to Claude Code and gentle-shell, and then goes through the two steps:

- **1 of 2, the connection:** a QR, the same as `kit-moshi connect`. If you already connected in step 2, or you are running this from the phone itself (you cannot scan a QR shown on the same screen), press **Ctrl+C** and it moves on.
- **2 of 2, the notifications:** it asks for a pairing token. In Moshi, Settings > Integrations shows it; paste it. Done.

Each step can be run on its own later: `kit-moshi connect`, `kit-moshi pair`.

Know what this adds. `moshi-hook` is a closed-source daemon from getmoshi.app. It runs as `dev`, listens only on this machine (127.0.0.1:24543) and keeps one connection open to Moshi's servers. Each event it sends carries up to 200 characters of your prompt, 80 of the agent's reply and the command behind an approval, plus the project name, the model and the context use. Transcripts and files stay here. The kit turns off its two other habits: uploading your agents' usage figures to Moshi, and probing local ports for development servers. `kit-moshi status` shows the settings; `kit-moshi remove` takes it all out again, and Moshi keeps working as a plain terminal.
