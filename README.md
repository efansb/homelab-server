# 🖥️ Homelab Server - HP Pavilion i3 Gen4

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> Repositori ini berisi panduan dan skrip untuk menyiapkan homelab: instalasi Proxmox VE 8.3 pada laptop/PC tua, post-install, paket dasar host (PVE), konfigurasi SSH, konfigurasi lid/layar (agar laptop tetap menyala saat ditutup dan layar mati setelah 10 menit idle), dan skrip otomatisasi.

## 📋 Spesifikasi Hardware (contoh)

- Laptop: HP Pavilion (i3 Gen4, 2 core)
- RAM: 4 GB (rekomendasi upgrade ke 8 GB jika memungkinkan)
- Storage: HDD/SSD

## Tujuan

Membuat host Proxmox VE 8.3 yang siap untuk menjalankan beberapa LXC/VM ringan untuk layanan home (Pi-hole, Home Assistant, Nextcloud, Jellyfin, dsb.). Dokumen ini berisi langkah instalasi Proxmox, post-install, skrip otomatis, konfigurasi lid/screen, dan contoh penggunaan.

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

apt install -y curl wget htop vim git net-tools lvm2 thin-provisioning-tools smartmontools hdparm python3-pip ufw fail2ban haveged

Penjelasan singkat: curl/wget (download), htop (monitor), lvm2 (storage), smartmontools/hdparm (cek disk), python3-pip (untuk tools tambahan), ufw/fail2ban (keamanan), haveged (entropy untuk VM).

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

9) Lid (tutup layar) dan Screen-off (mati layar tapi server tetap menyala)

Tujuan konfigurasi ini:
- Ketika laptop ditutup (lid close), server tetap menyala dan tidak suspend/hibernate.
- Layar (backlight/console) otomatis mati setelah 10 menit tidak ada aktivitas untuk menghemat daya, namun sistem tetap berjalan.

Langkah yang direkomendasikan (ada skrip otomatis di `scripts/lid-and-screen.sh` untuk menerapkan perubahan):

A) Prevent suspend on lid close (systemd-logind)
- Edit /etc/systemd/logind.conf dan set nilai berikut:
  HandleLidSwitch=ignore
  HandleLidSwitchDocked=ignore
  HandleLidSwitchExternalPower=ignore

- Restart service:
  systemctl restart systemd-logind

B) Matikan layar setelah 10 menit idle (console blanking)
- Tambahkan kernel parameter consoleblank=600 (600 detik = 10 menit) di GRUB agar blanking berlaku konsol default:
  - Edit `/etc/default/grub` dan ubah baris `GRUB_CMDLINE_LINUX_DEFAULT` untuk menambahkan `consoleblank=600` jika belum ada.
  - Contoh:
    GRUB_CMDLINE_LINUX_DEFAULT="quiet consoleblank=600"
  - Lalu jalankan: `update-grub`

- Selain kernel param, ada unit systemd (`consoleblank.service`) yang disertakan oleh skrip untuk menjalankan `setterm` pada tty1..tty6 sehingga layar konsol akan mati/powerdown setelah 10 menit.

Catatan: Jika Anda menjalankan desktop/X, gunakan pengaturan DPMS/xset di lingkungan grafis; panduan ini mengasumsikan host Proxmox headless (no X).

10) Skrip otomatis

Skrip disediakan di `scripts/`:
- scripts/proxmox-postinstall.sh — tugas post-install otomatis (tambahkan repo, update, install paket dasar, swap, enable haveged, konfigurasi ufw)
- scripts/ssh-setup.sh — setup user SSH dan konfigurasi dasar (harus disunting agar sesuai public key Anda)
- scripts/lid-and-screen.sh — terapkan perubahan untuk mencegah suspend saat tutup tutup dan mengatur screen-off (console blanking 10 menit)

---

## Struktur repo (saat ini)

- README.md (file ini)
- scripts/
  - proxmox-postinstall.sh
  - ssh-setup.sh
  - lid-and-screen.sh

---

## Cara menjalankan skrip (contoh)

1) Review skrip sebelum menjalankan. Jangan jalankan tanpa memeriksa isi.
2) Beri hak eksekusi:

chmod +x scripts/*.sh

3) Jalankan postinstall (sebagai root):

sudo ./scripts/proxmox-postinstall.sh

4) Jalankan setup SSH (sesuaikan ARGUMENT):

sudo ./scripts/ssh-setup.sh admin /path/to/your.pub

5) Terapkan pengaturan lid & screen (sebagai root):

sudo ./scripts/lid-and-screen.sh

---

Jika Anda ingin, saya akan membuat beberapa template LXC dan contoh provisioning untuk layanan (Pi-hole, Home Assistant, Nextcloud). Beri tahu layanan mana yang ingin Anda prioritaskan.
