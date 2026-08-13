#!/bin/bash
set -euo pipefail

# all-in-one-deploy.sh
# All-in-one orchestration script for homelab deployment on Proxmox host.
# PURPOSE: run the sequence of steps to set up host user, create LXC containers (100,101,103),
# install cloudflared (template config), and guide through interactive Cloudflare login/tunnel creation.
#
# IMPORTANT: This script is opinionated and performs privileged operations. Review every line
# in scripts/ before executing. This script will call other scripts in the repository.
#
# Usage: sudo ./scripts/all-in-one-deploy.sh
# Review and edit the variables below before running.

REPO_DIR="/root/homelab-server"
SCRIPTS_DIR="$REPO_DIR/scripts"

# Default values - change if your environment differs
PVE_IP="192.168.18.86"
STORAGE="local-lvm"
GATEWAY="192.168.18.1"
LXC_HOSTING_ID=100
LXC_HOSTING_IP="192.168.18.100/24"
LXC_SERVER_ID=101
LXC_SERVER_IP="192.168.18.101/24"
LXC_HERMES_ID=103
LXC_HERMES_IP="192.168.18.103/24"

# Host/user credentials (as requested)
HOST_NONROOT_USER="efan"
HOST_NONROOT_PASS="301008"
HOST_ROOT_PASS="Efan301008"

# WordPress admin (example - change before running wp-auto-install)
WP_ADMIN_USER="wpadmin"
WP_ADMIN_PASS="ChangeMeAdminPass!"
WP_ADMIN_EMAIL="you@example.com"
WP_SITE_TITLE="Blog 7Sembilan"
WP_SITE_DOMAIN="blog.7sembilan.my.id"

# Cloudflare tunnel details
TUNNEL_NAME="homelab-esb"
CF_HOSTNAMES=("pve.7sembilan.my.id" "blog.7sembilan.my.id" "folio.7sembilan.my.id" "erp.7sembilan.my.id")
# Optionally add hermes hostname
# CF_HOSTNAMES+=("hermes.7sembilan.my.id")

# Paths to cert/key for Cloudflare Origin Cert (optional step A)
CF_ORIGIN_CERT="/root/cf-origin.crt"
CF_ORIGIN_KEY="/root/cf-origin.key"

# Helper: ensure script location
if [ ! -d "$SCRIPTS_DIR" ]; then
  echo "Repository scripts not found in $REPO_DIR"
  echo "Please clone the repo into $REPO_DIR or edit REPO_DIR at top of this script."
  exit 1
fi

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

echo "ALL-IN-ONE DEPLOY SCRIPT"
echo "Review: $SCRIPTS_DIR/* before continuing."
read -rp "Have you reviewed scripts and want to proceed? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "Aborted by user. Please review scripts and rerun when ready."; exit 0
fi

# Make sure scripts executable
chmod +x "$SCRIPTS_DIR"/*.sh || true

# Step 1: create host user and set root password
echo "\n=== Step 1: Create host user and set root password ==="
echo "Running create-users-host.sh (this will set host root password and create user $HOST_NONROOT_USER)"
cp "$SCRIPTS_DIR/create-users-host.sh" /tmp/create-users-host.sh
# run copied script to avoid relative path issues
bash /tmp/create-users-host.sh

# Step 2: ensure Debian 12 LXC template available
echo "\n=== Step 2: Ensure Debian 12 template available (pveam) ==="
# pveam requires Proxmox environment; run with the host's pveam
pveam update || true
if ! pveam available | grep -iq "debian-12"; then
  echo "Warning: debian-12 template not found in remote list. Please download a Debian 12 LXC template via Proxmox UI or pveam and rerun.";
else
  echo "Debian 12 template is available. You may download it if not present locally."
fi

read -rp "Download Debian 12 template now if missing? (yes/no) " DL_TEMPL
if [[ "$DL_TEMPL" == "yes" ]]; then
  TEMPLATE_SHORT=$(pveam available | awk '/debian-12-standard/ {print $1; exit}') || true
  if [ -n "$TEMPLATE_SHORT" ]; then
    echo "Downloading $TEMPLATE_SHORT..."
    pveam download local "$TEMPLATE_SHORT"
  else
    echo "No debian-12 template found in pveam list. Please use Proxmox GUI to download one and rerun.";
  fi
fi

# Step 3: create LXC containers
echo "\n=== Step 3: Create LXC hosting (ID $LXC_HOSTING_ID) ==="
read -rp "Proceed to create LXC $LXC_HOSTING_ID (hosting)? (yes/no) " RESP
if [[ "$RESP" == "yes" ]]; then
  bash "$SCRIPTS_DIR/create-lxc-hosting.sh"
else
  echo "Skipping LXC $LXC_HOSTING_ID"
fi

echo "\n=== Step 4: Create LXC server-stack (ID $LXC_SERVER_ID) ==="
read -rp "Proceed to create LXC $LXC_SERVER_ID (server-stack)? (yes/no) " RESP
if [[ "$RESP" == "yes" ]]; then
  bash "$SCRIPTS_DIR/create-lxc-server-stack.sh"
else
  echo "Skipping LXC $LXC_SERVER_ID"
fi

echo "\n=== Step 5: Create LXC hermes-ai (ID $LXC_HERMES_ID) ==="
read -rp "Proceed to create LXC $LXC_HERMES_ID (hermes-ai)? (yes/no) " RESP
if [[ "$RESP" == "yes" ]]; then
  bash "$SCRIPTS_DIR/create-lxc-hermes-ai.sh"
else
  echo "Skipping LXC $LXC_HERMES_ID"
fi

# Step 4: Install cloudflared template and guide user through interactive login
echo "\n=== Step 6: Install cloudflared and configure tunnel (interactive) ==="
read -rp "Install cloudflared on host now? (yes/no) " RESP
if [[ "$RESP" == "yes" ]]; then
  bash "$SCRIPTS_DIR/install-cloudflared.sh"
  echo "Now you must authenticate cloudflared in your browser. Follow the prompts below."
  echo "Command: sudo cloudflared tunnel login"
  echo "After logging in, create the tunnel: sudo cloudflared tunnel create $TUNNEL_NAME"
  echo "When the tunnel is created, move the credentials JSON to /etc/cloudflared/ and run the helper to enable the tunnel."
  read -rp "Ready to run 'cloudflared tunnel login' now? (yes/no) " RESP2
  if [[ "$RESP2" == "yes" ]]; then
    echo "Running interactive login. A browser will open on the machine where you run this command.";
    sudo -H -u root cloudflared tunnel login || true
    echo "After login, create the tunnel: sudo cloudflared tunnel create $TUNNEL_NAME"
    read -rp "Have you created the tunnel and moved the credentials JSON to /etc/cloudflared? (yes/no) " DONE_TUN
    if [[ "$DONE_TUN" == "yes" ]]; then
      bash "$SCRIPTS_DIR/cloudflared-enable-tunnel.sh"
      echo "Now route DNS names to the tunnel (one by one):"
      for H in "${CF_HOSTNAMES[@]}"; do
        echo "sudo cloudflared tunnel route dns $TUNNEL_NAME $H";
      done
      echo "Run those cloudflared commands to create DNS records in Cloudflare (interactive/API token required)."
    else
      echo "Please complete tunnel creation and credentials move, then run: $SCRIPTS_DIR/cloudflared-enable-tunnel.sh";
    fi
  else
    echo "Skipping interactive cloudflared login. You must perform: cloudflared tunnel login && cloudflared tunnel create $TUNNEL_NAME";
  fi
else
  echo "Skipping cloudflared installation.";
fi

# Optional: install origin cert into LXC 100
echo "\n=== Optional Step: install Cloudflare Origin Cert into LXC 100 ==="
if [ -f "$CF_ORIGIN_CERT" ] && [ -f "$CF_ORIGIN_KEY" ]; then
  read -rp "Found $CF_ORIGIN_CERT and $CF_ORIGIN_KEY. Install into LXC 100 now? (yes/no) " RESP
  if [[ "$RESP" == "yes" ]]; then
    bash "$SCRIPTS_DIR/auto-install-origin-cert.sh" "$LXC_HOSTING_ID" "$WP_SITE_DOMAIN" "$CF_ORIGIN_CERT" "$CF_ORIGIN_KEY"
  else
    echo "Skipping origin cert installation.";
  fi
else
  echo "Origin cert/key not found at $CF_ORIGIN_CERT and $CF_ORIGIN_KEY. Skip this step or copy cert/key to these paths and rerun."
fi

# Optional: auto-install WordPress
echo "\n=== Optional Step: Auto-install WordPress (wp-cli) ==="
read -rp "Run wp-auto-install for LXC $LXC_HOSTING_ID now? (yes/no) " RESP
if [[ "$RESP" == "yes" ]]; then
  read -rp "Enter WP admin username (default $WP_ADMIN_USER): " IN_USER
  read -rp "Enter WP admin password (default hidden): " -s IN_PASS; echo
  read -rp "Enter WP admin email (default $WP_ADMIN_EMAIL): " IN_EMAIL
  IN_USER=${IN_USER:-$WP_ADMIN_USER}
  IN_PASS=${IN_PASS:-$WP_ADMIN_PASS}
  IN_EMAIL=${IN_EMAIL:-$WP_ADMIN_EMAIL}
  bash "$SCRIPTS_DIR/wp-auto-install.sh" "$LXC_HOSTING_ID" "$WP_SITE_DOMAIN" "$WP_SITE_TITLE" "$IN_USER" "$IN_PASS" "$IN_EMAIL"
else
  echo "Skipping WordPress auto-install.";
fi

# Optional: provide helper to deploy node service
echo "\n=== Optional Step: Deploy Node app via pm2 on LXC 101 ==="
read -rp "Do you want to deploy a Node app now with deploy-node-service.sh? (yes/no) " RESP
if [[ "$RESP" == "yes" ]]; then
  read -rp "Path to app directory inside LXC 101 (e.g. /home/efan/myapp): " APP_DIR
  read -rp "Start command (e.g. npm start): " START_CMD
  read -rp "Run user (default efan): " RUN_USER
  RUN_USER=${RUN_USER:-efan}
  bash "$SCRIPTS_DIR/deploy-node-service.sh" "$LXC_SERVER_ID" "$APP_DIR" "$START_CMD" "$RUN_USER"
else
  echo "Skipping node deploy.";
fi

# Final notes
cat <<EOF

ALL-IN-ONE SCRIPT finished (interactive). Summary of next manual actions you may need to do:
- If cloudflared tunnel isn't fully created, run: cloudflared tunnel login && cloudflared tunnel create $TUNNEL_NAME, move credentials to /etc/cloudflared, then run cloudflared-enable-tunnel.sh
- Create DNS routes: cloudflared tunnel route dns $TUNNEL_NAME <hostname>
- Verify OpenLiteSpeed vhost SSL settings and enable HTTPS listener.
- Replace all default passwords and add SSH public keys.
- Upload ggml model to LXC 103 /opt/localai/models and restart localai.
- Configure backups and firewall rules as needed.

Repository path: $REPO_DIR
Run 'less README.lxc.md' for quick reference.

EOF
