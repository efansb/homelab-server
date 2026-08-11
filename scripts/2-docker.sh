#!/bin/bash
# ==================================================
# SCRIPT 2: DOCKER STACK (AI AGENT)
# Untuk: Docker + Ollama + FastAPI AI Agent
# ==================================================

set -e
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}   SCRIPT 2: DOCKER STACK${NC}"
echo -e "${GREEN}   AI Agent + Ollama${NC}"
echo -e "${GREEN}=========================================${NC}"

# --- CEK USER ---
if [ "$EUID" -eq 0 ]; then 
  echo -e "${RED}Jangan jalankan sebagai root!${NC}"
  exit 1
fi

# --- INSTALL DOCKER ---
echo -e "${YELLOW}[1/5] Install Docker...${NC}"
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
echo -e "${GREEN}✓ Docker selesai (perlu logout/login untuk efek)${NC}"

# --- INSTALL DOCKER COMPOSE ---
echo -e "${YELLOW}[2/5] Install Docker Compose...${NC}"
sudo apt install -y docker-compose-plugin
docker compose version
echo -e "${GREEN}✓ Docker Compose selesai${NC}"

# --- BUAT FOLDER AI AGENT ---
echo -e "${YELLOW}[3/5] Setup AI Agent...${NC}"
mkdir -p ~/ai-agent
cd ~/ai-agent

# --- DOCKER COMPOSE FILE ---
cat > ~/ai-agent/docker-compose.yml << 'EOF'
version: '3.8'

services:
  # Ollama - LLM Server
  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    volumes:
      - ./ollama_data:/root/.ollama
    ports:
      - "11434:11434"
    restart: unless-stopped
    mem_limit: 600m
    cpus: 0.6
    environment:
      - OLLAMA_KEEP_ALIVE=5m
      - OLLAMA_NUM_PARALLEL=2
    deploy:
      resources:
        limits:
          memory: 600M
        reservations:
          memory: 300M

  # FastAPI - AI Agent API
  ai-api:
    image: python:3.11-slim
    container_name: ai-agent
    working_dir: /app
    volumes:
      - ./app:/app
      - ./data:/data
    command: bash -c "pip install --no-cache-dir fastapi uvicorn requests python-multipart && uvicorn app:app --host 0.0.0.0 --port 5000 --workers 1"
    ports:
      - "5000:5000"
    depends_on:
      - ollama
    restart: unless-stopped
    mem_limit: 256m
    cpus: 0.3
    environment:
      - OLLAMA_URL=http://ollama:11434
    deploy:
      resources:
        limits:
          memory: 256M
        reservations:
          memory: 128M
EOF

# --- APP.PY (FastAPI) ---
mkdir -p ~/ai-agent/app
cat > ~/ai-agent/app/app.py << 'EOF'
import os
import json
import requests
from fastapi import FastAPI, Query
from fastapi.responses import JSONResponse
import uvicorn

app = FastAPI(title="AI Agent", version="1.0")
OLLAMA_URL = os.getenv("OLLAMA_URL", "http://ollama:11434")

# Health check
@app.get("/")
def root():
    return {
        "status": "AI Agent running",
        "model": "tinyllama",
        "endpoints": {
            "/ask": "Query AI dengan prompt",
            "/models": "Lihat daftar model",
            "/health": "Health check"
        }
    }

# Health check
@app.get("/health")
def health():
    try:
        r = requests.get(f"{OLLAMA_URL}/api/tags", timeout=5)
        return {"status": "healthy", "ollama": r.status_code == 200}
    except:
        return {"status": "unhealthy", "ollama": False}

# List models
@app.get("/models")
def list_models():
    try:
        r = requests.get(f"{OLLAMA_URL}/api/tags", timeout=5)
        return r.json()
    except Exception as e:
        return {"error": str(e)}

# Chat endpoint
@app.get("/ask")
def ask(
    prompt: str = Query(..., description="Pertanyaan untuk AI"),
    model: str = Query("tinyllama", description="Model yang digunakan")
):
    try:
        payload = {
            "model": model,
            "prompt": prompt,
            "stream": False,
            "options": {
                "temperature": 0.7,
                "top_p": 0.9,
                "max_tokens": 512
            }
        }
        response = requests.post(
            f"{OLLAMA_URL}/api/generate",
            json=payload,
            timeout=30
        )
        if response.status_code == 200:
            data = response.json()
            return {
                "prompt": prompt,
                "response": data.get("response", ""),
                "model": model,
                "total_duration": data.get("total_duration", 0)
            }
        else:
            return {"error": f"Ollama error: {response.status_code}"}
    except requests.exceptions.Timeout:
        return {"error": "Timeout - model mungkin masih loading"}
    except Exception as e:
        return {"error": str(e)}

# POST version untuk chat
@app.post("/ask")
def ask_post(prompt: str, model: str = "tinyllama"):
    return ask(prompt, model)

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=5000, workers=1)
EOF

# --- SCRIPT UNTUK PULL MODEL ---
cat > ~/ai-agent/pull-model.sh << 'EOF'
#!/bin/bash
echo "Mengunduh model TinyLlama (637MB)..."
docker exec -it ollama ollama pull tinyllama
echo "Model siap!"
EOF
chmod +x ~/ai-agent/pull-model.sh

# --- SCRIPT START/STOP ---
cat > ~/ai-agent/start-ai.sh << 'EOF'
#!/bin/bash
cd ~/ai-agent
echo "🔄 Menjalankan AI Agent..."
docker compose up -d
echo "⏳ Menunggu service ready..."
sleep 5
echo "✅ AI Agent berjalan!"
echo "📊 Cek health: curl http://localhost:5000/health"
EOF
chmod +x ~/ai-agent/start-ai.sh

cat > ~/ai-agent/stop-ai.sh << 'EOF'
#!/bin/bash
cd ~/ai-agent
echo "🛑 Menghentikan AI Agent..."
docker compose down
echo "✅ AI Agent dihentikan"
EOF
chmod +x ~/ai-agent/stop-ai.sh

echo -e "${GREEN}✓ AI Agent selesai${NC}"

# --- DOWNLOAD MODEL (OTOMATIS) ---
echo -e "${YELLOW}[4/5] Download model TinyLlama (637MB)...${NC}"
echo "Proses ini memakan waktu tergantung kecepatan internet"
docker compose up -d
sleep 10
docker exec -it ollama ollama pull tinyllama
echo -e "${GREEN}✓ Model selesai diunduh${NC}"

# --- UPDATE CADDY ---
echo -e "${YELLOW}[5/5] Update Caddy untuk AI Agent...${NC}"
if grep -q "ai.domain-anda.com" /etc/caddy/Caddyfile; then
  echo "Caddy sudah memiliki konfigurasi AI Agent"
else
  echo -e "${YELLOW}Tambahkan ke /etc/caddy/Caddyfile:${NC}"
  echo ""
  echo "ai.domain-anda.com {"
  echo "    reverse_proxy localhost:5000"
  echo "}"
  echo ""
  read -p "Tekan ENTER setelah menambahkan ke Caddyfile, atau ketik 'skip' untuk lewati: " -r
  if [[ ! $REPLY =~ ^[Ss]kip$ ]]; then
    sudo systemctl restart caddy
    echo "✓ Caddy direstart"
  fi
fi

# --- STATUS ---
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}✅ SCRIPT 2 SELESAI!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "${YELLOW}📋 COMMANDS AI AGENT:${NC}"
echo "  Start:   ~/ai-agent/start-ai.sh"
echo "  Stop:    ~/ai-agent/stop-ai.sh"
echo "  Logs:    cd ~/ai-agent && docker compose logs -f"
echo "  Pull model lain: docker exec -it ollama ollama pull <model>"
echo ""
echo -e "${YELLOW}📊 TEST AI AGENT:${NC}"
echo "  curl http://localhost:5000/health"
echo "  curl 'http://localhost:5000/ask?prompt=Halo%20siapa%20kamu?'"
echo ""
echo -e "${YELLOW}⚠️  MODEL TERSEDIA:${NC}"
echo "  - tinyllama    (637MB)  ✓ sudah diunduh"
echo "  - phi          (1.5GB)  jalankan: docker exec -it ollama ollama pull phi"
echo "  - llama3.2     (2.3GB)  jalankan: docker exec -it ollama ollama pull llama3.2"