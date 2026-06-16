# Installation Guide — ERPNext School Management System

> **ERPNext v15.109.3** | Docker Desktop | Cloudflare Tunnel  
> Validated: June 2026

---

## Prerequisites

### Hardware Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| RAM | 8 GB | 16 GB |
| CPU | 4 cores | 8 cores |
| SSD | 50 GB free | 100 GB free |
| OS | Windows 10/11, Ubuntu 20.04+, macOS 12+ | Any |

### Software Requirements

**Windows:**
```powershell
# 1. Enable WSL2
wsl --install

# 2. Download Docker Desktop
# https://www.docker.com/products/docker-desktop/
# Install with WSL2 backend

# 3. Enable WSL2 integration in Docker Desktop Settings
# Docker Desktop → Settings → Resources → WSL Integration → Enable
```

**Linux (Ubuntu/Debian):**
```bash
# Install Docker
curl -fsSL https://get.docker.com | bash
sudo usermod -aG docker $USER
# Log out and back in

# Install Docker Compose plugin
sudo apt-get install docker-compose-plugin
```

**macOS:**
```bash
# Download Docker Desktop for Mac
# https://www.docker.com/products/docker-desktop/
# Install and start Docker Desktop
```

### Verify Installation
```bash
docker --version          # Should show 24.x or higher
docker compose version    # Should show v2.x or higher
docker info               # Should show server info
```

---

## Step 0 — Clone Repository

```bash
# Clone
git clone https://github.com/yourorg/erpnext-school.git
cd erpnext-school

# Or if you have the files already:
cd /path/to/erpnext-school
```

---

## Step 1 — Configure `.env`

The `.env` file controls everything. **You MUST change these values:**

```bash
# Edit the file
nano .env     # Linux/Mac
notepad .env  # Windows
```

### Critical Settings

#### 1. Passwords (CHANGE ALL OF THESE)

```env
ADMIN_PASSWORD=Admin@MySchool2026!
MARIADB_ROOT_PASSWORD=Root@MySchool2026!SecureDB
MARIADB_PASSWORD=Frappe@MySchool2026!
BACKUP_ENCRYPTION_KEY=MySecretBackupPassphrase2026
```

**Password requirements:**
- Minimum 12 characters
- Mix of uppercase, lowercase, numbers, special chars
- Do NOT use the example passwords above

#### 2. Generate Encryption Key

```bash
# Linux/Mac
python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"

# Windows PowerShell
python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```

Copy the output into `ENCRYPTION_KEY=` in `.env`

#### 3. Site Domain

```env
SITE_NAME=school.localhost
SITE_DOMAIN=erp.yourschool.com     # ← Your actual domain
```

#### 4. Cloudflare Token (Get Later)

```env
CLOUDFLARE_TUNNEL_TOKEN=eyJ...    # Get from Cloudflare dashboard
```

You can set this later. The system works locally without it.

#### 5. Email Configuration

```env
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=school@yourschool.com
SMTP_PASSWORD=your-app-password     # Use Gmail App Password, NOT your Google password
```

For Gmail App Passwords: https://myaccount.google.com/apppasswords

#### 6. School Settings

```env
SCHOOL_NAME=My School Name
DEFAULT_CURRENCY=INR
DEFAULT_COUNTRY=India
DEFAULT_TIMEZONE=Asia/Kolkata
```

---

## Step 2 — Create Data Directories

```bash
# Linux/Mac
bash scripts/init-dirs.sh

# Windows PowerShell
# Run from project directory:
$dirs = @("data\sites","data\sites\assets","data\logs","data\mariadb",
          "data\redis-queue","data\backups","data\backups\database",
          "data\backups\files","data\backups\logs")
foreach ($dir in $dirs) { New-Item -ItemType Directory -Path $dir -Force }
```

**Why this is needed:** Docker bind mounts require host directories to exist BEFORE the container starts.

---

## Step 3 — Build Custom Docker Image

> ⏱️ **Time estimate: 20-45 minutes** (downloads ~3GB, compiles all assets)

```bash
# Linux/Mac
bash scripts/build.sh

# Windows PowerShell
$appsJson = Get-Content "apps.json" -Raw
$appsBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($appsJson))

docker build `
  "--build-arg=FRAPPE_PATH=https://github.com/frappe/frappe" `
  "--build-arg=FRAPPE_BRANCH=version-15" `
  "--build-arg=PYTHON_VERSION=3.11.9" `
  "--build-arg=NODE_VERSION=18.20.4" `
  "--build-arg=APPS_JSON_BASE64=$appsBase64" `
  "--tag=school-erpnext:v15.109.3" `
  "--file=Containerfile" `
  "--progress=plain" `
  "."
```

**What gets baked into the image:**
- Frappe Framework v15
- ERPNext v15
- Frappe Payments v15
- Frappe HRMS v15
- Frappe Education v15
- Frappe LMS v15
- All Python dependencies
- All compiled JavaScript assets

**Verify the build:**
```bash
docker image ls school-erpnext
# Should show: school-erpnext   v15.109.3   <id>   <time>   ~4GB
```

---

## Step 4 — Start Infrastructure

```bash
# Start database and Redis (these must be healthy before the rest)
docker compose up -d db redis-cache redis-queue redis-socketio

# Monitor startup
docker compose logs -f db
# Wait until you see: "ready for connections"

# Verify Redis
docker compose exec redis-cache redis-cli ping  # Should output: PONG
docker compose exec redis-queue redis-cli ping   # Should output: PONG
```

---

## Step 5 — Run Configurator

The configurator writes the common configuration file that all services need:

```bash
docker compose up configurator
# This exits automatically when done
# You should see: bench set-config commands running
```

---

## Step 6 — Start All Services

```bash
docker compose up -d

# Check all containers are running
docker compose ps

# Expected output: all services as "running"
```

**Wait for backend to be ready (1-2 minutes):**
```bash
# Linux/Mac
until curl -sf http://localhost:8000/api/method/ping; do sleep 5; echo "Waiting..."; done
echo "Backend ready!"

# Windows PowerShell
do { Start-Sleep 5; Write-Host "Waiting..." } until (
  (Invoke-WebRequest "http://localhost:8000/api/method/ping" -ErrorAction SilentlyContinue).StatusCode -eq 200
)
```

---

## Step 7 — Create the Frappe Site

```bash
docker compose exec backend bench new-site school.localhost \
  --db-host db \
  --db-port 3306 \
  --db-root-username root \
  --db-root-password "Root@MySchool2026!SecureDB" \
  --admin-password "Admin@MySchool2026!" \
  --no-mariadb-socket \
  --mariadb-user-host-login-scope='%'
```

> ⚠️ **Important:** `--mariadb-user-host-login-scope='%'` is required in Docker because the bench client connects from a different container IP than the database expects.

---

## Step 8 — Install ERPNext and School Apps

```bash
# Install in this exact order (dependency order matters!)

# 1. ERPNext core
docker compose exec backend bench --site school.localhost install-app erpnext

# 2. Payments (required for ERPNext v15 payment gateways)
docker compose exec backend bench --site school.localhost install-app payments

# 3. HRMS (HR and Payroll)
docker compose exec backend bench --site school.localhost install-app hrms

# 4. Education (School Management System)
docker compose exec backend bench --site school.localhost install-app education

# 5. LMS (Online Learning Platform)
docker compose exec backend bench --site school.localhost install-app lms
```

Each install takes 2-5 minutes. You'll see migrations running.

---

## Step 9 — Run Migrations and Enable Scheduler

```bash
# Run all pending migrations
docker compose exec backend bench --site school.localhost migrate

# Enable the scheduler (runs cron-like background tasks)
docker compose exec backend bench --site school.localhost enable-scheduler

# Clear all caches
docker compose exec backend bench --site school.localhost clear-cache
docker compose exec backend bench --site school.localhost clear-website-cache
```

---

## Step 10 — First Login

Open your browser: **http://localhost:8080**

```
Username: Administrator
Password: [your ADMIN_PASSWORD from .env]
```

### Initial Setup Wizard

ERPNext will show a setup wizard. Configure:
1. **Language:** English
2. **Country:** India (or your country)
3. **Currency:** INR (or your currency)
4. **Company Name:** Your School Name
5. **Domain:** Education

### Configure Email

**Settings → Email Account → New**
```
Email ID: school@yourschool.com
Service: Gmail
Password: [your Gmail App Password]
Enable Outgoing: ✓
Default Outgoing: ✓
```

### Run School Setup Script

```bash
docker compose exec backend bench \
  --site school.localhost \
  execute scripts.school-setup.run_setup
```

This creates:
- Academic Years and Terms
- Programs (Nursery → Grade 12)
- Fee Categories
- Fee Structures
- Custom Roles
- Custom Fields on Student/Instructor doctypes
- Email Templates

---

## Verification

Run the complete validation suite:
```bash
bash scripts/validate.sh
```

All critical tests should PASS. See [troubleshooting-guide.md](troubleshooting-guide.md) if any fail.

---

## Troubleshooting Quick Reference

| Problem | Fix |
|---------|-----|
| `docker build` fails | Check internet connection; run with `--no-cache` |
| MariaDB not starting | Check `data/mariadb/` permissions: `chmod 777 data/mariadb/` |
| "Connection refused" on port 8080 | Wait 2 more minutes; check `docker compose logs frontend` |
| Site creation fails with auth error | Check MARIADB_ROOT_PASSWORD in .env matches MariaDB config |
| App install fails | Check `docker compose logs backend`; ensure dependencies installed first |
| Redis connection error | Ensure configurator ran successfully; check `data/sites/common_site_config.json` |

For detailed troubleshooting: [troubleshooting-guide.md](troubleshooting-guide.md)
