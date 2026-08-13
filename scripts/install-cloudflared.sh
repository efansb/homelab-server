#!/bin/bash
set -euo pipefail

# install-cloudflared.sh
# Install cloudflared binary and create a sample config for a tunnel named homelab-esb
# NOTE: This script installs cloudflared and writes a config template. You MUST run
# 'cloudflared tunnel login' (interactive) to authenticate Cloudflare and then
# 'cloudflared tunnel create homelab-esb' to create the tunnel and obtain the
# credentials file. After that, run 'scripts/cloudflared-enable-tunnel.sh' to
# finish DNS routing and enable the systemd service.

set -e

if [ "$EUID" -ne 0 ]; then
  echo "Run as root"
  exit 1
fi

# Download latest cloudflared .deb and install
TMPDEB="/tmp/cloudflared.deb"
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
  URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb"
else
  URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$(uname -m).deb"
fi

echo "Downloading cloudflared from $URL"
curl -L -o "$TMPDEB" "$URL"
apt update
apt install -y "$TMPDEB" || dpkg -i "$TMPDEB" || true
rm -f "$TMPDEB"

# Create config dir
mkdir -p /etc/cloudflared
chown root:root /etc/cloudflared
chmod 700 /etc/cloudflared

# Write sample config.yml
cat > /etc/cloudflared/config.yml <<'EOF'
# cloudflared config for homelab-esb
# Replace credentials-file with the JSON file created by 'cloudflared tunnel create'
# Ingress rules map public hostnames to local addresses/ports
# Use originRequest.noTLSVerify: true when connecting to local services with self-signed certs

# credentials-file: /etc/cloudflared/<TUNNEL-UUID>.json

ingress:
  - hostname: pve.7sembilan.my.id
    service: https://127.0.0.1:8006
    originRequest:
      noTLSVerify: true

  - hostname: blog.7sembilan.my.id
    service: http://192.168.18.100:80

  - hostname: folio.7sembilan.my.id
    service: http://192.168.18.100:80

  - hostname: erp.7sembilan.my.id
    service: http://192.168.18.101:80

  - service: http_status:404

# Tunnel name expected: homelab-esb
# credentials-file should be placed here after tunnel create, e.g. /etc/cloudflared/<TUNNEL-ID>.json
EOF

echo "cloudflared installed and /etc/cloudflared/config.yml created (template)."

cat <<EOF
Next manual steps (interactive):

1) Authenticate cloudflared with your Cloudflare account (this will open a browser):
   cloudflared tunnel login

2) Create the tunnel (this will create a credentials file in ~/.cloudflared and print the tunnel id):
   cloudflared tunnel create homelab-esb

   Move the generated credentials JSON file to /etc/cloudflared/ so config.yml can reference it, for example:
   mv ~/.cloudflared/<TUNNEL-ID>.json /etc/cloudflared/
   chown root:root /etc/cloudflared/<TUNNEL-ID>.json
   chmod 600 /etc/cloudflared/<TUNNEL-ID>.json

3) Edit /etc/cloudflared/config.yml and add the line:
   credentials-file: /etc/cloudflared/<TUNNEL-ID>.json
   (Add it at top of file)

4) Route DNS for each hostname (this requires the tunnel id):
   cloudflared tunnel route dns homelab-esb pve.7sembilan.my.id
   cloudflared tunnel route dns homelab-esb blog.7sembilan.my.id
   cloudflared tunnel route dns homelab-esb folio.7sembilan.my.id
   cloudflared tunnel route dns homelab-esb erp.7sembilan.my.id

5) Enable the tunnel as a systemd service (after credentials-file present):
   cloudflared service install --token <if using service install>    # optional
   Or create systemd unit:
     /usr/bin/cloudflared tunnel run homelab-esb &

6) Verify logs:
   journalctl -u cloudflared -f

Note: If Cloudflare DNS zone/permissions are managed via API token, you can also use API tokens to create records programmatically.

EOF
