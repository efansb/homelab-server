#!/bin/bash
set -euo pipefail

# create-lxc-hosting.sh
# Create and provision LXC container for hosting (OpenLiteSpeed + PHP + MariaDB + WordPress)
# Usage: sudo ./scripts/create-lxc-hosting.sh

# Editable variables
VMID=100
HOSTNAME="hosting"
IPADDR="192.168.18.100/24"
GATEWAY="192.168.18.1"
TEMPLATE_NAME="local:vztmpl/debian-12-standard_12.1-1_amd64.tar.zst" # adjust if different
STORAGE="local-lvm" # change to your storage (local, local-lvm, etc.)
ROOTFS_SIZE="8G"
CORES=1
MEMORY=2048
ROOT_PASSWORD="Efan301008"  # requested root password
NONROOT_USER="efan"
NONROOT_PASS="301008"
LS_ADMIN_USER="admin"
LS_ADMIN_PASS="ChangeMeLSAdmin!"
DB_ROOT_PASS="ChangeMeDBRoot!"
WP_DB="wpdb"
WP_DB_USER="wpuser"
WP_DB_PASS="ChangeMeWPDB!"

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

# Ensure template exists; try to download if not
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

# Start container
pct start $VMID

# Wait for container to boot
echo "Waiting for container to boot..."
sleep 5

# Provision inside container using pct exec
echo "Updating apt and installing base packages..."
pct exec $VMID -- bash -lc "apt update && DEBIAN_FRONTEND=noninteractive apt install -y wget curl gnupg2 lsb-release ca-certificates software-properties-common" 

# Create non-root user 'efan' with requested password and add to sudo
echo "Creating non-root user $NONROOT_USER inside container..."
pct exec $VMID -- bash -lc "id -u $NONROOT_USER >/dev/null 2>&1 || (useradd -m -s /bin/bash $NONROOT_USER && echo '$NONROOT_USER:$NONROOT_PASS' | chpasswd && usermod -aG sudo $NONROOT_USER)"

# Install OpenLiteSpeed repository & packages
echo "Installing OpenLiteSpeed and PHP (lsphp)..."
pct exec $VMID -- bash -lc "wget -O - https://repo.litespeed.sh | sudo bash && apt update && apt install -y openlitespeed" 

# Install lsphp (choose latest available, fallback to lsphp74/80/81/82)
AVAILABLE_PHP=$(pct exec $VMID -- bash -lc "apt-cache search lsphp | awk '{print \$1}' | grep -E 'lsphp[0-9]+' | sort -V | tail -n1") || true
if [ -n "$AVAILABLE_PHP" ]; then
  echo "Found PHP package inside container: $AVAILABLE_PHP"
  pct exec $VMID -- bash -lc "DEBIAN_FRONTEND=noninteractive apt install -y $AVAILABLE_PHP ${AVAILABLE_PHP}-mysql ${AVAILABLE_PHP}-curl ${AVAILABLE_PHP}-gd ${AVAILABLE_PHP}-mbstring ${AVAILABLE_PHP}-xml ${AVAILABLE_PHP}-zip"
else
  echo "No specific lsphp package found, installing generic lsphp and php packages"
  pct exec $VMID -- bash -lc "DEBIAN_FRONTEND=noninteractive apt install -y lsphp lsphp-mysql"
fi

# Install MariaDB
echo "Installing MariaDB server..."
pct exec $VMID -- bash -lc "DEBIAN_FRONTEND=noninteractive apt install -y mariadb-server"

# Secure MariaDB (set root password and remove test DB)
pct exec $VMID -- bash -lc "mysql -e \"ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASS}'; FLUSH PRIVILEGES;\" || true"

# Create WP database and user
pct exec $VMID -- bash -lc "mysql -uroot -p'${DB_ROOT_PASS}' -e \"CREATE DATABASE IF NOT EXISTS ${WP_DB}; CREATE USER IF NOT EXISTS '${WP_DB_USER}'@'localhost' IDENTIFIED BY '${WP_DB_PASS}'; GRANT ALL PRIVILEGES ON ${WP_DB}.* TO '${WP_DB_USER}'@'localhost'; FLUSH PRIVILEGES;\""

# Set OpenLiteSpeed admin password
echo "Setting OpenLiteSpeed admin password..."
pct exec $VMID -- bash -lc "/usr/local/lsws/admin/misc/admpass.sh <<EOF
${LS_ADMIN_USER}
${LS_ADMIN_PASS}
${LS_ADMIN_PASS}
EOF
"

# Install WP CLI and WordPress
echo "Installing WordPress..."
pct exec $VMID -- bash -lc "apt install -y unzip && cd /var/www && wget https://wordpress.org/latest.zip && unzip latest.zip && chown -R www-data:www-data wordpress && chmod -R 755 wordpress"

# Basic OpenLiteSpeed: restart
pct exec $VMID -- bash -lc "/usr/local/lsws/bin/lswsctrl restart || true"

# Done — output credentials and next steps
cat <<EOF

LXC $VMID ($HOSTNAME) created and basic provisioning completed.
Access:
- SSH: root@${IPADDR%%/*} (password: ${ROOT_PASSWORD})
- Non-root user: ${NONROOT_USER} (password: ${NONROOT_PASS})
- OpenLiteSpeed WebAdmin: https://${IPADDR%%/*}:7080 (user: ${LS_ADMIN_USER}, password: ${LS_ADMIN_PASS})
- WordPress files: /var/www/wordpress
- MySQL root password: ${DB_ROOT_PASS}
- WordPress DB: ${WP_DB}, user: ${WP_DB_USER}, pass: ${WP_DB_PASS}

Notes:
- After verifying, change all default passwords immediately.
- Fine-tune OpenLiteSpeed virtual host, enable HTTPS (Let's Encrypt) and optimize PHP settings.
EOF
