#!/usr/bin/env bash
##############################################################
# ERPNext School — Restore Script
# Restores from encrypted backup created by backup-cron.sh
#
# Usage:
#   bash scripts/restore.sh [backup-timestamp]
#   bash scripts/restore.sh 20260616_020000
#   bash scripts/restore.sh --list         (list available backups)
##############################################################

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
log_step()    { echo -e "\n${CYAN}══ $1 ══${NC}"; }

# ─── Load environment ─────────────────────────────────────
source "$PROJECT_DIR/.env"

BACKUP_BASE="$PROJECT_DIR/data/backups/database"
SITE_NAME="${SITE_NAME:-school.localhost}"
ENCRYPTION_KEY="${BACKUP_ENCRYPTION_KEY:-}"

# ─── Handle arguments ─────────────────────────────────────
if [[ "${1:-}" == "--list" ]]; then
    echo -e "${CYAN}Available backups:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    ls -1t "$BACKUP_BASE" 2>/dev/null | head -20 | while read -r dir; do
        if [[ -d "$BACKUP_BASE/$dir" ]]; then
            SIZE=$(du -sh "$BACKUP_BASE/$dir" | cut -f1)
            MANIFEST="$BACKUP_BASE/$dir/BACKUP_MANIFEST.json"
            if [[ -f "$MANIFEST" ]]; then
                echo -e "  ${GREEN}$dir${NC} (${SIZE}) ← manifest available"
            else
                echo -e "  ${YELLOW}$dir${NC} (${SIZE})"
            fi
        fi
    done
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Usage: bash scripts/restore.sh <timestamp>"
    echo "       bash scripts/restore.sh 20260616_020000"
    exit 0
fi

BACKUP_TIMESTAMP="${1:-}"
if [[ -z "$BACKUP_TIMESTAMP" ]]; then
    # Use most recent backup
    BACKUP_TIMESTAMP=$(ls -1t "$BACKUP_BASE" | head -1)
    log_warn "No timestamp specified — using most recent: $BACKUP_TIMESTAMP"
fi

BACKUP_DIR="${BACKUP_BASE}/${BACKUP_TIMESTAMP}"

if [[ ! -d "$BACKUP_DIR" ]]; then
    log_error "Backup directory not found: $BACKUP_DIR"
fi

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   ERPNext School — Restore Procedure         ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Backup:    ${GREEN}$BACKUP_TIMESTAMP${NC}"
echo -e "  Site:      ${GREEN}$SITE_NAME${NC}"
echo -e "  Directory: ${GREEN}$BACKUP_DIR${NC}"
echo ""
echo -e "${RED}  ⚠ WARNING: This will OVERWRITE the current site!${NC}"
echo -e "${RED}  All current data will be replaced with backup data.${NC}"
echo ""
read -rp "  Type 'RESTORE' to confirm: " CONFIRM

if [[ "$CONFIRM" != "RESTORE" ]]; then
    echo "Restore cancelled."
    exit 0
fi

# ─── STEP 1: Check backup files exist ─────────────────────
log_step "Checking backup files"

# Find files (encrypted or plain)
DB_FILE=$(find "$BACKUP_DIR" -name "*.sql.gz.enc" -o -name "*.sql.gz" 2>/dev/null | head -1)
FILES_BACKUP=$(find "$BACKUP_DIR" -name "*-files.tar.gz.enc" -o -name "*-files.tar.gz" 2>/dev/null | head -1)

if [[ -z "$DB_FILE" ]]; then
    log_error "No database backup file found in $BACKUP_DIR"
fi

log_success "Database backup: $(basename "$DB_FILE")"
[[ -n "$FILES_BACKUP" ]] && log_success "Files backup: $(basename "$FILES_BACKUP")"

# ─── STEP 2: Decrypt if encrypted ─────────────────────────
log_step "Decrypting backups"

WORK_DIR="/tmp/erpnext-restore-${BACKUP_TIMESTAMP}"
mkdir -p "$WORK_DIR"

if [[ "$DB_FILE" == *.enc ]]; then
    if [[ -z "$ENCRYPTION_KEY" ]]; then
        log_error "Backup is encrypted but BACKUP_ENCRYPTION_KEY is not set"
    fi
    DECRYPTED_DB="${WORK_DIR}/database.sql.gz"
    log_info "Decrypting database backup..."
    openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 \
        -pass "pass:${ENCRYPTION_KEY}" \
        -in "$DB_FILE" \
        -out "$DECRYPTED_DB"
    log_success "Database decrypted"
else
    DECRYPTED_DB="$DB_FILE"
fi

if [[ -n "$FILES_BACKUP" && "$FILES_BACKUP" == *.enc ]]; then
    DECRYPTED_FILES="${WORK_DIR}/files.tar.gz"
    log_info "Decrypting files backup..."
    openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 \
        -pass "pass:${ENCRYPTION_KEY}" \
        -in "$FILES_BACKUP" \
        -out "$DECRYPTED_FILES"
    log_success "Files decrypted"
else
    DECRYPTED_FILES="$FILES_BACKUP"
fi

# ─── STEP 3: Put site in maintenance mode ─────────────────
log_step "Enabling maintenance mode"
docker compose exec -T backend \
    bench --site "${SITE_NAME}" set-maintenance-mode on || true
log_success "Maintenance mode enabled"

# ─── STEP 4: Restore database ─────────────────────────────
log_step "Restoring database"
docker compose exec -T backend \
    bench --site "${SITE_NAME}" restore "$DECRYPTED_DB"
log_success "Database restored"

# ─── STEP 5: Restore files ────────────────────────────────
if [[ -n "$DECRYPTED_FILES" && -f "$DECRYPTED_FILES" ]]; then
    log_step "Restoring files"
    docker compose exec -T backend \
        bench --site "${SITE_NAME}" restore "$DECRYPTED_DB" \
        --with-public-files "$DECRYPTED_FILES" \
        --with-private-files "$DECRYPTED_FILES" || true
    log_success "Files restored"
fi

# ─── STEP 6: Run migrations ───────────────────────────────
log_step "Running database migrations"
docker compose exec -T backend \
    bench --site "${SITE_NAME}" migrate
log_success "Migrations completed"

# ─── STEP 7: Clear caches ─────────────────────────────────
log_step "Clearing caches"
docker compose exec -T backend \
    bench --site "${SITE_NAME}" clear-cache
docker compose exec -T backend \
    bench --site "${SITE_NAME}" clear-website-cache
log_success "Caches cleared"

# ─── STEP 8: Disable maintenance mode ─────────────────────
log_step "Disabling maintenance mode"
docker compose exec -T backend \
    bench --site "${SITE_NAME}" set-maintenance-mode off
log_success "Maintenance mode disabled"

# ─── STEP 9: Restart services ─────────────────────────────
log_step "Restarting services"
docker compose restart backend websocket queue-short queue-long scheduler
log_success "Services restarted"

# ─── Cleanup ──────────────────────────────────────────────
rm -rf "$WORK_DIR"

# ─── Success ──────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Restore Complete! ✓                        ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║                                              ║${NC}"
echo -e "${GREEN}║  Restored from: $BACKUP_TIMESTAMP           ║${NC}"
echo -e "${GREEN}║  Site: $SITE_NAME                           ║${NC}"
echo -e "${GREEN}║                                              ║${NC}"
echo -e "${GREEN}║  Please verify the site is working:         ║${NC}"
echo -e "${GREEN}║  http://localhost:${NGINX_PORT:-8080}                  ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
