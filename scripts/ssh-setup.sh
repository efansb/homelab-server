#!/bin/bash
set -euo pipefail

# ssh-setup.sh
# Usage: sudo ./ssh-setup.sh <username> <pubkey-file>
# Example: sudo ./ssh-setup.sh admin /root/id_rsa.pub

if [ $# -ne 2 ]; then
  echo "Usage: $0 <username> <pubkey-file>"
  exit 1
fi

USERNAME="$1"
PUBKEY_FILE="$2"

if [ ! -f "$PUBKEY_FILE" ]; then
  echo "Public key file not found: $PUBKEY_FILE"
  exit 2
fi

if ! id "$USERNAME" >/dev/null 2>&1; then
  echo "Membuat user: $USERNAME"
  adduser --gecos "" "$USERNAME"
else
  echo "User $USERNAME sudah ada"
fi

usermod -aG sudo "$USERNAME"

mkdir -p /home/"$USERNAME"/.ssh
cp "$PUBKEY_FILE" /home/"$USERNAME"/.ssh/authorized_keys
chown -R "$USERNAME":"$USERNAME" /home/"$USERNAME"/.ssh
chmod 700 /home/"$USERNAME"/.ssh
chmod 600 /home/"$USERNAME"/.ssh/authorized_keys

echo "==> Backup sshd_config"
SSHD_CONFIG="/etc/ssh/sshd_config"
cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak.$(date +%s)"

# Safely set options (add or replace)
grep -q '^PermitRootLogin' "$SSHD_CONFIG" && sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' "$SSHD_CONFIG" || echo "PermitRootLogin no" >> "$SSHD_CONFIG"
grep -q '^PasswordAuthentication' "$SSHD_CONFIG" && sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG" || echo "PasswordAuthentication no" >> "$SSHD_CONFIG"
grep -q '^PubkeyAuthentication' "$SSHD_CONFIG" && sed -i 's/^PubkeyAuthentication.*/PubkeyAuthentication yes/' "$SSHD_CONFIG" || echo "PubkeyAuthentication yes" >> "$SSHD_CONFIG"

systemctl restart sshd

echo "Selesai. PENTING: Uji login SSH menggunakan key dari sesi lain sebelum menutup sesi root."
