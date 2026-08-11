# 📥 Panduan Instalasi Lengkap

## Prasyarat

### Hardware
- Laptop/PC dengan minimal RAM 4GB
- Storage minimal 50GB free
- Koneksi internet stabil

### Software
- Debian 12 (minimal installation, CLI-only)
- User dengan akses sudo

### Domain (Opsional, untuk akses publik)
- Domain yang sudah terdaftar (contoh: domain-anda.com)
- Akun Cloudflare (gratis)

---

## Step 1: Persiapan OS

### Install Debian 12
1. Download Debian 12 netinst ISO
2. Buat bootable USB dengan Rufus/Etcher
3. Boot dari USB, pilih **Install** (bukan Graphical)
4. Partisi:
   - `/` (root) = 20GB (ext4)
   - `swap` = 8GB
   - `/home` = sisa storage
5. Pilih **SSH server** dan **standard system utilities**
6. **JANGAN** pilih desktop environment

### Login dan Update
```bash
ssh username@ip-laptop
sudo apt update && sudo apt upgrade -y
sudo apt install git -y
