#!/bin/bash
set -e

echo "========================================"
echo "   ErpPlus Development Setup"
echo "========================================"

cd /home/frappe/frappe-bench

# 1. Init bench if not already done
if [ ! -f "sites/common_site_config.json" ]; then
    echo "[1/6] Initializing Frappe Bench..."
    bench init --skip-redis-config-generation --frappe-branch version-17 /tmp/frappe-bench
    cp -r /tmp/frappe-bench/* /home/frappe/frappe-bench/ 2>/dev/null || true
    cp -r /tmp/frappe-bench/.* /home/frappe/frappe-bench/ 2>/dev/null || true
    rm -rf /tmp/frappe-bench
else
    echo "[1/6] Bench already initialized, skipping..."
fi

# 2. Configure site_config for Docker services
echo "[2/6] Configuring connections..."
cat > sites/common_site_config.json <<EOF
{
    "db_host": "mariadb",
    "db_port": 3306,
    "redis_cache": "redis://redis-cache:6379",
    "redis_queue": "redis://redis-queue:6379",
    "redis_socketio": "redis://redis-cache:6379",
    "socketio_port": 9000
}
EOF

# 3. Install app if not linked
if [ ! -L "apps/erpnext" ] && [ ! -d "apps/erpnext/erpnext" ]; then
    echo "[3/6] Linking ErpPlus app..."
    ln -sf /home/frappe/frappe-bench/apps/erpnext apps/erpnext 2>/dev/null || true
fi

# Install erpnext pip dependencies
echo "[3/6] Installing ErpPlus dependencies..."
cd apps/erpnext && pip install -e . --quiet && cd /home/frappe/frappe-bench

# 4. Create new site
SITE_NAME="erpplus.localhost"
if [ ! -d "sites/$SITE_NAME" ]; then
    echo "[4/6] Creating site: $SITE_NAME ..."
    bench new-site $SITE_NAME \
        --mariadb-root-password 123 \
        --admin-password admin \
        --no-mariadb-socket
else
    echo "[4/6] Site already exists, skipping..."
fi

# 5. Install app on site
echo "[5/6] Installing ErpPlus on site..."
bench --site $SITE_NAME install-app erpnext || echo "App may already be installed"

# 6. Set as default site
bench use $SITE_NAME

echo ""
echo "========================================"
echo "   ErpPlus Setup Complete!"
echo "========================================"
echo ""
echo "   URL:      http://localhost:8069"
echo "   Username: Administrator"
echo "   Password: admin"
echo ""
echo "   Run: bench start"
echo "========================================"
