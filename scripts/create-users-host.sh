#!/bin/bash
set -euo pipefail

# create-users-host.sh
# Create non-root user 'efan' on the PVE host and set root password as requested.
# Usage: sudo ./scripts/create-users-host.sh

USERNAME="efan"
USERPASS="301008"
ROOTPASS="Efan301008"

if [ "$EUID" -ne 0 ]; then
  echo "Run as root"
  exit 1
fi

# Create user if not exists
if id "$USERNAME" >/dev/null 2>&1; then
  echo "User $USERNAME already exists on host"
else
  echo "Creating user $USERNAME"
  adduser --gecos "" "$USERNAME"
  echo "$USERNAME:$USERPASS" | chpasswd
  usermod -aG sudo "$USERNAME"
fi

# Set root password
echo "Setting root password"
echo "root:$ROOTPASS" | chpasswd

# Ensure SSH allows password auth temporarily if needed (do NOT keep in production)
SSHD_CONFIG="/etc/ssh/sshd_config"
cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak.$(date +%s)"
grep -q '^PasswordAuthentication' "$SSHD_CONFIG" && sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' "$SSHD_CONFIG" || echo "PasswordAuthentication yes" >> "$SSHD_CONFIG"
systemctl restart sshd

echo "User $USERNAME created with password. Root password set. Consider adding SSH public key and then disabling password authentication."
