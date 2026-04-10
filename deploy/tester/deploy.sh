#!/bin/bash
# ============================================================
#  ErpPlus - Tester Deployment Script
#  Domain: testerp.tplus.asset.com
#  Server: GCP VM Instance (Ubuntu 24.04 LTS)
#  Spec  : e2-small (2 vCPU, 2GB RAM), 30GB SSD
# ============================================================

set -e

DOMAIN="testerp.tplus.asset.com"
BENCH_USER="erpplus"
ADMIN_PASS="admin_test_123"
DB_ROOT_PASS="db_test_root_123"
FRAPPE_BRANCH="develop"
ERPPLUS_REPO="https://github.com/chaiwatjup-bot/ErpPlus.git"
ERPPLUS_BRANCH="develop"

echo "========================================"
echo "  ErpPlus Tester Deploy"
echo "  Domain: $DOMAIN"
echo "========================================"

# -----------------------------------------------
# 1. System Update & Dependencies
# -----------------------------------------------
echo "[1/10] Installing system dependencies..."

sudo apt update && sudo apt upgrade -y
sudo apt install -y \
    python3-dev python3-pip python3-venv python3-setuptools \
    build-essential libffi-dev libssl-dev libjpeg-dev zlib1g-dev \
    mariadb-server mariadb-client libmariadb-dev \
    redis-server \
    nginx supervisor \
    curl git wget \
    xvfb libfontconfig wkhtmltopdf \
    cron

# -----------------------------------------------
# 2. Node.js 24
# -----------------------------------------------
echo "[2/10] Installing Node.js..."

curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
sudo apt install -y nodejs
sudo npm install -g yarn

# -----------------------------------------------
# 3. MariaDB Configuration
# -----------------------------------------------
echo "[3/10] Configuring MariaDB..."

sudo tee /etc/mysql/mariadb.conf.d/99-erpplus.cnf > /dev/null <<EOF
[mysqld]
character-set-client-handshake = FALSE
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

[mysql]
default-character-set = utf8mb4
EOF

sudo systemctl restart mariadb

sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$DB_ROOT_PASS';" 2>/dev/null || true
sudo mysql -u root -p"$DB_ROOT_PASS" -e "FLUSH PRIVILEGES;" 2>/dev/null || true

# -----------------------------------------------
# 4. Create bench user
# -----------------------------------------------
echo "[4/10] Creating bench user..."

if ! id "$BENCH_USER" &>/dev/null; then
    sudo adduser --disabled-password --gecos "" $BENCH_USER
    sudo usermod -aG sudo $BENCH_USER
    echo "$BENCH_USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$BENCH_USER
fi

# -----------------------------------------------
# 5. Install Frappe Bench
# -----------------------------------------------
echo "[5/10] Installing Frappe Bench..."

sudo -u $BENCH_USER bash -c "pip3 install --user frappe-bench"

# -----------------------------------------------
# 6. Initialize Bench
# -----------------------------------------------
echo "[6/10] Initializing Frappe Bench..."

sudo -u $BENCH_USER bash -c "
    cd /home/$BENCH_USER
    bench init --frappe-branch $FRAPPE_BRANCH erpplus-bench
"

# -----------------------------------------------
# 7. Install ErpPlus App
# -----------------------------------------------
echo "[7/10] Installing ErpPlus app..."

sudo -u $BENCH_USER bash -c "
    cd /home/$BENCH_USER/erpplus-bench
    bench get-app $ERPPLUS_REPO --branch $ERPPLUS_BRANCH
"

# -----------------------------------------------
# 8. Create Site
# -----------------------------------------------
echo "[8/10] Creating tester site..."

sudo -u $BENCH_USER bash -c "
    cd /home/$BENCH_USER/erpplus-bench
    bench new-site $DOMAIN \
        --mariadb-root-password $DB_ROOT_PASS \
        --admin-password $ADMIN_PASS \
        --install-app erpnext

    bench --site $DOMAIN enable-scheduler
    bench use $DOMAIN

    # Enable developer mode for testing
    bench set-config -gp developer_mode 1
"

# -----------------------------------------------
# 9. Production Setup (nginx + supervisor)
# -----------------------------------------------
echo "[9/10] Setting up production mode..."

sudo bench setup production $BENCH_USER --yes
sudo bench setup nginx --yes
sudo supervisorctl restart all
sudo systemctl restart nginx

# -----------------------------------------------
# 10. SSL with Let's Encrypt
# -----------------------------------------------
echo "[10/10] Setting up SSL..."

sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN || {
    echo "SSL setup failed. Run manually:"
    echo "  sudo certbot --nginx -d $DOMAIN"
}

echo ""
echo "========================================"
echo "  ErpPlus Tester Deploy Complete!"
echo "========================================"
echo ""
echo "  URL:      https://$DOMAIN"
echo "  Username: Administrator"
echo "  Password: $ADMIN_PASS"
echo ""
echo "  Developer mode: ENABLED"
echo "========================================"
