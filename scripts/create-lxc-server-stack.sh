#!/bin/bash
set -euo pipefail

# create-lxc-server-stack.sh
# Create and provision LXC container for server-stack (Node.js, Python, build tools)
# Usage: sudo ./scripts/create-lxc-server-stack.sh

# Editable variables
VMID=101
HOSTNAME="server-stack"
IPADDR="192.168.18.101/24"
GATEWAY="192.168.18.1"
TEMPLATE_NAME="local:vztmpl/debian-12-standard_12.1-1_amd64.tar.zst" # adjust if different
STORAGE="local-lvm"
ROOTFS_SIZE="6G"
CORES=1
MEMORY=1024
ROOT_PASSWORD="Efan301008"
NONROOT_USER="efan"
NONROOT_PASS="301008"

# Ensure running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Check if VM exists
if pct status $VMID >/dev/null 2>&1; then
  echo "LXC $VMID already exists. Aborting to avoid overwrite."
  exit 1
fi

# Ensure template exists
TEMPLATE_FILE=$(echo "$TEMPLATE_NAME" | awk -F: '{print $2}')
if [ ! -f "/var/lib/vz/template/cache/$TEMPLATE_FILE" ]; then
  echo "Template not found locally. Attempting to download Debian 12 template via pveam..."
  pveam update
  TEMPLATE_SHORT=$(pveam available | awk '/debian-12-standard/ {print $1; exit}') || true
  if [ -n "$TEMPLATE_SHORT" ]; then
    echo "Downloading template $TEMPLATE_SHORT..."
    pveam download local $TEMPLATE_SHORT
    TEMPLATE_NAME="local:vztmpl/$TEMPLATE_SHORT"
  else
    echo "Could not find debian-12 template via pveam. Please download a Debian 12 LXC template first." >&2
    exit 1
  fi
fi

# Create container
echo "Creating LXC $VMID ($HOSTNAME)..."
pct create $VMID $TEMPLATE_NAME \
  --hostname $HOSTNAME \
  --cores $CORES \
  --memory $MEMORY \
  --net0 name=eth0,bridge=vmbr0,ip=$IPADDR,gw=$GATEWAY \
  --rootfs ${STORAGE}:${ROOTFS_SIZE} \
  --features nesting=1 \
  --password "$ROOT_PASSWORD"

pct start $VMID
sleep 5

# Provision packages inside container
echo "Updating apt and installing base build packages..."
pct exec $VMID -- bash -lc "apt update && DEBIAN_FRONTEND=noninteractive apt install -y build-essential curl wget git ca-certificates software-properties-common" 

# Create non-root user 'efan' with requested password and add to sudo
echo "Creating non-root user $NONROOT_USER inside container..."
pct exec $VMID -- bash -lc "id -u $NONROOT_USER >/dev/null 2>&1 || (useradd -m -s /bin/bash $NONROOT_USER && echo '$NONROOT_USER:$NONROOT_PASS' | chpasswd && usermod -aG sudo $NONROOT_USER)"

# Install Node.js (LTS) via NodeSource
echo "Installing Node.js LTS (18.x)..."
pct exec $VMID -- bash -lc "curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && apt install -y nodejs"

# Install PM2 to manage node processes
pct exec $VMID -- bash -lc "npm install -g pm2 --unsafe-perm"

# Install Python3 and pip, venv
echo "Installing Python3, pip and virtualenv..."
pct exec $VMID -- bash -lc "apt install -y python3 python3-venv python3-pip"

# Optional: install common tools
pct exec $VMID -- bash -lc "apt install -y htop vim net-tools"

cat <<EOF

LXC $VMID ($HOSTNAME) created and provisioned for server stack.
Access:
- SSH: root@${IPADDR%%/*} (password: ${ROOT_PASSWORD})
- Non-root user: ${NONROOT_USER} (password: ${NONROOT_PASS})

Installed:
- nodejs (18.x) and npm
- pm2 (global)
- python3, pip, venv
- build-essential, git, curl

Next steps:
- Create non-root user inside container and deploy your Node/Python apps.
- Use pm2 to run Node apps and configure startup: pm2 startup && pm2 save
EOF
