#!/usr/bin/env bash
##############################################################
# ERPNext School — Complete Deploy Script
# Orchestrates the full deployment in correct sequence
#
# Usage: bash scripts/deploy.sh [--skip-build]
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
log_step()    { echo -e "\n${CYAN}══════════════════════════════════════════${NC}"; echo -e "${CYAN}  $1${NC}"; echo -e "${CYAN}══════════════════════════════════════════${NC}"; }

SKIP_BUILD=false
for arg in "$@"; do
    [[ "$arg" == "--skip-build" ]] && SKIP_BUILD=true
done

cd "$PROJECT_DIR"
source "$PROJECT_DIR/.env"

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  ERPNext School — Full Deployment                    ║${NC}"
echo -e "${CYAN}║  ERPNext v15 + Education + LMS + HRMS                ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

# ─── PRE-FLIGHT CHECKS ───────────────────────────────────
log_step "Pre-flight Checks"

command -v docker &>/dev/null || log_error "Docker not installed"
docker info &>/dev/null || log_error "Docker daemon not running"
command -v docker &>/dev/null && docker compose version &>/dev/null || log_error "Docker Compose not available"

log_info "Docker: $(docker --version)"
log_info "Docker Compose: $(docker compose version)"

# Check .env is configured
if grep -q "change-me\|your-.*-here\|CHANGEME" "$PROJECT_DIR/.env" 2>/dev/null; then
    log_warn "⚠ .env contains placeholder values — update before production use"
fi
log_success "Pre-flight checks passed"

# ─── STEP 1: Create directories ─────────────────────────
log_step "Step 1: Initializing directories"
bash "$SCRIPT_DIR/init-dirs.sh"
log_success "Directories created"

# ─── STEP 2: Build image ──────────────────────────────────
if [[ "$SKIP_BUILD" == "false" ]]; then
    log_step "Step 2: Building custom Docker image"
    log_warn "This takes 15-30 minutes on first run"
    bash "$SCRIPT_DIR/build.sh"
else
    log_warn "Step 2: Skipping build (--skip-build flag)"
    IMAGE_EXISTS=$(docker image inspect "${CUSTOM_IMAGE:-school-erpnext}:${CUSTOM_TAG:-v15.109.3}" 2>/dev/null && echo "yes" || echo "no")
    [[ "$IMAGE_EXISTS" == "no" ]] && log_error "Image not found and --skip-build specified"
fi

# ─── STEP 3: Start infrastructure ─────────────────────────
log_step "Step 3: Starting infrastructure (DB + Redis)"
docker compose up -d db redis-cache redis-queue redis-socketio

log_info "Waiting for MariaDB to be ready..."
WAIT=0
while ! docker compose exec -T db mysqladmin ping -h"localhost" --silent 2>/dev/null; do
    [[ $WAIT -ge 120 ]] && log_error "MariaDB not ready after 120s"
    sleep 5; WAIT=$((WAIT+5))
    echo -n "."
done
echo ""
log_success "MariaDB is ready"

log_info "Waiting for Redis..."
sleep 5
for rs in redis-cache redis-queue redis-socketio; do
    docker compose exec -T "$rs" redis-cli ping | grep -q PONG && log_success "$rs ready" || log_warn "$rs not ready"
done

# ─── STEP 4: Run configurator ─────────────────────────────
log_step "Step 4: Running configurator"
docker compose up configurator
log_success "Configuration written"

# ─── STEP 5: Start all services ───────────────────────────
log_step "Step 5: Starting all services"
docker compose up -d
log_info "Waiting for backend..."
WAIT=0
while ! curl -sf --max-time 5 "http://localhost:8000/api/method/ping" &>/dev/null; do
    [[ $WAIT -ge 180 ]] && log_error "Backend not ready after 180s"
    sleep 5; WAIT=$((WAIT+5))
    echo -n "."
done
echo ""
log_success "Backend is ready"

# ─── STEP 6: Install ERPNext ──────────────────────────────
log_step "Step 6: Installing ERPNext & School Apps"
bash "$SCRIPT_DIR/install.sh"

# ─── STEP 7: Show status ──────────────────────────────────
log_step "Final Status"
docker compose ps

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Deployment Complete! 🎉                            ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║                                                      ║${NC}"
echo -e "${GREEN}║  Local URL: http://localhost:${NGINX_PORT:-8080}             ║${NC}"
echo -e "${GREEN}║  Username:  Administrator                            ║${NC}"
echo -e "${GREEN}║  Password:  (set in .env → ADMIN_PASSWORD)           ║${NC}"
echo -e "${GREEN}║                                                      ║${NC}"
echo -e "${GREEN}║  Next: Set up Cloudflare Tunnel                      ║${NC}"
echo -e "${GREEN}║    bash scripts/setup-cloudflare.sh                  ║${NC}"
echo -e "${GREEN}║                                                      ║${NC}"
echo -e "${GREEN}║  Monitor: bash scripts/health-check.sh               ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
