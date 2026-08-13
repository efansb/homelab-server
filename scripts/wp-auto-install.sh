#!/bin/bash
set -euo pipefail

# wp-auto-install.sh
# Finish WordPress installation using wp-cli inside LXC
# Usage: sudo ./scripts/wp-auto-install.sh <LXC_ID> <site_url> <site_title> <admin_user> <admin_pass> <admin_email>
# Example:
# sudo ./scripts/wp-auto-install.sh 100 blog.7sembilan.my.id "My Blog" wpadmin StrongPass user@domain.com

if [ "$EUID" -ne 0 ]; then
  echo "Run as root"
  exit 1
fi

if [ $# -ne 6 ]; then
  echo "Usage: $0 <LXC_ID> <site_url> <site_title> <admin_user> <admin_pass> <admin_email>"
  exit 1
fi

LXC_ID="$1"
SITE_URL="$2"
SITE_TITLE="$3"
ADMIN_USER="$4"
ADMIN_PASS="$5"
ADMIN_EMAIL="$6"

WP_PATH="/var/www/wordpress"

# Ensure wp-cli is present; install if needed
pct exec $LXC_ID -- bash -lc "which wp >/dev/null 2>&1 || (cd /usr/local/bin && curl -sSL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o wp && chmod +x wp && mv wp /usr/local/bin/wp)"

# Create wp-config with DB credentials (assumes database and user created by provisioning)
# We need to fetch DB credentials from known values in provisioning script; default used there: wpdb/wpuser/ChangeMeWPDB!
DB_NAME="wpdb"
DB_USER="wpuser"
DB_PASS="ChangeMeWPDB!"
DB_HOST="localhost"

# Create config
pct exec $LXC_ID -- bash -lc "cd $WP_PATH && wp config create --dbname='$DB_NAME' --dbuser='$DB_USER' --dbpass='$DB_PASS' --dbhost='$DB_HOST' --allow-root"

# Install core
pct exec $LXC_ID -- bash -lc "cd $WP_PATH && wp core install --url='$SITE_URL' --title='${SITE_TITLE}' --admin_user='$ADMIN_USER' --admin_password='$ADMIN_PASS' --admin_email='$ADMIN_EMAIL' --skip-email --allow-root"

# Set proper permissions
pct exec $LXC_ID -- bash -lc "chown -R www-data:www-data $WP_PATH && find $WP_PATH -type d -exec chmod 755 {} \; && find $WP_PATH -type f -exec chmod 644 {} \;"

cat <<EOF
WordPress should be installed at: http://$SITE_URL/ (or https if configured)
Admin user: $ADMIN_USER
Admin password: $ADMIN_PASS
Admin email: $ADMIN_EMAIL

Note: Change default DB and admin passwords after login. If using Cloudflare Tunnel, use the public hostname to access the site.
EOF
