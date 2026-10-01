#!/usr/bin/env bash
# NaN (nan.builders) as the open-source model provider:
#   - nan-gate (127.0.0.1:4880): every NaN client on the machine goes through it, so together they
#     never exceed your plan's simultaneous requests (NAN_MAX_CONCURRENT) and per-minute limit.
#     Hermes has priority over development. It holds no key: each client sends its own.
#   - OpenCode with NaN (GLM 5.3 Flash by default) through the gate.
#   - Model profiles for gentle-shell (/gentle:profiles): "opensource" (DeepSeek V4 Flash
#     orchestrates) and "opensource-glm" (GLM 5.3 Flash orchestrates). Pi's NaN provider cannot be
#     pointed at the gate, so it goes direct.
#   - GGA reviews pull requests with OpenCode + NaN.
# Config files are only copied when missing: your own changes are never overwritten.
# The NaN key itself is asked for by kit-login.
set -euo pipefail
# shellcheck disable=SC1091
. "$KIT_DIR/lib/common.sh"

install -d -m 755 /usr/local/lib/nan-gate
install -m 644 "$KIT_DIR/bin/nan-gate.py" /usr/local/lib/nan-gate/nan-gate.py
cat > /etc/systemd/system/nan-gate.service <<EOF
# Managed by workstation-kit (modules/85-nan.sh)
[Unit]
Description=nan-gate: single door to NaN for this machine
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
DynamicUser=yes
Environment=NAN_GATE_LISTEN=127.0.0.1
Environment=NAN_GATE_PORT=4880
Environment=NAN_GATE_MAX_CONCURRENT=${NAN_MAX_CONCURRENT:-4}
Environment=NAN_GATE_MAX_RPM=${NAN_MAX_RPM:-40}
ExecStart=/usr/bin/python3 /usr/local/lib/nan-gate/nan-gate.py
Restart=always
RestartSec=3
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
PrivateDevices=yes
MemoryMax=256M

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable nan-gate.service >/dev/null
systemctl restart nan-gate.service
for _ in $(seq 1 20); do curl -fs http://127.0.0.1:4880/status >/dev/null && break; sleep 0.5; done
ok "nan-gate: $(curl -fs http://127.0.0.1:4880/status)"

h=$(home_of "$DEV_USER")
copy_if_missing() {  # copy_if_missing SRC DEST
  install -d -o "$DEV_USER" -g "$DEV_USER" -m 700 "$(dirname "$2")"
  [ -e "$2" ] || install -o "$DEV_USER" -g "$DEV_USER" -m 600 "$1" "$2"
}
copy_if_missing "$KIT_DIR/config/opencode.json" "$h/.config/opencode/opencode.json"
copy_if_missing "$KIT_DIR/config/gga.conf" "$h/.config/gga/config"
install -d -o "$DEV_USER" -g "$DEV_USER" -m 700 "$h/.pi"
copy_if_missing "$KIT_DIR/config/gentle-profiles.json" "$h/.pi/gentle-ai/profiles.json"
ok "OpenCode, GGA and gentle-shell profiles use NaN (the key comes in kit-login)"
