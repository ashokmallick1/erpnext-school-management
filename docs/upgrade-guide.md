# Upgrade Guide — ERPNext School

> Safe, tested upgrade procedure for ERPNext v15

---

## When to Upgrade

### Check for Available Updates

```bash
# Check current version
docker compose exec backend bench version

# Check latest v15 releases
# https://github.com/frappe/erpnext/releases?q=v15&expanded=true

# Check Docker Hub for new tags
# https://hub.docker.com/r/frappe/erpnext/tags?name=v15
```

**Recommended upgrade schedule:**
- **Minor patches (v15.x.x → v15.x.(x+1)):** Monthly
- **Point releases (v15.x → v15.(x+1)):** After testing in staging
- **Major versions (v15 → v16):** Planned migration, not covered here

---

## Pre-Upgrade Checklist

```bash
# ✅ 1. Check current system health
bash scripts/health-check.sh
# All services must be HEALTHY before upgrading

# ✅ 2. Create fresh backup
docker compose exec backend bench --site school.localhost backup \
  --with-files --compress
# Verify backup exists:
ls -la data/backups/database/ | tail -3

# ✅ 3. Check disk space (need ~5GB free for new image)
df -h
# Need at least 5GB free

# ✅ 4. Note current version
docker compose exec backend bench version > /tmp/pre-upgrade-versions.txt
cat /tmp/pre-upgrade-versions.txt

# ✅ 5. Check for breaking changes in release notes
# https://github.com/frappe/erpnext/releases/tag/v15.X.X

# ✅ 6. Test during off-peak hours (weekends recommended)
echo "Planned upgrade time: $(date)"
```

---

## Upgrade Process (Automated)

```bash
# Upgrade to specific version
bash scripts/upgrade.sh --tag v15.110.0

# The script does:
# 1. Pre-upgrade backup
# 2. Build new image
# 3. Enable maintenance mode
# 4. Update containers
# 5. Run database migrations
# 6. Clear caches
# 7. Disable maintenance mode
# 8. Verify installation
```

---

## Upgrade Process (Manual)

### Step 1: Update apps.json (if apps changed)

```json
// apps.json - update branches if needed
[
  {
    "url": "https://github.com/frappe/erpnext",
    "branch": "version-15"
  },
  {
    "url": "https://github.com/frappe/payments",
    "branch": "version-15"
  },
  {
    "url": "https://github.com/frappe/hrms",
    "branch": "version-15"
  },
  {
    "url": "https://github.com/frappe/education",
    "branch": "version-15"
  },
  {
    "url": "https://github.com/frappe/lms",
    "branch": "version-15"
  }
]
```

### Step 2: Build New Image

```bash
# Linux/Mac
APPS_JSON_BASE64=$(base64 -w 0 apps.json)

docker build \
  --build-arg=FRAPPE_PATH=https://github.com/frappe/frappe \
  --build-arg=FRAPPE_BRANCH=version-15 \
  --build-arg=PYTHON_VERSION=3.11.9 \
  --build-arg=NODE_VERSION=18.20.4 \
  --build-arg=APPS_JSON_BASE64=$APPS_JSON_BASE64 \
  --tag=school-erpnext:v15.110.0 \
  --tag=school-erpnext:latest \
  --file=Containerfile \
  --no-cache \
  .

# Windows PowerShell
$appsBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes((Get-Content apps.json -Raw)))
docker build `
  "--build-arg=FRAPPE_PATH=https://github.com/frappe/frappe" `
  "--build-arg=FRAPPE_BRANCH=version-15" `
  "--build-arg=APPS_JSON_BASE64=$appsBase64" `
  "--tag=school-erpnext:v15.110.0" `
  "--file=Containerfile" `
  "--no-cache" `
  "."
```

### Step 3: Enable Maintenance Mode

```bash
docker compose exec backend bench \
  --site school.localhost \
  set-maintenance-mode on
```

### Step 4: Update .env and Restart

```bash
# Update version in .env
sed -i 's/CUSTOM_TAG=.*/CUSTOM_TAG=v15.110.0/' .env

# Pull new containers
docker compose --env-file .env up -d
```

### Step 5: Run Migrations

```bash
# Wait for backend
until docker compose exec backend curl -sf http://localhost:8000/api/method/ping; do
  sleep 5; echo "Waiting for backend..."
done

# Run migrations
docker compose exec backend bench \
  --site school.localhost \
  migrate
```

### Step 6: Post-Upgrade Tasks

```bash
# Disable maintenance mode
docker compose exec backend bench \
  --site school.localhost \
  set-maintenance-mode off

# Clear all caches
docker compose exec backend bench --site school.localhost clear-cache
docker compose exec backend bench --site school.localhost clear-website-cache

# Rebuild search index
docker compose exec backend bench --site school.localhost build-search-index

# Verify apps
docker compose exec backend bench --site school.localhost list-apps

# Verify version
docker compose exec backend bench version
```

---

## Post-Upgrade Verification

```bash
# Run full validation
bash scripts/validate.sh

# Manual verification checklist:
# ✅ Login works
# ✅ Student list loads
# ✅ Attendance can be marked
# ✅ Fee creation works
# ✅ Reports generate
# ✅ Email sending works (send a test)
# ✅ File uploads work
# ✅ Cloudflare Tunnel still connected
```

---

## Rollback Procedure

If the upgrade causes issues:

```bash
# Option 1: Revert to old image
# Update .env with old version
sed -i 's/CUSTOM_TAG=v15.110.0/CUSTOM_TAG=v15.109.3/' .env
docker compose up -d

# Then restore pre-upgrade backup
bash scripts/restore.sh --list
# Pick the "pre-upgrade" backup
bash scripts/restore.sh 20260616_020000

# Option 2: Tag-based rollback
docker tag school-erpnext:v15.109.3 school-erpnext:rollback
# Update .env to use rollback tag
sed -i 's/CUSTOM_TAG=.*/CUSTOM_TAG=rollback/' .env
docker compose up -d
```

---

## Staging Environment (Best Practice)

Before upgrading production, test on a staging copy:

```bash
# Create staging directory
mkdir -p /opt/erpnext-school-staging
cp -r . /opt/erpnext-school-staging/
cd /opt/erpnext-school-staging

# Modify staging .env
nano .env
# Change: SITE_NAME=school-staging.localhost
# Change: NGINX_PORT=8081
# Change: COMPOSE_PROJECT_NAME=erpnext-school-staging

# Restore production backup to staging
cp -r /path/to/production/data/backups/database/latest/ ./data/backups/database/

# Build new image on staging
bash scripts/build.sh

# Test upgrade on staging first
bash scripts/upgrade.sh --tag v15.110.0

# Run validation on staging
bash scripts/validate.sh

# If all good → upgrade production
cd /path/to/production
bash scripts/upgrade.sh --tag v15.110.0
```

---

## ERPNext v15 → v16 (Future Planning)

> **Note:** v15 EOL is end-2027. Do NOT upgrade until thoroughly tested.

Key changes in v16:
- New frontend (Vue.js-based desk)
- Updated API contracts
- Database schema changes

Migration path:
1. Test v16 in parallel environment
2. Test all custom configurations
3. Plan for 4+ hour migration window
4. Upgrade education app to v16 branch
5. Follow official migration guide

---

## Keeping Base Images Updated

MariaDB and Redis should also be updated periodically:

```bash
# Pull latest patch versions
docker pull mariadb:10.6
docker pull redis:7.2-alpine
docker pull cloudflare/cloudflared:latest

# Restart with new images
docker compose up -d --pull missing
```

> MariaDB **major** version changes (10.6 → 10.11) require a separate migration procedure. Keep at 10.6 until ERPNext officially supports the new version.
