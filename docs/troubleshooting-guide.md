# Troubleshooting Guide — ERPNext School

> Diagnose and fix the most common issues

---

## Diagnostic Commands (Start Here)

```bash
# Overall system status
docker compose ps
bash scripts/health-check.sh

# All service logs (last 50 lines)
docker compose logs --tail=50

# Specific service logs
docker compose logs -f backend
docker compose logs -f frontend
docker compose logs -f db
docker compose logs -f cloudflared
docker compose logs -f scheduler
```

---

## Issue 1: Site Shows 502 / 503 Error

**Symptoms:** Browser shows "502 Bad Gateway" or "503 Service Unavailable"

**Cause:** Backend (gunicorn) not running or not ready

**Fix:**
```bash
# Check backend status
docker compose ps backend
docker compose logs --tail=30 backend

# Restart backend
docker compose restart backend

# Wait 60 seconds, then check
sleep 60
curl http://localhost:8080/api/method/ping
# Expected: {"message":"pong"}
```

If backend keeps crashing:
```bash
# Check for site configuration issues
docker compose exec backend bash -c "cat /home/frappe/frappe-bench/sites/common_site_config.json"

# Run configurator again if file is empty/missing
docker compose up configurator
docker compose restart backend
```

---

## Issue 2: Cloudflare Tunnel Not Connecting

**Symptoms:** `https://erp.yourschool.com` shows "ERR_TUNNEL_CONNECTION_FAILED"

**Cause:** Wrong token, token expired, or network issue

**Fix:**
```bash
# Check tunnel logs
docker compose logs --tail=20 cloudflared

# Get a new token from Cloudflare dashboard
# Zero Trust → Networks → Tunnels → your-tunnel → Configure
# Delete the connector and add a new one → copy new token

# Update .env
nano .env
# Set CLOUDFLARE_TUNNEL_TOKEN=new-token-here

# Restart tunnel
docker compose restart cloudflared
docker compose logs -f cloudflared
# Wait for: "Registered tunnel connection"
```

---

## Issue 3: CSS/JS Not Loading (Blank page, unstyled)

**Symptoms:** Login page loads but no styling; browser console shows 404 for .js/.css files

**Cause:** Domain not registered with ERPNext

**Fix:**
```bash
# Register the domain
docker compose exec backend bench setup add-domain erp.yourschool.com \
  --site school.localhost

# Restart frontend
docker compose restart frontend

# If still broken, rebuild assets
docker compose exec backend bench --site school.localhost build
docker compose restart frontend
```

---

## Issue 4: Database Connection Error

**Symptoms:** "Can't connect to MySQL server" in logs

**Cause:** MariaDB not ready, wrong password, or network issue

**Fix:**
```bash
# Check MariaDB status
docker compose ps db
docker compose logs --tail=20 db

# Test connection
docker compose exec db mysqladmin ping -h localhost --silent
# Expected: "mysqld is alive"

# If MariaDB not starting, check data directory
ls -la data/mariadb/
# Should show MySQL data files

# Reset MariaDB data (⚠️ DESTROYS ALL DATA)
# Only if fresh install with no data yet:
docker compose down
rm -rf data/mariadb/*
docker compose up -d db
```

---

## Issue 5: Redis Connection Error

**Symptoms:** "Error connecting to Redis" in backend logs; workers not processing

**Cause:** Redis container not running, or common_site_config.json has wrong URLs

**Fix:**
```bash
# Check Redis containers
docker compose ps redis-cache redis-queue redis-socketio

# Test Redis directly
docker compose exec redis-cache redis-cli ping   # Should: PONG
docker compose exec redis-queue redis-cli ping    # Should: PONG

# Check common_site_config.json has correct Redis URLs
docker compose exec backend cat /home/frappe/frappe-bench/sites/common_site_config.json

# Should show:
# "redis_cache": "redis://redis-cache:6379"
# "redis_queue": "redis://redis-queue:6379"
# "redis_socketio": "redis://redis-socketio:6379"

# If wrong, re-run configurator:
docker compose up configurator
docker compose restart backend websocket queue-short queue-long scheduler
```

---

## Issue 6: Email Not Sending

**Symptoms:** No emails received; no error in UI; email log shows "not sent"

**Fix:**
```bash
# Check email account settings
# ERPNext → Settings → Email Account → your account

# Test SMTP manually
docker compose exec backend python3 -c "
import smtplib
server = smtplib.SMTP('smtp.gmail.com', 587)
server.starttls()
server.login('school@gmail.com', 'your-app-password')
print('SMTP connection OK')
server.quit()
"

# If using Gmail, ensure:
# 1. 2FA is enabled on Google account
# 2. App Password is used (NOT regular password)
# 3. App Password: myaccount.google.com/apppasswords
```

---

## Issue 7: Backup Failing

**Symptoms:** Backup service crashes; no backups in data/backups/

**Fix:**
```bash
# Check backup service logs
docker compose logs --tail=30 backup

# Run backup manually
docker compose exec backend bench --site school.localhost backup \
  --with-files \
  --compress

# Check output location
ls -la data/backups/database/

# If backup directory permissions issue:
chmod -R 777 data/backups/
```

---

## Issue 8: Worker Queue Stuck

**Symptoms:** Background jobs not running; emails not sending; reports not generating

**Fix:**
```bash
# Check worker status
docker compose ps queue-short queue-long

# Check failed queue
docker compose exec redis-queue redis-cli llen "rq:queue:failed"

# Clear failed queue (⚠️ loses failed job data)
docker compose exec redis-queue redis-cli del "rq:queue:failed"

# Restart workers
docker compose restart queue-short queue-long

# Check workers are picking up jobs
docker compose logs -f queue-short
```

---

## Issue 9: Scheduler Not Running

**Symptoms:** Automated tasks not running (fee reminders, etc.)

**Fix:**
```bash
# Check scheduler container
docker compose ps scheduler
docker compose logs --tail=20 scheduler

# Check scheduler is enabled for site
docker compose exec backend bench --site school.localhost doctor

# Enable scheduler if disabled
docker compose exec backend bench --site school.localhost enable-scheduler

# Restart scheduler
docker compose restart scheduler
```

---

## Issue 10: File Upload Failures

**Symptoms:** "File size exceeds limit" or upload hangs

**Fix:**
```bash
# Check nginx client_max_body_size
# Default is 50MB — increase in .env:
# CLIENT_MAX_BODY_SIZE=100m

docker compose restart frontend

# Also check ERPNext file size setting:
# Settings → System Settings → Max File Size (bytes)
# Default: 52428800 (50MB)
```

---

## Issue 11: Login Redirect Loop

**Symptoms:** Login screen → redirect → login screen repeatedly

**Cause:** Session/cookie issue, or site domain not matching

**Fix:**
```bash
# Clear ERPNext caches
docker compose exec backend bench --site school.localhost clear-cache
docker compose exec backend bench --site school.localhost clear-website-cache

# Restart services
docker compose restart backend frontend

# If using Cloudflare Tunnel:
# Ensure FRAPPE_SITE_NAME_HEADER=$$host in docker-compose.yml
# Ensure domain is registered: bench setup add-domain <domain>
```

---

## Issue 12: "Permission Denied" Errors

**Symptoms:** "Not permitted to read Document" or similar errors

**Fix:**
```bash
# Check user's roles
# Settings → User → [username] → Roles

# Reset permissions (rebuilds from defaults)
docker compose exec backend bench --site school.localhost reset-perms

# For a specific app:
docker compose exec backend bench --site school.localhost reset-perms education

# Clear cache after permission changes
docker compose exec backend bench --site school.localhost clear-cache
```

---

## Issue 13: Docker Containers Crashing

**Symptoms:** Container status shows "Exiting" or "Restarting"

**Fix:**
```bash
# Find which container is crashing
docker compose ps

# Get exit code and recent logs
docker compose logs --tail=50 <service-name>

# Common causes by service:
# backend: Python error, site not created, wrong config
# db: Disk full, file permissions, corrupted data
# redis: Out of memory (adjust maxmemory in docker-compose.yml)
# cloudflared: Invalid token

# For disk space issues:
df -h
docker system prune  # Remove unused images/containers
```

---

## Issue 14: Out of Disk Space

**Symptoms:** Containers crashing with "No space left on device"

**Fix:**
```bash
# Check disk usage
df -h
du -sh data/*/

# Largest space consumers:
du -sh data/mariadb/
du -sh data/backups/

# Clean Docker system (safely removes unused data)
docker system prune --volumes  # ⚠️ Removes unused volumes!

# Clean old backups
find data/backups/database/ -type d -mtime +30 -exec rm -rf {} \;

# Increase Docker Desktop disk allocation:
# Docker Desktop → Settings → Resources → Disk image size
```

---

## Issue 15: High CPU/Memory Usage

**Symptoms:** System slow, fans spinning, Docker using excessive resources

**Fix:**
```bash
# Check resource usage
docker stats

# Limit MariaDB memory (in docker-compose.yml):
# --innodb_buffer_pool_size=1G  (reduce from 2G)

# Limit Redis memory (already configured):
# redis-cache: --maxmemory 512mb
# redis-queue: --maxmemory 1gb

# Reduce backend workers (if CPU constrained):
# In docker-compose.yml, remove one of the worker services
# Remove queue-long if not needed for background reports

# Set Docker Desktop resource limits:
# Docker Desktop → Settings → Resources
# Memory: 6GB, CPUs: 4
```

---

## Useful Commands Reference

### Reset Admin Password
```bash
docker compose exec backend bench --site school.localhost set-admin-password "NewPassword123!"
```

### List Installed Apps
```bash
docker compose exec backend bench --site school.localhost list-apps
```

### Rebuild Frontend Assets
```bash
docker compose exec backend bench --site school.localhost build
docker compose restart frontend
```

### Access MariaDB CLI
```bash
docker compose exec db mysql -u root -p
# Enter MARIADB_ROOT_PASSWORD from .env
```

### Access Redis CLI
```bash
docker compose exec redis-cache redis-cli
docker compose exec redis-queue redis-cli info
```

### Check Site Doctor
```bash
docker compose exec backend bench --site school.localhost doctor
```

### Export Site (Backup)
```bash
docker compose exec backend bench --site school.localhost backup \
  --with-files \
  --compress
```

### Check ERPNext Version
```bash
docker compose exec backend bench version
```

### Access Bench Shell
```bash
docker compose exec backend bash
# Now you're inside the container as frappe user
# cd /home/frappe/frappe-bench
```

### View Active Jobs
```bash
docker compose exec redis-queue redis-cli llen "rq:queue:short"
docker compose exec redis-queue redis-cli llen "rq:queue:long"
docker compose exec redis-queue redis-cli llen "rq:queue:failed"
```

### Force Migrate (After Manual Changes)
```bash
docker compose exec backend bench --site school.localhost migrate --skip-failing
```
