#!/usr/bin/env bash
##############################################################
# ERPNext School — Automated Backup Script (Cron Daemon)
# Runs as a long-running service inside the backup container
# Performs: DB backup + file backup + encryption + retention
# Schedule: Daily at 2:00 AM
##############################################################

set -euo pipefail

# ─── Colors ───────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'

log_info()    { echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${GREEN}[✓]${NC} $1"; }
log_warn()    { echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${RED}[ERROR]${NC} $1"; }

# ─── Configuration ────────────────────────────────────────
SITE_NAME="${SITE_NAME:-school.localhost}"
BACKUP_BASE="/backups"
BACKUP_DB_DIR="${BACKUP_BASE}/database"
BACKUP_FILES_DIR="${BACKUP_BASE}/files"
BACKUP_LOGS_DIR="${BACKUP_BASE}/logs"
BENCH_DIR="/home/frappe/frappe-bench"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
ENCRYPTION_KEY="${BACKUP_ENCRYPTION_KEY:-}"
S3_ENABLED="${S3_BACKUP_ENABLED:-false}"

# ─── Perform one backup cycle ────────────────────────────
perform_backup() {
    local TIMESTAMP
    TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
    local BACKUP_DIR="${BACKUP_DB_DIR}/${TIMESTAMP}"

    log_info "═══════════════════════════════════════════"
    log_info "Starting backup: ${TIMESTAMP}"
    log_info "Site: ${SITE_NAME}"
    log_info "═══════════════════════════════════════════"

    mkdir -p "$BACKUP_DIR" "$BACKUP_FILES_DIR" "$BACKUP_LOGS_DIR"

    # ─── Database backup via bench ────────────────────────
    log_info "Backing up database..."
    cd "$BENCH_DIR"

    bench --site "${SITE_NAME}" backup \
        --with-files \
        --compress \
        --backup-path "${BACKUP_DIR}" \
        2>&1 | tee -a "${BACKUP_LOGS_DIR}/backup_${TIMESTAMP}.log"

    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        log_error "Database backup FAILED"
        return 1
    fi
    log_success "Database backup completed"

    # ─── Encrypt backup files ─────────────────────────────
    if [[ -n "$ENCRYPTION_KEY" ]]; then
        log_info "Encrypting backup files..."
        for file in "${BACKUP_DIR}"/*.gz "${BACKUP_DIR}"/*.tar.gz; do
            [[ -f "$file" ]] || continue
            openssl enc -aes-256-cbc -salt \
                -pbkdf2 -iter 100000 \
                -pass "pass:${ENCRYPTION_KEY}" \
                -in "$file" \
                -out "${file}.enc" 2>/dev/null
            if [[ $? -eq 0 ]]; then
                rm -f "$file"
                log_success "Encrypted: $(basename "$file").enc"
            else
                log_warn "Encryption failed for: $(basename "$file")"
            fi
        done
    else
        log_warn "No encryption key set — backup stored unencrypted"
    fi

    # ─── Calculate backup size ────────────────────────────
    BACKUP_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
    log_success "Backup size: $BACKUP_SIZE"

    # ─── S3 Upload (optional) ─────────────────────────────
    if [[ "${S3_ENABLED}" == "true" ]]; then
        log_info "Uploading to S3: s3://${S3_BUCKET_NAME}/$(date '+%Y/%m/%d')/"
        if command -v aws &>/dev/null; then
            AWS_ACCESS_KEY_ID="${S3_ACCESS_KEY}" \
            AWS_SECRET_ACCESS_KEY="${S3_SECRET_KEY}" \
            AWS_DEFAULT_REGION="${S3_REGION:-us-east-1}" \
            aws s3 sync "${BACKUP_DIR}" \
                "s3://${S3_BUCKET_NAME}/$(date '+%Y/%m/%d')/${TIMESTAMP}/" \
                --endpoint-url "${S3_ENDPOINT_URL:-}" \
                --quiet
            log_success "S3 upload completed"
        else
            log_warn "aws CLI not found — S3 upload skipped"
        fi
    fi

    # ─── Clean old backups ────────────────────────────────
    log_info "Cleaning backups older than ${RETENTION_DAYS} days..."
    find "${BACKUP_DB_DIR}" -type d -mtime "+${RETENTION_DAYS}" -exec rm -rf {} \; 2>/dev/null || true
    find "${BACKUP_LOGS_DIR}" -type f -mtime "+${RETENTION_DAYS}" -delete 2>/dev/null || true
    log_success "Old backups cleaned"

    # ─── Verify backup ────────────────────────────────────
    BACKUP_COUNT=$(find "${BACKUP_DIR}" -type f | wc -l)
    if [[ "$BACKUP_COUNT" -eq 0 ]]; then
        log_error "Backup verification FAILED — no files found in ${BACKUP_DIR}"
        return 1
    fi

    log_success "Backup verification passed: ${BACKUP_COUNT} files"
    log_success "═══════════════════════════════════════════"
    log_success "Backup complete: ${TIMESTAMP}"
    log_success "Location: ${BACKUP_DIR}"
    log_success "═══════════════════════════════════════════"

    # ─── Record backup metadata ───────────────────────────
    cat > "${BACKUP_DIR}/BACKUP_MANIFEST.json" << MANIFEST
{
  "timestamp": "${TIMESTAMP}",
  "site_name": "${SITE_NAME}",
  "backup_size": "${BACKUP_SIZE}",
  "file_count": "${BACKUP_COUNT}",
  "encrypted": $([ -n "$ENCRYPTION_KEY" ] && echo "true" || echo "false"),
  "s3_uploaded": $([ "$S3_ENABLED" == "true" ] && echo "true" || echo "false"),
  "retention_days": ${RETENTION_DAYS},
  "erpnext_version": "v15"
}
MANIFEST

    return 0
}

# ─── Cron-style scheduler ────────────────────────────────
# Runs backup daily at 02:00 AM
run_cron() {
    log_info "Backup service started"
    log_info "Schedule: Daily at 02:00 AM"
    log_info "Retention: ${RETENTION_DAYS} days"
    log_info "Encryption: $([ -n "$ENCRYPTION_KEY" ] && echo "Enabled" || echo "Disabled")"
    log_info "S3 Upload: $S3_ENABLED"

    # Run immediately on startup for verification
    log_info "Running initial backup on startup..."
    sleep 30  # Wait for other services to be ready
    perform_backup || log_warn "Initial backup failed — will retry at 02:00 AM"

    # Continuous cron loop
    while true; do
        CURRENT_HOUR=$(date +%H)
        CURRENT_MIN=$(date +%M)

        # Run at 02:00 AM
        if [[ "$CURRENT_HOUR" == "02" && "$CURRENT_MIN" == "00" ]]; then
            perform_backup || log_error "Scheduled backup failed"
            # Sleep 61 minutes to avoid running twice in same hour
            sleep 3660
        fi

        sleep 60
    done
}

# ─── Entry point ──────────────────────────────────────────
log_info "ERPNext School Backup Service"
log_info "Site: ${SITE_NAME}"
run_cron
