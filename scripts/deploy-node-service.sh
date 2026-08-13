#!/bin/bash
set -euo pipefail

# deploy-node-service.sh
# Helper to create PM2 service for a Node.js app in LXC and setup pm2 startup
# Usage: sudo ./scripts/deploy-node-service.sh <LXC_ID> <app_dir> <start_command> <user>
# Example: sudo ./scripts/deploy-node-service.sh 101 /home/efan/myapp "npm start" efan

if [ "$EUID" -ne 0 ]; then
  echo "Run as root"
  exit 1
fi

if [ $# -ne 4 ]; then
  echo "Usage: $0 <LXC_ID> <app_dir> <start_command> <user>"
  exit 1
fi

LXC_ID="$1"
APP_DIR="$2"
START_CMD="$3"
RUN_USER="$4"

# Install pm2 if not present
pct exec $LXC_ID -- bash -lc "which pm2 >/dev/null 2>&1 || npm install -g pm2 --unsafe-perm"

# Run the app under the specified user and save pm2 process list
pct exec $LXC_ID -- bash -lc "su - $RUN_USER -c 'cd $APP_DIR && pm2 start $START_CMD --name \"$(basename $APP_DIR)\"'"

# Generate startup script and save
pct exec $LXC_ID -- bash -lc "su - $RUN_USER -c 'pm2 startup systemd -u $RUN_USER --hp /home/$RUN_USER'"
# The above prints a command; run pm2 save to persist
pct exec $LXC_ID -- bash -lc "su - $RUN_USER -c 'pm2 save'"

cat <<EOF
PM2 process created for app at $APP_DIR inside LXC $LXC_ID and set to restart on boot.
To manage processes:
  sudo pct exec $LXC_ID -- bash -lc "pm2 list"
  sudo pct exec $LXC_ID -- bash -lc "pm2 logs"

EOF
