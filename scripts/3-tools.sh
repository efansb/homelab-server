#!/bin/bash
# ==================================================
# SCRIPT 3: TOOLS + MONITORING
# Untuk: htop, btop, netdata, logrotate, cron
# ==================================================

set -e
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}   SCRIPT 3: TOOLS + MONITORING${NC}"
echo -e "${GREEN}=========================================${NC}"

# --- INSTALL TOOLS ---
echo -e "${YELLOW}[1/6] Install monitoring tools...${NC}"
sudo apt install -y htop btop nethogs iotop iftop ncdu tldr

# btop butuh library
sudo apt install -y libgcc-s1 libstdc++6

echo -e "${GREEN}✓ Tools terinstall: htop, btop, nethogs, iotop, iftop, ncdu${NC}"

# --- INSTALL NETDATA (LIGHTWEIGHT MONITORING) ---
echo -e "${YELLOW}[2/6] Install Netdata (monitoring realtime)...${NC}"
sudo apt install -y netdata netdata-core netdata-web
sudo systemctl enable netdata
sudo systemctl start netdata

# Konfigurasi Netdata (akses dari localhost only)
sudo sed -i 's/# bind socket to IP = 127.0.0.1/bind socket to IP = 127.0.0.1/' /etc/netdata/netdata.conf
sudo systemctl restart netdata

echo -e "${GREEN}✓ Netdata running di http://localhost:19999${NC}"

# --- INSTALL LOGROTATE ---
echo -e "${YELLOW}[3/6] Setup Logrotate...${NC}"
sudo apt install -y logrotate

# Buat konfigurasi custom
sudo cat > /etc/logrotate.d/custom-apps << 'EOF'
# WordPress logs
/var/log/nginx/*.log /var/log/php/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 640 www-data adm
    sharedscripts
    postrotate
        systemctl reload php8.2-fpm > /dev/null 2>&1 || true
    endscript
}

# Caddy logs
/var/log/caddy/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 640 caddy caddy
    sharedscripts
    postrotate
        systemctl reload caddy > /dev/null 2>&1 || true
    endscript
}

# AI Agent logs
/home/*/ai-agent/logs/*.log {
    daily
    rotate 3
    compress
    missingok
    notifempty
    create 0640 $USER $USER
}
EOF

echo -e "${GREEN}✓ Logrotate selesai${NC}"

# --- CRON JOBS (AUTOMATIC MAINTENANCE) ---
echo -e "${YELLOW}[4/6] Setup Cron Jobs...${NC}"
(crontab -l 2>/dev/null || true; cat << 'EOF' ) | crontab -
# Maintenance setiap hari jam 3 pagi
0 3 * * * sudo systemctl restart caddy 2>/dev/null
0 3 * * * sudo journalctl --vacuum-size=50M

# Restart AI Agent tiap minggu (memory leak)
0 4 * * 0 cd ~/ai-agent && docker compose restart

# Health check setiap 5 menit
*/5 * * * * curl -s http://localhost:5000/health > /dev/null || echo "AI Agent down!" | logger

# Backup WordPress tiap minggu
0 2 * * 0 tar -czf ~/backups/wordpress-$(date +\%Y\%m\%d).tar.gz /var/www/wp1 2>/dev/null
EOF

mkdir -p ~/backups
echo -e "${GREEN}✓ Cron jobs selesai${NC}"

# --- SCRIPT MONITORING ---
echo -e "${YELLOW}[5/6] Buat script monitoring...${NC}"
cat > ~/monitor.sh << 'EOF'
#!/bin/bash
# Monitoring Dashboard sederhana
clear
echo "========================================="
echo "   SERVER MONITOR - $(date)"
echo "========================================="
echo ""
echo "--- RAM Usage ---"
free -h
echo ""
echo "--- CPU Load ---"
uptime
echo ""
echo "--- Disk Usage ---"
df -h / /home
echo ""
echo "--- Docker Status ---"
docker ps 2>/dev/null || echo "Docker not running"
echo ""
echo "--- Service Status ---"
systemctl status caddy --no-pager | grep Active
systemctl status php8.2-fpm --no-pager | grep Active
echo ""
echo "--- Top 5 Memory Processes ---"
ps aux --sort=-%mem | head -6
echo ""
echo "========================================="
echo "Ketik 'btop' untuk monitoring interaktif"
echo "========================================="
EOF
chmod +x ~/monitor.sh

echo -e "${GREEN}✓ Monitoring script selesai${NC}"

# --- BASH ALIAS ---
echo -e "${YELLOW}[6/6] Tambahkan alias ke .bashrc...${NC}"
cat >> ~/.bashrc << 'EOF'

# Server Monitoring Aliases
alias monitor='~/monitor.sh'
alias ai-start='~/ai-agent/start-ai.sh'
alias ai-stop='~/ai-agent/stop-ai.sh'
alias ai-logs='cd ~/ai-agent && docker compose logs -f'
alias ai-status='curl -s http://localhost:5000/health | jq . 2>/dev/null || echo "AI Agent tidak merespon"'
alias wp-restart='sudo systemctl restart php8.2-fpm'
alias caddy-restart='sudo systemctl restart caddy'
alias erp-start='cd ~/erpnext-bench && bench start --no-workers &'
alias logs-all='sudo journalctl -u caddy -f -n 50'
EOF

echo -e "${GREEN}✓ Alias ditambahkan (ketik 'source ~/.bashrc' untuk aktifkan)${NC}"

# --- FINISH ---
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}✅ SCRIPT 3 SELESAI!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "${YELLOW}📋 COMMANDS AVAILABLE:${NC}"
echo "  monitor      - Tampilkan dashboard monitoring"
echo "  btop         - Monitoring interaktif (realtime)"
echo "  ai-start     - Start AI Agent"
echo "  ai-stop      - Stop AI Agent"
echo "  ai-logs      - Lihat log AI Agent"
echo "  wp-restart   - Restart WordPress"
echo "  caddy-restart - Restart Caddy"
echo "  logs-all     - Lihat semua log"
echo ""
echo -e "${YELLOW}📊 Netdata: http://localhost:19999${NC}"
echo ""
echo -e "${GREEN}💡 Jalankan 'source ~/.bashrc' untuk aktifkan alias${NC}"