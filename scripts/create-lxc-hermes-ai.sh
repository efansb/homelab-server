#!/bin/bash
set -euo pipefail

# create-lxc-hermes-ai.sh
# Create LXC for hermes-ai (LXC 103) and install LocalAI (lightweight local inference) via Docker
# This script assumes nesting=1 in container features and that Docker is supported in the LXC
# Usage: sudo ./scripts/create-lxc-hermes-ai.sh

VMID=103
HOSTNAME="hermes-ai"
IPADDR="192.168.18.103/24"
GATEWAY="192.168.18.1"
TEMPLATE_NAME="local:vztmpl/debian-12-standard_12.1-1_amd64.tar.zst"
STORAGE="local-lvm"
ROOTFS_SIZE="8G"
CORES=1
MEMORY=2048
ROOT_PASSWORD="Efan301008"
NONROOT_USER="efan"
NONROOT_PASS="301008"

# Model selection recommendation
# We'll use LocalAI (https://github.com/go-skynet/LocalAI) which provides an OpenAI-compatible API and can run
# smaller ggml models. For low-RAM environments choose a small quantized model such as gpt4all or other ~1GB models.
# This script will deploy LocalAI via Docker and create a models directory for you to place a ggml model.

if [ "$EUID" -ne 0 ]; then
  echo "Run as root"
  exit 1
fi

# Check if exists
if pct status $VMID >/dev/null 2>&1; then
  echo "LXC $VMID already exists. Aborting."
  exit 1
fi

# Ensure template exists, attempt download if not
TEMPLATE_FILE=$(echo "$TEMPLATE_NAME" | awk -F: '{print $2}')
if [ ! -f "/var/lib/vz/template/cache/$TEMPLATE_FILE" ]; then
  echo "Template not found locally. Attempting to download Debian 12 template via pveam..."
  pveam update
  TEMPLATE_SHORT=$(pveam available | awk '/debian-12-standard/ {print $1; exit}') || true
  if [ -n "$TEMPLATE_SHORT" ]; then
    echo "Downloading template $TEMPLATE_SHORT..."
    pveam download local $TEMPLATE_SHORT
    TEMPLATE_NAME="local:vztmpl/$TEMPLATE_SHORT"
  else
    echo "Could not find debian-12 template via pveam. Please download a Debian 12 LXC template first." >&2
    exit 1
  fi
fi

# Create container
pct create $VMID $TEMPLATE_NAME \
  --hostname $HOSTNAME \
  --cores $CORES \
  --memory $MEMORY \
  --net0 name=eth0,bridge=vmbr0,ip=$IPADDR,gw=$GATEWAY \
  --rootfs ${STORAGE}:${ROOTFS_SIZE} \
  --features nesting=1 \
  --password "$ROOT_PASSWORD"

pct start $VMID
sleep 5

# Install Docker (in-container) and docker-compose
pct exec $VMID -- bash -lc "apt update && DEBIAN_FRONTEND=noninteractive apt install -y apt-transport-https ca-certificates curl gnupg lsb-release"
pct exec $VMID -- bash -lc "curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg"
pct exec $VMID -- bash -lc "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable\" > /etc/apt/sources.list.d/docker.list"
pct exec $VMID -- bash -lc "apt update && apt install -y docker-ce docker-ce-cli containerd.io"

# Install docker-compose (plugin)
pct exec $VMID -- bash -lc "apt install -y docker-compose-plugin"

# Create models dir and docker-compose for LocalAI
pct exec $VMID -- bash -lc "mkdir -p /opt/localai/models && chown -R $NONROOT_USER:$NONROOT_USER /opt/localai || true"

cat > /tmp/localai-dc.yml <<'EOF'
version: '3.8'
services:
  localai:
    image: ghcr.io/go-skynet/localai:latest
    container_name: localai
    restart: unless-stopped
    ports:
      - "8080:8080" # OpenAI compatible API
    volumes:
      - ./models:/app/models
    environment:
      - LOKI_LOGGING=debug
      # Example: set model path via CLI args in command if needed
    command: ["localai", "--listen", ":8080", "--model-dir", "/app/models"]
EOF

pct push $VMID /tmp/localai-dc.yml /opt/localai/docker-compose.yml
pct exec $VMID -- bash -lc "chown -R $NONROOT_USER:$NONROOT_USER /opt/localai && cd /opt/localai && docker compose up -d || docker-compose -f docker-compose.yml up -d"

cat <<EOF
LXC $VMID (hermes-ai) created and LocalAI deployed as Docker container.
Notes and next steps:
- LocalAI exposes an OpenAI-compatible API on port 8080 inside the container. Through Cloudflare Tunnel, you can expose it if desired.
- You MUST download a ggml model compatible with LocalAI and place it in /opt/localai/models. Example small models:
  - gpt4all-j (quantized) (~800MB): https://gpt4all.io/models
  - smaller ggml models from huggingface (search 'ggml' / quantized models)
- After placing model file (e.g. ggml-gpt4all-j-v1.3-groovy.bin) into /opt/localai/models, restart the container:
  sudo pct exec 103 -- bash -lc "cd /opt/localai && docker compose restart localai || docker-compose restart"

API usage examples:
- Text completion (curl):
  curl -sX POST http://192.168.18.103:8080/v1/chat/completions -H 'Content-Type: application/json' \
    -d '{"model":"gpt4all-j", "messages":[{"role":"user","content":"Tulis program Python untuk ..."}]}'

- For code generation tasks, call the chat completions API similarly. For image generation, LocalAI currently focuses on text models; for images you may need a separate Stable Diffusion setup (e.g., AUTOMATIC1111) or use cloud APIs.

Security:
- LocalAI does NOT enable authentication by default; if exposing to the internet, secure it (reverse proxy with auth or run behind Cloudflare Tunnel and access only via authenticated hostname).

EOF
