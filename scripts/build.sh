#!/usr/bin/env bash
##############################################################
# ERPNext School — Docker Image Build Script
# Builds custom image with all school apps baked in
# Usage: bash scripts/build.sh [--push] [--tag custom-tag]
#
# Apps included:
#   - ERPNext v15 (branch: version-15)
#   - Payments (branch: version-15)
#   - HRMS (branch: version-15)
#   - Frappe Education (branch: version-15)
#   - Frappe LMS (branch: version-15)
##############################################################

set -euo pipefail

# ─── Colors ───────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
log_step()    { echo -e "\n${CYAN}══ $1 ══${NC}"; }

# ─── Parse arguments ──────────────────────────────────────
PUSH=false
CUSTOM_TAG=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --push) PUSH=true; shift ;;
        --tag)  CUSTOM_TAG="$2"; shift 2 ;;
        *) log_warn "Unknown argument: $1"; shift ;;
    esac
done

# ─── Load .env ────────────────────────────────────────────
ENV_FILE="$PROJECT_DIR/.env"
[[ -f "$ENV_FILE" ]] || log_error ".env not found at $ENV_FILE"
source "$ENV_FILE"

IMAGE_NAME="${CUSTOM_IMAGE:-school-erpnext}"
IMAGE_TAG="${CUSTOM_TAG:-${CUSTOM_TAG_ARG:-v15.109.3}}"
FULL_IMAGE="$IMAGE_NAME:$IMAGE_TAG"

log_step "Building ERPNext School Image: $FULL_IMAGE"
log_info "Apps: ERPNext + Payments + HRMS + Education + LMS"
log_info "Frappe branch: version-15"

# ─── Check prerequisites ──────────────────────────────────
log_step "Checking prerequisites"

command -v docker &>/dev/null || log_error "Docker not found"
command -v base64 &>/dev/null || log_error "base64 not found"

APPS_JSON="$PROJECT_DIR/apps.json"
[[ -f "$APPS_JSON" ]] || log_error "apps.json not found at $APPS_JSON"
log_success "All prerequisites met"

# ─── Encode apps.json ─────────────────────────────────────
log_step "Encoding apps.json"

APPS_JSON_BASE64=$(base64 -w 0 "$APPS_JSON" 2>/dev/null || base64 "$APPS_JSON")
log_success "apps.json encoded ($(echo "$APPS_JSON_BASE64" | wc -c) bytes base64)"

# ─── Show apps to be installed ───────────────────────────
log_info "Apps to be installed:"
python3 -c "
import json, sys
with open('$APPS_JSON') as f:
    apps = json.load(f)
for i, app in enumerate(apps, 1):
    name = app['url'].split('/')[-1]
    branch = app.get('branch', 'main')
    print(f'  {i}. {name} [{branch}]')
" 2>/dev/null || cat "$APPS_JSON"

# ─── Build image ──────────────────────────────────────────
log_step "Building Docker image (this takes 15-30 minutes)"
log_info "Image: $FULL_IMAGE"
log_info "Containerfile: $PROJECT_DIR/Containerfile"

START_TIME=$(date +%s)

docker build \
    --build-arg=FRAPPE_PATH=https://github.com/frappe/frappe \
    --build-arg=FRAPPE_BRANCH=version-15 \
    --build-arg=PYTHON_VERSION=3.11.9 \
    --build-arg=NODE_VERSION=18.20.4 \
    --build-arg=APPS_JSON_BASE64="$APPS_JSON_BASE64" \
    --tag="$FULL_IMAGE" \
    --tag="$IMAGE_NAME:latest" \
    --file="$PROJECT_DIR/Containerfile" \
    --progress=plain \
    "$PROJECT_DIR"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

log_success "Image built in ${MINUTES}m ${SECONDS}s"

# ─── Verify image ─────────────────────────────────────────
log_step "Verifying image"

docker image inspect "$FULL_IMAGE" &>/dev/null || log_error "Image not found after build"
IMAGE_SIZE=$(docker image inspect "$FULL_IMAGE" --format='{{.Size}}' | numfmt --to=iec 2>/dev/null || echo "unknown")
log_success "Image: $FULL_IMAGE (size: $IMAGE_SIZE)"

# ─── Verify apps installed ───────────────────────────────
log_step "Verifying installed apps"
docker run --rm "$FULL_IMAGE" bash -c \
    "ls /home/frappe/frappe-bench/apps/" 2>/dev/null && \
    log_success "Apps directory verified" || \
    log_warn "Could not verify apps directory"

# ─── Optional push ────────────────────────────────────────
if [[ "$PUSH" == "true" ]]; then
    log_step "Pushing image to registry"
    docker push "$FULL_IMAGE"
    docker push "$IMAGE_NAME:latest"
    log_success "Image pushed"
fi

# ─── Summary ─────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Image Build Complete! ✓                     ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║  Image: $FULL_IMAGE                          ║${NC}"
echo -e "${GREEN}║                                              ║${NC}"
echo -e "${GREEN}║  Next: Run deployment                        ║${NC}"
echo -e "${GREEN}║    bash scripts/deploy.sh                    ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
