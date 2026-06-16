# Backup & Restore Guide

> Data protection for ERPNext School Management System

---

## What Gets Backed Up

| Data | Location | Backed Up? |
|------|---------|-----------|
| All database data | MariaDB | ✅ Daily |
| Student files/photos | sites/school.localhost/private | ✅ Daily |
| Public uploads | sites/school.localhost/public | ✅ Daily |
| Site configuration | sites/school.localhost/site_config.json | ✅ Daily |
| Application code | Docker image | ✅ Rebuild |

---

## Automatic Backup (Daily at 02:00 AM)

The `backup` service runs automatically. Monitor it:

```bash
# Check backup service
docker compose ps backup
docker compose logs -f backup

# Successful backup log shows:
# [INFO] Starting backup: 20260616_020000
# [✓] Database backup completed
# [✓] Backup size: 45M
# [✓] Backup complete: 20260616_020000
```

Backups stored in: `data/backups/database/<timestamp>/`

---

## Manual Backup

```bash
# Quick backup via bench (no encryption)
docker compose exec backend bench --site school.localhost backup --with-files

# Backup via the backup script (with encryption)
docker compose exec backup bash /scripts/backup-cron.sh

# Backup to specific directory
docker compose exec backend bench --site school.localhost backup \
  --with-files \
  --compress \
  --backup-path /backups/manual-$(date +%Y%m%d)
```

---

## Backup Location & Structure

```
data/backups/
├── database/
│   ├── 20260616_020000/         ← Backup timestamp
│   │   ├── BACKUP_MANIFEST.json ← Backup metadata
│   │   ├── *-database.sql.gz.enc ← Encrypted DB dump
│   │   ├── *-files.tar.gz.enc   ← Encrypted files
│   │   └── *-private-files.tar.gz.enc
│   ├── 20260615_020000/
│   └── ...
├── files/
└── logs/
    └── backup_20260616_020000.log
```

---

## List Available Backups

```bash
bash scripts/restore.sh --list

# Output:
# Available backups:
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#   20260616_020000 (45M) ← manifest available
#   20260615_020000 (44M) ← manifest available
#   20260614_020000 (43M) ← manifest available
```

---

## Restore Procedure

### Full Restore (from backup)

```bash
# List backups first
bash scripts/restore.sh --list

# Restore specific backup
bash scripts/restore.sh 20260616_020000

# Restore most recent backup
bash scripts/restore.sh
```

The restore script:
1. Prompts for confirmation (type `RESTORE`)
2. Decrypts backup files
3. Enables maintenance mode
4. Restores database
5. Restores files
6. Runs migrations
7. Clears caches
8. Disables maintenance mode
9. Restarts services

### Manual Restore (Advanced)

```bash
# 1. Decrypt backup (if encrypted)
openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 \
  -pass "pass:${BACKUP_ENCRYPTION_KEY}" \
  -in data/backups/database/20260616_020000/*-database.sql.gz.enc \
  -out /tmp/database.sql.gz

# 2. Enable maintenance mode
docker compose exec backend bench --site school.localhost set-maintenance-mode on

# 3. Restore database
docker compose exec backend bench --site school.localhost restore /tmp/database.sql.gz

# 4. Run migrations
docker compose exec backend bench --site school.localhost migrate

# 5. Disable maintenance mode
docker compose exec backend bench --site school.localhost set-maintenance-mode off

# 6. Clear caches
docker compose exec backend bench --site school.localhost clear-cache
```

---

## Verify Backup Integrity

```bash
# Check backup manifest
cat data/backups/database/20260616_020000/BACKUP_MANIFEST.json

# Verify backup file (decrypt + check SQL header)
openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 \
  -pass "pass:${BACKUP_ENCRYPTION_KEY}" \
  -in data/backups/database/20260616_020000/*-database.sql.gz.enc | \
  gunzip | head -5
# Should start with: -- MariaDB dump
```

---

## S3 / Cloud Backup (Optional)

Enable in `.env`:
```env
S3_BACKUP_ENABLED=true
S3_BUCKET_NAME=yourschool-backups
S3_ACCESS_KEY=AKIAXXXXXXXXXXXXXXXX
S3_SECRET_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
S3_ENDPOINT_URL=https://s3.amazonaws.com
S3_REGION=ap-south-1
```

Restart backup service:
```bash
docker compose restart backup
```

Compatible with: AWS S3, DigitalOcean Spaces, Backblaze B2, MinIO, Wasabi

---

## Retention Policy

Default: **30 days** (configurable via `BACKUP_RETENTION_DAYS` in `.env`)

The backup cron automatically deletes backups older than the retention period.

To keep more backups:
```env
BACKUP_RETENTION_DAYS=90
```

---

## Disaster Recovery

### Scenario: Server/Machine Failure

1. **Provision new machine** with Docker Desktop
2. **Clone repository:** `git clone <repo>`
3. **Configure `.env`** (use same passwords as original)
4. **Copy backup files** from old machine (or S3)
5. **Build image:** `bash scripts/build.sh`
6. **Start infrastructure:** `docker compose up -d db redis-cache redis-queue redis-socketio`
7. **Create new site:**
   ```bash
   docker compose exec backend bench new-site school.localhost \
     --db-root-password ... --admin-password ...
   ```
8. **Restore from backup:** `bash scripts/restore.sh`
9. **Start all services:** `docker compose up -d`

### Scenario: Accidental Data Deletion

```bash
# Enable maintenance mode immediately
docker compose exec backend bench --site school.localhost set-maintenance-mode on

# Do NOT clear cache or write anything

# Find most recent backup before the deletion
bash scripts/restore.sh --list

# Restore
bash scripts/restore.sh 20260616_020000
```

---

## Monthly Restore Testing

Best practice: Test restore monthly to ensure backups work.

```bash
# Create a test environment
mkdir /tmp/test-restore && cd /tmp/test-restore
# Copy your docker-compose.yml, .env, apps.json
# Change SITE_NAME to test.localhost, NGINX_PORT to 8085

# Start test environment
docker compose up -d

# Restore from backup
bash scripts/restore.sh 20260616_020000

# Verify data
curl http://localhost:8085/api/method/ping

# Tear down test environment
docker compose down -v
```

---

## Security of Backups

- **Encryption:** AES-256-CBC with PBKDF2 key derivation (100,000 iterations)
- **Key:** Set in `.env` → `BACKUP_ENCRYPTION_KEY`
- **Never store encryption key in same location as backup**
- **Store key in:** Password manager (Bitwarden, 1Password, etc.)
