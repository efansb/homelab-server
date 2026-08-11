#!/bin/bash
# ==================================================
# SCRIPT 1: NATIVE STACK
# Untuk: Caddy + Cloudflare Tunnel + WordPress + ERPNext
# ==================================================

set -e
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}   SCRIPT 1: NATIVE STACK${NC}"
echo -e "${GREEN}   Caddy + Cloudflare + WordPress + ERPNext${NC}"
echo -e "${GREEN}=========================================${NC}"

# --- CEK USER ---
if [ "$EUID" -eq 0 ]; then 
  echo -e "${RED}Jangan jalankan sebagai root!${NC}"
  exit 1
fi

# --- UPDATE & DEPENDENSI ---
echo -e "${YELLOW}[1/8] Update sistem...${NC}"
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git build-essential nano unzip software-properties-common

# --- OPTIMASI RAM ---
echo -e "${YELLOW}[2/8] Optimasi RAM (Swap + ZRAM)...${NC}"
if [ ! -f /swapfile ]; then
  sudo dd if=/dev/zero of=/swapfile bs=1M count=8192 status=progress
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi

sudo apt install -y zram-tools
sudo sed -i 's/^PERCENT=.*/PERCENT=50/' /etc/default/zramswap
sudo systemctl restart zramswap
echo -e "${GREEN}✓ RAM Optimasi selesai${NC}"

# --- INSTALL CADDY ---
echo -e "${YELLOW}[3/8] Install Caddy...${NC}"
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install -y caddy
sudo systemctl enable caddy
echo -e "${GREEN}✓ Caddy selesai${NC}"

# --- INSTALL CLOUDFLARED ---
echo -e "${YELLOW}[4/8] Install Cloudflare Tunnel...${NC}"
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
sudo mv cloudflared-linux-amd64 /usr/local/bin/cloudflared
sudo chmod +x /usr/local/bin/cloudflared
cloudflared --version
echo -e "${GREEN}✓ Cloudflared selesai${NC}"

# --- INSTALL WORDPRESS (SQLite) ---
echo -e "${YELLOW}[5/8] Install WordPress + SQLite...${NC}"
sudo apt install -y php php-fpm php-sqlite3 php-curl php-zip php-mbstring php-xml php-gd

sudo mkdir -p /var/www
cd /var/www
sudo wget -q https://wordpress.org/latest.tar.gz
sudo tar -xzf latest.tar.gz
sudo mv wordpress wp1

# SQLite plugin
cd /var/www/wp1
sudo wget -q https://raw.githubusercontent.com/aaemnnosttv/wp-sqlite-db/master/src/db.php

# Konfigurasi PHP-FPM (hemat RAM)
sudo sed -i 's/^pm = .*/pm = ondemand/' /etc/php/8.2/fpm/pool.d/www.conf
sudo sed -i 's/^pm.max_children = .*/pm.max_children = 5/' /etc/php/8.2/fpm/pool.d/www.conf
sudo sed -i 's/^pm.process_idle_timeout = .*/pm.process_idle_timeout = 10s/' /etc/php/8.2/fpm/pool.d/www.conf
sudo systemctl restart php8.2-fpm

# Web statis contoh
sudo mkdir -p /var/www/static1
echo "<h1>Static Site 1</h1><p>Server berjalan di laptop jadul!</p>" | sudo tee /var/www/static1/index.html

echo -e "${GREEN}✓ WordPress selesai di /var/www/wp1${NC}"

# --- INSTALL ERPNext (RINGAN) ---
echo -e "${YELLOW}[6/8] Install ERPNext (Proses lama, 15-30 menit)...${NC}"
echo -e "${YELLOW}⚠️  Tekan CTRL+C untuk skip ERPNext${NC}"
read -p "Lanjut install ERPNext? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  sudo apt install -y python3-dev python3-setuptools redis-server postgresql postgresql-contrib
  sudo pip3 install frappe-bench
  
  cd ~
  bench init --frappe-branch version-14 erpnext-bench --no-backups --verbose
  cd ~/erpnext-bench
  bench new-site erp.localhost --db-type postgresql
  bench get-app erpnext
  bench install-app erpnext
  
  # Tuning RAM
  cat > ~/erpnext-bench/common_site_config.json << 'EOF'
{
  "worker_limit": 2,
  "background_workers": 1,
  "redis_cache_limit": "256m",
  "redis_queue_limit": "256m",
  "allow_unsafe_docs": true
}
EOF
  echo -e "${GREEN}✓ ERPNext selesai${NC}"
else
  echo -e "${YELLOW}⏭️  Skip ERPNext${NC}"
fi

# --- KONFIGURASI CADDY ---
echo -e "${YELLOW}[7/8] Konfigurasi Caddy...${NC}"
sudo cat > /etc/caddy/Caddyfile << 'EOF'
# ============================================
# CADDYFILE - Ganti domain-anda.com dengan domain Anda
# ============================================

# Root domain -> Static site
domain-anda.com {
    root * /var/www/static1
    file_server
}

# WordPress
wp.domain-anda.com {
    reverse_proxy localhost:8080
}

# ERPNext (jika diinstall)
erp.domain-anda.com {
    reverse_proxy localhost:8000
}

# AI Agent (akan ditambahkan oleh script 2)
ai.domain-anda.com {
    reverse_proxy localhost:5000
}
EOF

sudo systemctl restart caddy
echo -e "${GREEN}✓ Caddy dikonfigurasi${NC}"

# --- TEMPLATE CLOUDFLARE ---
echo -e "${YELLOW}[8/8] Persiapan Cloudflare Tunnel...${NC}"
mkdir -p ~/.cloudflared

cat > ~/cloudflare-setup.txt << 'EOF'
============================================
CARA SETUP CLOUDFLARE TUNNEL
============================================

1. Login ke Cloudflare:
   cloudflared tunnel login

2. Buat tunnel:
   cloudflared tunnel create myserver

   Catat Tunnel ID (contoh: abc-123-def)

3. Buat file /etc/cloudflared/config.yml:
   ----------------------------------------
   tunnel: myserver
   credentials-file: /home/USERNAME/.cloudflared/abc-123-def.json
   
   ingress:
     - hostname: domain-anda.com
       service: http://localhost:80
     - hostname: *.domain-anda.com
       service: http://localhost:80
     - service: http_status:404
   ----------------------------------------

4. Jalankan tunnel:
   sudo cloudflared service install
   sudo systemctl enable cloudflared
   sudo systemctl start cloudflared

5. Di Cloudflare DNS, tambahkan:
   CNAME * -> abc-123-def.cfargotunnel.com (Proxy: ON)

============================================
EOF

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}✅ SCRIPT 1 SELESAI!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "${YELLOW}📋 INFORMASI:${NC}"
echo "1. WordPress: /var/www/wp1 (akses via wp.domain-anda.com)"
echo "2. Static site: /var/www/static1"
echo "3. ERPNext: ~/erpnext-bench (jalan manual: bench start --no-workers)"
echo "4. Caddy config: /etc/caddy/Caddyfile"
echo "5. Cloudflare setup: cat ~/cloudflare-setup.txt"
echo ""
echo -e "${YELLOW}⚠️  JANGAN LUPA: Ganti 'domain-anda.com' di /etc/caddy/Caddyfile${NC}"
echo -e "${YELLOW}⚠️  Setup Cloudflare Tunnel sesuai petunjuk di atas${NC}"