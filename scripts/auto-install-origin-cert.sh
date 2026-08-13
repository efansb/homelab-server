#!/bin/bash
set -euo pipefail

# auto-install-origin-cert.sh
# Install Cloudflare Origin Certificate into OpenLiteSpeed vhost for a given domain.
# Usage: sudo ./scripts/auto-install-origin-cert.sh <LXC_ID> <domain> <cert-file> <key-file>
# Example: sudo ./scripts/auto-install-origin-cert.sh 100 blog.7sembilan.my.id /root/cf-origin.crt /root/cf-origin.key

if [ "$EUID" -ne 0 ]; then
  echo "Run as root"
  exit 1
fi

if [ $# -ne 4 ]; then
  echo "Usage: $0 <LXC_ID> <domain> <cert-file> <key-file>"
  exit 1
fi

LXC_ID="$1"
DOMAIN="$2"
CERT_SRC="$3"
KEY_SRC="$4"

# Verify files
if [ ! -f "$CERT_SRC" ]; then
  echo "Cert file not found: $CERT_SRC"
  exit 2
fi
if [ ! -f "$KEY_SRC" ]; then
  echo "Key file not found: $KEY_SRC"
  exit 3
fi

# Destination paths inside container
CERT_DST="/etc/ssl/certs/${DOMAIN}.crt"
KEY_DST="/etc/ssl/private/${DOMAIN}.key"

# Copy cert and key into LXC
echo "Copying cert and key into LXC $LXC_ID..."
pct push $LXC_ID "$CERT_SRC" "$CERT_DST"
pct push $LXC_ID "$KEY_SRC" "$KEY_DST"

# Set permissions inside LXC
pct exec $LXC_ID -- bash -lc "chmod 644 $CERT_DST && chmod 600 $KEY_DST && chown root:root $CERT_DST $KEY_DST"

# Configure OpenLiteSpeed vhost to use cert/key
# We'll attempt to configure default vhost configuration file if exists. User may need to fine-tune via WebAdmin.

echo "Configuring OpenLiteSpeed vhost for $DOMAIN (basic steps)..."

# Create simple script inside LXC to update vhost settings via CLI (using sed to add cert paths)
SET_SCRIPT="/tmp/ols_set_ssl_${DOMAIN}.sh"
cat > /tmp/tmp_ols_script.sh <<'EOF'
#!/bin/bash
DOMAIN="$DOMAIN"
CERT="$CERT_DST"
KEY="$KEY_DST"
# Attempt to patch default vhost.xml (may vary by OpenLiteSpeed versions). This script is best-effort; adjust via WebAdmin if needed.
VHOST_CONF_DIR="/usr/local/lsws/conf/vhosts/"
if [ -d "$VHOST_CONF_DIR" ]; then
  for V in "$VHOST_CONF_DIR"*; do
    if [ -f "$V"/vhconf.xml ]; then
      echo "Patching $V/vhconf.xml"
      # Insert SSL settings under <ssl> node if not present
      if ! grep -q "sslCertFile" "$V/vhconf.xml"; then
        sed -i "/<vhTemplate>/a \\n    <ssl>\\n      <certName>$(basename $CERT)</certName>\\n      <key>$(basename $KEY)</key>\\n    </ssl>" "$V/vhconf.xml" || true
      fi
    fi
  done
fi
# Note: User should verify via OpenLiteSpeed WebAdmin and set certificate/key paths in Virtual Host > SSL.
EOF

# Push the script into container and run
pct push $LXC_ID /tmp/tmp_ols_script.sh /tmp/ols_set_ssl_${DOMAIN}.sh
pct exec $LXC_ID -- bash -lc "chmod +x /tmp/ols_set_ssl_${DOMAIN}.sh && /tmp/ols_set_ssl_${DOMAIN}.sh || true"

# Restart OpenLiteSpeed inside container
pct exec $LXC_ID -- bash -lc "/usr/local/lsws/bin/lswsctrl restart || true"

cat <<EOF
Done: copied origin cert and key into LXC $LXC_ID and attempted basic vhost update.
Please login to OpenLiteSpeed WebAdmin (https://<container-ip>:7080) and verify Virtual Host -> SSL settings:
 - Certificate File: $CERT_DST
 - Key File: $KEY_DST
Also enable HTTPS listener (port 443) and bind to your vhost if not already.
EOF
