# From your phone

[Moshi](https://getmoshi.app) is a terminal for iOS and Android that connects straight to this machine over SSH or Mosh, with no relay in between. Its free plan has everything this needs: the full terminal, Mosh, unlimited sessions and push notifications. It knows Herdr, so your workspaces show up as a list you tap.

## 1. Tailscale on the phone

Install Tailscale on the phone and sign in to the same tailnet as this machine. That is the only way in.

## 2. Add the machine to Moshi

Two ways:

- **With the QR.** In Herdr's `~` workspace run `kit-moshi connect` and scan the QR with Moshi. It adds the connection (this machine, user `dev`, your Tailscale address) and the phone's SSH key. The QR and its link grant SSH access to whoever scans them, so never share or screenshot them; they expire in a few minutes, and the pairing goes through Moshi's service.
- **By hand.** In Moshi, add a connection with the machine's name in your tailnet (or its Tailscale IP, `100.x.y.z`), user `dev`, and key authentication. Moshi shows the phone's public key; allow it on the machine with:

  ```bash
  kit-phone-key "ssh-ed25519 AAAA... phone"
  ```

Use the Tailscale address, never the public IP: the firewall does not answer there. Connection type **Auto** picks Mosh when it can, which keeps the session alive when the phone changes networks.

## 3. Work

Connect. Moshi lists the running Herdr sessions under a **Herdr** tab; tap one and you are in the same workspaces you use from your computer. In Moshi's settings, Shortcuts > Herdr, the prefix is `Ctrl-B`, the same as here, so `Ctrl-B C` opens a tab and `Ctrl-B W` switches workspaces.

Everything else is the same as on your computer: `wt new`, `claude` or `gentle-shell`, `wt rm`. See [getting-started.md](getting-started.md).

## 4. Optional: notifications and approvals on the phone

With `moshi-hook` on the machine, your phone gets a push when an agent finishes a turn, asks a question or needs an approval, and you can answer from the notification. In Herdr's `~` workspace:

```bash
kit-moshi
```

It installs the daemon with conservative settings, adds the hooks to Claude Code and gentle-shell, shows the QR for the connection (step 2) and then asks for a pairing token, which Moshi shows under Settings > Integrations.

Know what this adds. `moshi-hook` is a closed-source daemon from getmoshi.app. It runs as `dev`, listens only on this machine (127.0.0.1:24543) and keeps one connection open to Moshi's servers. Each event it sends carries up to 200 characters of your prompt, 80 of the agent's reply and the command behind an approval, plus the project name, the model and the context use. Transcripts and files stay here. The kit turns off its two other habits: uploading your agents' usage figures to Moshi, and probing local ports for development servers. `kit-moshi status` shows the settings; `kit-moshi remove` takes it all out again, and Moshi keeps working as a plain terminal.
