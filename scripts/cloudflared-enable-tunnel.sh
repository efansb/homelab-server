#!/bin/bash
set -euo pipefail

# cloudflared-enable-tunnel.sh
# After you've run 'cloudflared tunnel create homelab-esb' and moved the credentials
# JSON to /etc/cloudflared/<TUNNEL-ID>.json, this script will add the credentials-file
# line to config.yml, enable the tunnel service and attempt to start it.

if [ "$EUID" -ne 0 ]; then
  echo "Run as root"
  exit 1
fi

if [ ! -d /etc/cloudflared ]; then
  echo "/etc/cloudflared not found. Run scripts/install-cloudflared.sh first."
  exit 1
fi

echo "Searching for a cloudflared credentials file in ~/.cloudflared and /etc/cloudflared..."
CRED=$(ls /etc/cloudflared/*.json 2>/dev/null | head -n1 || true)
if [ -z "$CRED" ]; then
  echo "No credentials JSON found in /etc/cloudflared. Please move the file created by 'cloudflared tunnel create' into /etc/cloudflared and run again."
  exit 1
fi

CFG="/etc/cloudflared/config.yml"
cp "$CFG" "${CFG}.bak.$(date +%s)"

# Add credentials-file line at top if not present
grep -q '^credentials-file:' "$CFG" || sed -i "1icredentials-file: $CRED\n" "$CFG"

# Create a systemd unit that runs the tunnel
SERVICE="/etc/systemd/system/cloudflared-homelab-esb.service"
cat > "$SERVICE" <<EOF
[Unit]
Description=cloudflared tunnel homelab-esb
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/cloudflared tunnel run homelab-esb --config /etc/cloudflared/config.yml
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now cloudflared-homelab-esb.service || true

cat <<EOF
Attempted to enable and start cloudflared-homelab-esb.service. Check status with:
  systemctl status cloudflared-homelab-esb.service
  journalctl -u cloudflared-homelab-esb.service -f

If DNS routing for hostnames is not created, run (requires cloudflared authenticated):
  cloudflared tunnel route dns homelab-esb pve.7sembilan.my.id
  cloudflared tunnel route dns homelab-esb blog.7sembilan.my.id
  cloudflared tunnel route dns homelab-esb folio.7sembilan.my.id
  cloudflared tunnel route dns homelab-esb erp.7sembilan.my.id

EOF
