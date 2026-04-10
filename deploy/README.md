# ErpPlus Deployment Guide

## Architecture

```
┌─────────────────────────────┐    ┌─────────────────────────────┐
│  GCP VM 1 (Tester)          │    │  GCP VM 2 (Production)      │
│  e2-small (2 vCPU, 2GB)     │    │  e2-medium (2 vCPU, 4GB)    │
│  30GB SSD                   │    │  50GB SSD                   │
│                             │    │                             │
│  testerp.tplus.asset.com   │    │  tplusoneleasing.com        │
│  developer_mode: ON         │    │  developer_mode: OFF        │
│  scheduler: ON              │    │  scheduler: ON              │
└─────────────────────────────┘    └─────────────────────────────┘
```

## Pre-requisites

### 1. GCP VM Setup
- สร้าง VM 2 ตัว บน Google Cloud Console
- OS: **Ubuntu 24.04 LTS**
- เปิด Firewall: port **80** (HTTP), **443** (HTTPS), **22** (SSH)

### 2. DNS Records
ที่ Domain registrar ให้ชี้ A Record:

| Type | Name | Value |
|------|------|-------|
| A | tplusoneleasing.com | [IP ของ Production VM] |
| A | testerp.tplus.asset.com | [IP ของ Tester VM] |

### 3. Push Code ขึ้น GitHub
```bash
cd /path/to/ErpPlus
git remote add origin https://github.com/YOUR_USERNAME/ErpPlus.git
git push -u origin develop
```

## Deploy

### Tester VM
```bash
ssh user@[TESTER_VM_IP]

# แก้ไข ERPPLUS_REPO ใน script ก่อน
nano deploy.sh
# เปลี่ยน YOUR_USERNAME เป็น GitHub username จริง

chmod +x deploy.sh
./deploy.sh
```

### Production VM
```bash
ssh user@[PRODUCTION_VM_IP]

# แก้ไข ERPPLUS_REPO + passwords ใน script ก่อน
nano deploy.sh
# เปลี่ยน YOUR_USERNAME และ passwords

chmod +x deploy.sh
./deploy.sh
```

## Post-Deploy

### อัปเดตระบบ
```bash
cd /home/erpplus/erpplus-bench
bench update --pull --reset
```

### Backup
```bash
bench --site tplusoneleasing.com backup --with-files
```

### ดู Logs
```bash
# Error log
tail -f /home/erpplus/erpplus-bench/logs/frappe.log

# Web requests
tail -f /home/erpplus/erpplus-bench/logs/web.log
```

### Restart Services
```bash
sudo supervisorctl restart all
sudo systemctl restart nginx
```
