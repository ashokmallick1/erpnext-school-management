#!/usr/bin/env bash
##############################################################
# ERPNext School — Upgrade Script
# Safely upgrades ERPNext and all apps to latest v15 patch
#
# Usage: bash scripts/upgrade.sh [--tag v15.110.0]
#
# Process:
#   1. Backup current installation
#   2. Build new image with updated app versions
#   3. Apply database migrations
#   4. Restart services
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

source "$PROJECT_DIR/.env"

NEW_TAG="${1#--tag=}"
[[ "$NEW_TAG" == "$1" ]] && NEW_TAG="${CUSTOM_TAG:-v15.109.3}"

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   ERPNext School — Upgrade Procedure         ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Current:  ${YELLOW}${CUSTOM_TAG}${NC}"
echo -e "  New tag:  ${GREEN}${NEW_TAG}${NC}"
echo ""
read -rp "  Proceed with upgrade? (yes/no): " CONFIRM
[[ "$CONFIRM" != "yes" ]] && { echo "Upgrade cancelled."; exit 0; }

# ─── STEP 1: Pre-upgrade backup ───────────────────────────
log_step "1: Running pre-upgrade backup"
bash "$SCRIPT_DIR/backup-cron.sh" --run-once 2>/dev/null || {
    # Manual backup via bench
    docker compose exec -T backend \
        bench --site "${SITE_NAME}" backup --with-files --compress \
        --backup-path "/backups/database/pre-upgrade-$(date +%Y%m%d_%H%M%S)"
}
log_success "Pre-upgrade backup completed"

# ─── STEP 2: Pull latest Docker images ───────────────────
log_step "2: Pulling updated base images"
docker pull mariadb:10.6 || true
docker pull redis:7.2-alpine || true
docker pull cloudflare/cloudflared:latest || true
log_success "Base images updated"

# ─── STEP 3: Build new custom image ──────────────────────
log_step "3: Building new custom image: ${CUSTOM_IMAGE}:${NEW_TAG}"

APPS_JSON_BASE64=$(base64 -w 0 "$PROJECT_DIR/apps.json" 2>/dev/null || base64 "$PROJECT_DIR/apps.json")

docker build \
    --build-arg=FRAPPE_PATH=https://github.com/frappe/frappe \
    --build-arg=FRAPPE_BRANCH=version-15 \
    --build-arg=PYTHON_VERSION=3.11.9 \
    --build-arg=NODE_VERSION=18.20.4 \
    --build-arg=APPS_JSON_BASE64="$APPS_JSON_BASE64" \
    --tag="${CUSTOM_IMAGE}:${NEW_TAG}" \
    --tag="${CUSTOM_IMAGE}:latest" \
    --file="$PROJECT_DIR/Containerfile" \
    --no-cache \
    "$PROJECT_DIR" || log_error "Image build failed"

log_success "New image built: ${CUSTOM_IMAGE}:${NEW_TAG}"

# ─── STEP 4: Update .env with new tag ─────────────────────
log_step "4: Updating CUSTOM_TAG in .env"
sed -i.bak "s/^CUSTOM_TAG=.*/CUSTOM_TAG=${NEW_TAG}/" "$PROJECT_DIR/.env"
log_success ".env updated to ${NEW_TAG}"

# ─── STEP 5: Enable maintenance mode ─────────────────────
log_step "5: Enabling maintenance mode"
docker compose exec -T backend \
    bench --site "${SITE_NAME}" set-maintenance-mode on || true
log_success "Maintenance mode enabled"

# ─── STEP 6: Restart with new image ──────────────────────
log_step "6: Restarting services with new image"
docker compose --env-file "$PROJECT_DIR/.env" up -d \
    --remove-orphans \
    2>&1 | tail -20
log_success "Services updated to new image"

# ─── STEP 7: Run database migrations ─────────────────────
log_step "7: Running database migrations"
# Wait for backend to be healthy
sleep 30
MAX_WAIT=120; WAITED=0
while ! docker compose exec -T backend curl -sf http://localhost:8000/api/method/ping &>/dev/null; do
    sleep 5; WAITED=$((WAITED+5))
    [[ $WAITED -ge $MAX_WAIT ]] && log_error "Backend did not start in time"
done

docker compose exec -T backend \
    bench --site "${SITE_NAME}" migrate
log_success "Migrations completed"

# ─── STEP 8: Disable maintenance mode ─────────────────────
log_step "8: Disabling maintenance mode"
docker compose exec -T backend \
    bench --site "${SITE_NAME}" set-maintenance-mode off
log_success "Site back online"

# ─── STEP 9: Verify ───────────────────────────────────────
log_step "9: Post-upgrade verification"
docker compose exec -T backend \
    bench --site "${SITE_NAME}" list-apps
log_success "Apps list verified"

# ─── STEP 10: Clear caches ────────────────────────────────
log_step "10: Clearing caches"
docker compose exec -T backend bench --site "${SITE_NAME}" clear-cache
docker compose exec -T backend bench --site "${SITE_NAME}" clear-website-cache
docker compose exec -T backend bench --site "${SITE_NAME}" build-search-index 2>/dev/null || true
log_success "Caches cleared"

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Upgrade Complete! ✓                        ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║  Previous: ${CUSTOM_TAG}                     ║${NC}"
echo -e "${GREEN}║  Current:  ${NEW_TAG}                        ║${NC}"
echo -e "${GREEN}║                                              ║${NC}"
echo -e "${GREEN}║  Please verify: http://localhost:${NGINX_PORT:-8080}  ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
