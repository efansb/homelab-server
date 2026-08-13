#!/bin/bash
set -euo pipefail

# proxmox-postinstall.sh
# Usage: sudo ./proxmox-postinstall.sh [--no-swap] [--lan SUBNET]
# Example: sudo ./proxmox-postinstall.sh --lan 192.168.1.0/24

NO_SWAP=0
LAN_SUBNET="192.168.1.0/24"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-swap) NO_SWAP=1; shift ;;
    --lan) LAN_SUBNET="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

echo "==> Menambahkan proxmox no-subscription repo (opsional)"
if [ ! -f /usr/share/keyrings/proxmox-archive-keyring.gpg ]; then
  wget -qO - https://download.proxmox.com/debian/proxmox-release-bookworm.gpg | gpg --dearmor > /usr/share/keyrings/proxmox-archive-keyring.gpg
fi
cat >/etc/apt/sources.list.d/pve-no-subscription.list <<'EOF'
# proxmox no-subscription repo
deb [signed-by=/usr/share/keyrings/proxmox-archive-keyring.gpg] http://download.proxmox.com/debian/pve bookworm pve-no-subscription
EOF

echo "==> Update apt & upgrade sistem"
apt update
DEBIAN_FRONTEND=noninteractive apt full-upgrade -y

echo "==> Install paket dasar"
apt install -y \
  curl wget htop vim git net-tools lvm2 thin-provisioning-tools \
  smartmontools hdparm python3-pip ufw fail2ban haveged

echo "==> Setup UFW (default deny incoming)"
ufw default deny incoming
ufw default allow outgoing

# allow SSH from LAN only (ubah sesuai jaringan Anda)
ufw allow from "${LAN_SUBNET}" to any port 22 proto tcp
ufw allow 8006/tcp   # Proxmox web UI
ufw --force enable

if [ "$NO_SWAP" -eq 0 ]; then
  if swapon --show | grep -q '^'; then
    echo "Swap sudah aktif, lewati pembuatan swapfile"
  else
    echo "==> Membuat swapfile 4G"
    if command -v fallocate >/dev/null 2>&1; then
      fallocate -l 4G /swapfile
    else
      dd if=/dev/zero of=/swapfile bs=1M count=4096
    fi
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
  fi
else
  echo "Lewati pembuatan swapfile karena --no-swap"
fi

echo "==> Mengaktifkan haveged untuk entropy (berguna di VM)"
systemctl enable --now haveged || true

echo "==> Membersihkan apt cache"
apt autoremove -y
apt autoclean -y

echo "Selesai. Tinjau output untuk error. Direkomendasikan reboot setelah skrip selesai."
