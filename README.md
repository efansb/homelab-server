# 🖥️ Homelab Server - HP Pavilion i3 Gen4

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> Repositori ini berisi panduan dan skrip untuk menyiapkan homelab: instalasi Proxmox VE 8.3 pada laptop/PC tua, post-install, paket dasar host (PVE), konfigurasi SSH, contoh konfigurasi layar LED/I2C, dan skrip otomatisasi.

## 📋 Spesifikasi Hardware (contoh)

- Laptop: HP Pavilion (i3 Gen4, 2 core)
- RAM: 4 GB (rekomendasi upgrade ke 8 GB jika memungkinkan)
- Storage: HDD/SSD

## Tujuan

Membuat host Proxmox VE 8.3 yang siap untuk menjalankan beberapa LXC/VM ringan untuk layanan home (Pi-hole, Home Assistant, Nextcloud, Jellyfin, dsb.). Dokumen ini berisi langkah instalasi Proxmox, post-install, skrip otomatis, dan contoh konfigurasi.

---

## Proxmox VE 8.3 — Instalasi & Post-install (ringkasan)

Catatan: Langkah instalasi awal dilakukan dari ISO Proxmox VE 8.3 (unduh dari https://www.proxmox.com/en/downloads/category/iso-images-pve) dan di-boot dari USB.

1) Persiapan USB boot
- Unduh ISO Proxmox VE 8.3
- Buat USB bootable (Linux contoh):

  sudo dd if=proxmox-ve_8.3-*.iso of=/dev/sdX bs=4M status=progress && sync

  Ganti /dev/sdX dengan device USB Anda. Hati-hati memilih device.

2) Install lewat installer GUI Proxmox
- Boot dari USB dan ikuti wizard instalasi: pilih disk, set password root, email admin, atur network (rekomendasi IP statis) dan selesai.

3) First boot & akses Web UI
- Buka web UI: https://IP_HOST:8006
- Login sebagai root (atau user yang Anda buat saat instalasi).

4) Tambah repository no-subscription (opsional)
Jika Anda tidak memiliki subscription, untuk menerima update via apt gunakan repo pve-no-subscription:

As root di shell PVE:

wget -qO - https://download.proxmox.com/debian/proxmox-release-bookworm.gpg | gpg --dearmor > /usr/share/keyrings/proxmox-archive-keyring.gpg

cat <<'EOF' > /etc/apt/sources.list.d/pve-no-subscription.list
# proxmox no-subscription repo
deb [signed-by=/usr/share/keyrings/proxmox-archive-keyring.gpg] http://download.proxmox.com/debian/pve bookworm pve-no-subscription
EOF

apt update && apt full-upgrade -y

5) Paket & tools dasar (host PVE)

Jalankan (sebagai root):

apt install -y curl wget htop vim git net-tools lvm2 thin-provisioning-tools smartmontools hdparm i2c-tools python3-pip ufw fail2ban haveged

Penjelasan singkat: curl/wget (download), htop (monitor), lvm2 (storage), smartmontools/hdparm (cek disk), i2c-tools/python3-pip (untuk LED/I2C), ufw/fail2ban (keamanan), haveged (entropy untuk VM).

6) Swap (opsional, jika hanya 4 GB RAM)

# buat swapfile 4G
fallocate -l 4G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
# persist
echo '/swapfile none swap sw 0 0' >> /etc/fstab

7) Konfigurasi SSH — ringkasan

- Buat user non-root (contoh: admin) dan beri sudo
- Setup public key authentication
- Nonaktifkan PermitRootLogin dan PasswordAuthentication bila sudah yakin
- Batasi akses SSH lewat UFW jika perlu

Contoh singkat:

adduser admin
usermod -aG sudo admin
mkdir -p /home/admin/.ssh
# taruh public key di /home/admin/.ssh/authorized_keys
chown -R admin:admin /home/admin/.ssh
chmod 700 /home/admin/.ssh
chmod 600 /home/admin/.ssh/authorized_keys

Edit /etc/ssh/sshd_config:
- PermitRootLogin no
- PasswordAuthentication no
- PubkeyAuthentication yes

systemctl restart sshd

8) Firewall dasar (UFW)

Contoh aturan (sesuaikan subnet/port):

ufw allow from 192.168.1.0/24 to any port 22 proto tcp
ufw allow 8006/tcp    # Proxmox web UI
ufw enable

9) LED / small display (I2C) — contoh

- Pastikan kernel module i2c_dev dimuat dan perangkat I2C terhubung
- Install i2c-tools & library Python:

apt install -y i2c-tools
pip3 install RPLCD smbus2

i2cdetect -y 1

Contoh script ada di `examples/i2c_lcd_example.py`.

10) Backup & monitoring

- Instal Netdata (opsional) untuk monitoring ringan:
  bash <(curl -Ss https://my-netdata.io/kickstart.sh)
- Atur backup VM/LXC melalui GUI Proxmox (Storage -> Scheduled Backup)

11) Skrip otomatis

Skrip disediakan di `scripts/`:
- scripts/proxmox-postinstall.sh — tugas post-install otomatis (tambahkan repo, update, install paket dasar, swap)
- scripts/ssh-setup.sh — setup user SSH dan konfigurasi dasar (harus disunting agar sesuai public key Anda)

---

## Struktur repo (baru)

- README.md (file ini)
- scripts/
  - proxmox-postinstall.sh
  - ssh-setup.sh
- examples/
  - i2c_lcd_example.py

---

## Cara menjalankan skrip (contoh)

1) Review skrip sebelum menjalankan. Jangan jalankan tanpa memeriksa isi.
2) Beri hak eksekusi:

chmod +x scripts/*.sh

3) Jalankan postinstall (sebagai root):

sudo ./scripts/proxmox-postinstall.sh

4) Jalankan setup SSH (sesuaikan ARGUMENT):

sudo ./scripts/ssh-setup.sh admin /path/to/pubkey.pub

---

Jika Anda setuju, saya akan menambahkan skrip `scripts/proxmox-postinstall.sh`, `scripts/ssh-setup.sh`, dan contoh `examples/i2c_lcd_example.py` ke repo. Setelah itu kita lanjut membuat LXC template dan provisioning untuk app server.
