#!/bin/bash
set -euo pipefail

# lid-and-screen.sh
# Usage: sudo ./lid-and-screen.sh
# Notes:
# - Akan backup file yang diubah.
# - Menambahkan consoleblank=600 ke GRUB_CMDLINE_LINUX_DEFAULT.
# - Menetapkan HandleLidSwitch=ignore di /etc/systemd/logind.conf.
# - Membuat consoleblank service yang menjalankan setterm untuk tty1..tty6.

echo "Backup dan konfigurasi logind.conf"
LOGIND_CONF="/etc/systemd/logind.conf"
cp "$LOGIND_CONF" "${LOGIND_CONF}.bak.$(date +%s)" || true

# Set values (replace or append)
sed -i 's/^#\?HandleLidSwitch=.*$/HandleLidSwitch=ignore/' "$LOGIND_CONF" || echo "HandleLidSwitch=ignore" >> "$LOGIND_CONF"
sed -i 's/^#\?HandleLidSwitchDocked=.*$/HandleLidSwitchDocked=ignore/' "$LOGIND_CONF" || echo "HandleLidSwitchDocked=ignore" >> "$LOGIND_CONF"
sed -i 's/^#\?HandleLidSwitchExternalPower=.*$/HandleLidSwitchExternalPower=ignore/' "$LOGIND_CONF" || echo "HandleLidSwitchExternalPower=ignore" >> "$LOGIND_CONF"

echo "Restart systemd-logind..."
systemctl restart systemd-logind

# GRUB consoleblank (600 seconds = 10 minutes)
GRUB_FILE="/etc/default/grub"
cp "$GRUB_FILE" "${GRUB_FILE}.bak.$(date +%s)"
if grep -q "consoleblank=" "$GRUB_FILE"; then
  # replace existing consoleblank value
  sed -i 's/consoleblank=[0-9]\+/consoleblank=600/g' "$GRUB_FILE"
else
  # append to GRUB_CMDLINE_LINUX_DEFAULT
  sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\\1 consoleblank=600"/' "$GRUB_FILE"
fi

echo "Updating grub..."
if command -v update-grub >/dev/null 2>&1; then
  update-grub
else
  echo "update-grub tidak ditemukan; abaikan dan pastikan GRUB diperbarui sesuai distro Anda."
fi

# Create script to set term behavior on ttys
CB_SCRIPT="/usr/local/bin/consoleblank-setter.sh"
cat > "$CB_SCRIPT" <<'EOF'
#!/bin/bash
# Apply setterm blanking/powerdown to tty1..tty6
for tty in /dev/tty{1..6}; do
  if [ -w "$tty" ]; then
    # blank after 10 minutes (600s) and enable powerdown
    /usr/bin/setterm -blank 10 -powersave powerdown > "$tty"
  fi
done
EOF

chmod +x "$CB_SCRIPT"

# Create systemd service
SERVICE_FILE="/etc/systemd/system/consoleblank.service"
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Apply console blanking to virtual ttys (tty1..tty6)
After=local-fs.target

[Service]
Type=oneshot
ExecStart=$CB_SCRIPT
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now consoleblank.service || true

echo "Konfigurasi lid/screen selesai."
echo "- HandleLidSwitch set to ignore (logind.conf)."
echo "- GRUB consoleblank set to 600s (10 menit) — pastikan update-grub dijalankan pada sistem Anda."
echo "- consoleblank.service dibuat dan diaktifkan untuk menerapkan setterm ke tty1..6."
echo "Rekomendasi: reboot untuk memastikan semua perubahan diterapkan."
