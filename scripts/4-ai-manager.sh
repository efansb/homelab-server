#!/bin/bash
# ==================================================
# SCRIPT 4: AI AGENT MANAGER
# Untuk: Manajemen AI Agent + Ollama
# ==================================================

set -e
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}   AI AGENT MANAGER${NC}"
echo -e "${GREEN}=========================================${NC}"

cd ~/ai-agent

# --- MENU ---
echo ""
echo -e "${YELLOW}Pilih aksi:${NC}"
echo "1) Start AI Agent"
echo "2) Stop AI Agent"
echo "3) Restart AI Agent"
echo "4) Status AI Agent"
echo "5) Logs AI Agent"
echo "6) Update AI Agent (pull latest images)"
echo "7) Pull model baru"
echo "8) List models"
echo "9) Test AI Agent (curl test)"
echo "10) Backup AI Agent data"
echo "11) Hapus AI Agent (danger!)"
echo "0) Exit"
echo ""
read -p "Pilihan (0-11): " choice

case $choice in
  1)
    echo -e "${GREEN}🔄 Starting AI Agent...${NC}"
    docker compose up -d
    sleep 3
    echo -e "${GREEN}✅ Started${NC}"
    curl -s http://localhost:5000/health | jq . 2>/dev/null || echo "Health check: OK"
    ;;
  2)
    echo -e "${YELLOW}🛑 Stopping AI Agent...${NC}"
    docker compose down
    echo -e "${GREEN}✅ Stopped${NC}"
    ;;
  3)
    echo -e "${YELLOW}🔄 Restarting AI Agent...${NC}"
    docker compose restart
    echo -e "${GREEN}✅ Restarted${NC}"
    ;;
  4)
    echo -e "${YELLOW}📊 Status AI Agent:${NC}"
    docker ps --filter "name=ollama" --filter "name=ai-agent" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    echo -e "${YELLOW}Health check:${NC}"
    curl -s http://localhost:5000/health | jq . 2>/dev/null || echo "❌ AI Agent tidak merespon"
    ;;
  5)
    echo -e "${YELLOW}📋 Logs AI Agent (CTRL+C untuk keluar):${NC}"
    docker compose logs -f
    ;;
  6)
    echo -e "${YELLOW}🔄 Updating AI Agent...${NC}"
    docker compose down
    docker compose pull
    docker compose up -d
    echo -e "${GREEN}✅ Update selesai${NC}"
    ;;
  7)
    echo -e "${YELLOW}📥 Model tersedia:${NC}"
    echo "  - tinyllama   (637MB)  - cepat, ringan"
    echo "  - phi         (1.5GB)  - cukup pintar"
    echo "  - llama3.2    (2.3GB)  - sangat pintar (RAM > 1GB)"
    echo "  - gemma2      (2.5GB)  - Google's model"
    echo "  - mistral     (4.1GB)  - RAM 4GB hampir penuh"
    echo ""
    read -p "Nama model yang akan di-pull: " model
    if [ ! -z "$model" ]; then
      echo -e "${YELLOW}⬇️  Pulling $model...${NC}"
      docker exec -it ollama ollama pull $model
      echo -e "${GREEN}✅ $model selesai${NC}"
    fi
    ;;
  8)
    echo -e "${YELLOW}📦 Models tersedia:${NC}"
    docker exec -it ollama ollama list
    ;;
  9)
    echo -e "${YELLOW}🧪 Test AI Agent:${NC}"
    read -p "Prompt: " prompt
    if [ ! -z "$prompt" ]; then
      curl -s "http://localhost:5000/ask?prompt=$(echo $prompt | sed 's/ /%20/g')" | jq . 2>/dev/null || curl -s "http://localhost:5000/ask?prompt=$(echo $prompt | sed 's/ /%20/g')"
    fi
    ;;
  10)
    echo -e "${YELLOW}💾 Backup AI Agent data...${NC}"
    BACKUP_DIR=~/backups/ai-agent-$(date +%Y%m%d-%H%M%S)
    mkdir -p $BACKUP_DIR
    cp -r ~/ai-agent/app $BACKUP_DIR/
    cp ~/ai-agent/docker-compose.yml $BACKUP_DIR/
    echo "Membackup data Ollama (besar, bisa lama)..."
    tar -czf $BACKUP_DIR/ollama_data.tar.gz ~/ai-agent/ollama_data/ 2>/dev/null || echo "Data Ollama tidak ditemukan"
    echo -e "${GREEN}✅ Backup selesai di $BACKUP_DIR${NC}"
    ls -lh $BACKUP_DIR/
    ;;
  11)
    echo -e "${RED}⚠️  PERINGATAN! Ini akan menghapus semua data AI Agent${NC}"
    read -p "Yakin? (ketik 'YES' untuk konfirmasi): " confirm
    if [ "$confirm" = "YES" ]; then
      echo -e "${RED}🗑️  Menghapus AI Agent...${NC}"
      docker compose down -v
      cd ~
      rm -rf ~/ai-agent
      echo -e "${RED}✅ AI Agent dihapus${NC}"
    else
      echo "Dibatalkan"
    fi
    ;;
  0)
    echo "Exit"
    exit 0
    ;;
  *)
    echo -e "${RED}Pilihan tidak valid${NC}"
    ;;
esac

echo ""
read -p "Tekan ENTER untuk kembali ke menu..."
./$0