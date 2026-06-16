#!/usr/bin/env bash
##############################################################
# ERPNext School — Directory Initialization Script
# Creates all required bind-mount directories before
# running docker compose up for the first time.
# Usage: bash scripts/init-dirs.sh
##############################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }

cd "$PROJECT_DIR"

log_info "Creating required data directories..."

DIRS=(
    "data/sites"
    "data/sites/assets"
    "data/logs"
    "data/mariadb"
    "data/redis-queue"
    "data/backups"
    "data/backups/database"
    "data/backups/files"
    "data/backups/logs"
)

for dir in "${DIRS[@]}"; do
    mkdir -p "$dir"
    log_success "Created: $dir"
done

# ─── Create .gitkeep files ────────────────────────────────
for dir in "${DIRS[@]}"; do
    touch "$dir/.gitkeep"
done

# ─── Set permissions ──────────────────────────────────────
# These directories need to be writable by Docker container user (frappe, uid=1000)
chmod -R 777 data/ 2>/dev/null || true

log_success "All directories created and permissions set"
echo ""
echo "Next steps:"
echo "  1. Edit .env and change all passwords/tokens"
echo "  2. Build image: bash scripts/build.sh"
echo "  3. Start services: docker compose up -d"
echo "  4. Install ERPNext: bash scripts/install.sh"
