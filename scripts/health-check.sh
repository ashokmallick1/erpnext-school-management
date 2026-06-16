#!/usr/bin/env bash
##############################################################
# ERPNext School — Health Check Script
# Comprehensive monitoring of all system components
# Usage: bash scripts/health-check.sh [--watch] [--json]
##############################################################

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

source "$PROJECT_DIR/.env" 2>/dev/null || true

WATCH_MODE=false
JSON_MODE=false
NGINX_PORT="${NGINX_PORT:-8080}"

for arg in "$@"; do
    case $arg in
        --watch) WATCH_MODE=true ;;
        --json)  JSON_MODE=true ;;
    esac
done

ok()    { echo -e "  ${GREEN}✓${NC} $1"; }
fail()  { echo -e "  ${RED}✗${NC} $1"; OVERALL_STATUS="DEGRADED"; }
warn()  { echo -e "  ${YELLOW}⚠${NC} $1"; }
info()  { echo -e "  ${BLUE}ℹ${NC} $1"; }

run_check() {
    OVERALL_STATUS="HEALTHY"

    echo ""
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║   ERPNext School — System Health Check               ║${NC}"
    echo -e "${BOLD}${CYAN}║   $(date '+%Y-%m-%d %H:%M:%S')                              ║${NC}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""

    # ─── Container status ─────────────────────────────────
    echo -e "${BOLD}Container Status:${NC}"
    SERVICES=(backend frontend websocket queue-short queue-long scheduler db redis-cache redis-queue redis-socketio cloudflared backup)

    for svc in "${SERVICES[@]}"; do
        STATUS=$(docker compose ps --format json "$svc" 2>/dev/null | \
            python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('State','unknown'))" 2>/dev/null || \
            echo "not-found")
        case "$STATUS" in
            running)  ok "$svc — running" ;;
            healthy)  ok "$svc — healthy" ;;
            starting) warn "$svc — starting" ;;
            *)        fail "$svc — ${STATUS}" ;;
        esac
    done

    # ─── ERPNext API health ───────────────────────────────
    echo ""
    echo -e "${BOLD}ERPNext API Health:${NC}"

    PING_RESP=$(curl -sf --max-time 5 \
        "http://localhost:${NGINX_PORT}/api/method/ping" 2>/dev/null || echo "failed")

    if echo "$PING_RESP" | grep -q "pong"; then
        ok "API ping — responsive"
    else
        fail "API ping — not responding (got: ${PING_RESP:0:50})"
    fi

    # Check login endpoint
    LOGIN_STATUS=$(curl -so /dev/null -w "%{http_code}" --max-time 10 \
        "http://localhost:${NGINX_PORT}/api/method/frappe.auth.get_logged_user" 2>/dev/null || echo "000")
    if [[ "$LOGIN_STATUS" =~ ^(200|403|401)$ ]]; then
        ok "Login endpoint — responsive (HTTP $LOGIN_STATUS)"
    else
        fail "Login endpoint — HTTP $LOGIN_STATUS"
    fi

    # ─── Database health ──────────────────────────────────
    echo ""
    echo -e "${BOLD}Database Health:${NC}"

    DB_STATUS=$(docker compose exec -T db \
        mysqladmin -u root -p"${MARIADB_ROOT_PASSWORD}" status 2>/dev/null | head -1 || echo "failed")

    if echo "$DB_STATUS" | grep -q "Uptime"; then
        ok "MariaDB — running"
        DB_UPTIME=$(echo "$DB_STATUS" | grep -oP "Uptime: \K[0-9]+")
        DB_QUERIES=$(echo "$DB_STATUS" | grep -oP "Queries per second avg: \K[0-9.]+")
        info "  Uptime: ${DB_UPTIME}s | Queries/sec avg: ${DB_QUERIES}"
    else
        fail "MariaDB — not responding"
    fi

    # Check site database
    SITE_DB=$(docker compose exec -T backend \
        bench --site "${SITE_NAME:-school.localhost}" frappe.db.get_value \
        "System Settings" "None" "language" 2>/dev/null || echo "failed")
    if [[ "$SITE_DB" != "failed" ]]; then
        ok "Site database — accessible"
    else
        warn "Site database — check manually"
    fi

    # ─── Redis health ─────────────────────────────────────
    echo ""
    echo -e "${BOLD}Redis Health:${NC}"

    for redis_svc in redis-cache redis-queue redis-socketio; do
        REDIS_STATUS=$(docker compose exec -T "$redis_svc" redis-cli ping 2>/dev/null || echo "failed")
        if echo "$REDIS_STATUS" | grep -q "PONG"; then
            REDIS_MEM=$(docker compose exec -T "$redis_svc" \
                redis-cli info memory 2>/dev/null | \
                grep "used_memory_human:" | cut -d: -f2 | tr -d '[:space:]' || echo "?")
            ok "$redis_svc — running (memory: ${REDIS_MEM})"
        else
            fail "$redis_svc — not responding"
        fi
    done

    # ─── Disk usage ───────────────────────────────────────
    echo ""
    echo -e "${BOLD}Disk Usage:${NC}"

    for dir in data/sites data/mariadb data/backups; do
        FULL_PATH="$PROJECT_DIR/$dir"
        if [[ -d "$FULL_PATH" ]]; then
            USAGE=$(du -sh "$FULL_PATH" 2>/dev/null | cut -f1)
            DISK_FREE=$(df -h "$FULL_PATH" 2>/dev/null | tail -1 | awk '{print $4}')
            info "$dir — Used: $USAGE | Free: $DISK_FREE"
        fi
    done

    # ─── Backup status ────────────────────────────────────
    echo ""
    echo -e "${BOLD}Backup Status:${NC}"

    BACKUP_DIR="$PROJECT_DIR/data/backups/database"
    if [[ -d "$BACKUP_DIR" ]]; then
        LATEST_BACKUP=$(ls -1t "$BACKUP_DIR" | head -1)
        if [[ -n "$LATEST_BACKUP" ]]; then
            BACKUP_AGE=$(python3 -c "
import os, datetime
d = '$BACKUP_DIR/$LATEST_BACKUP'
mtime = os.path.getmtime(d)
age = datetime.datetime.now() - datetime.datetime.fromtimestamp(mtime)
print(f'{age.days}d {age.seconds//3600}h ago')
" 2>/dev/null || echo "unknown")
            ok "Latest backup: $LATEST_BACKUP ($BACKUP_AGE)"
        else
            warn "No backups found"
        fi
    else
        warn "Backup directory not found"
    fi

    # ─── Cloudflare Tunnel ────────────────────────────────
    echo ""
    echo -e "${BOLD}Cloudflare Tunnel:${NC}"

    CF_STATUS=$(docker compose ps --format "{{.Status}}" cloudflared 2>/dev/null || echo "unknown")
    if echo "$CF_STATUS" | grep -qi "running\|up"; then
        ok "cloudflared — running"
        CF_LOGS=$(docker compose logs --tail=3 cloudflared 2>/dev/null | tail -3)
        if echo "$CF_LOGS" | grep -qi "connection registered\|registered tunnel\|Connected to"; then
            ok "Tunnel connection — established"
        else
            warn "Tunnel connection — check logs: docker compose logs cloudflared"
        fi
    else
        fail "cloudflared — not running"
    fi

    # ─── Workers health ───────────────────────────────────
    echo ""
    echo -e "${BOLD}Worker Queues:${NC}"

    QUEUE_LENGTH=$(docker compose exec -T redis-queue \
        redis-cli llen rq:queue:default 2>/dev/null || echo "?")
    info "Default queue length: $QUEUE_LENGTH jobs"

    SHORT_QUEUE=$(docker compose exec -T redis-queue \
        redis-cli llen rq:queue:short 2>/dev/null || echo "?")
    info "Short queue length: $SHORT_QUEUE jobs"

    LONG_QUEUE=$(docker compose exec -T redis-queue \
        redis-cli llen rq:queue:long 2>/dev/null || echo "?")
    info "Long queue length: $LONG_QUEUE jobs"

    # ─── Overall status ───────────────────────────────────
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if [[ "$OVERALL_STATUS" == "HEALTHY" ]]; then
        echo -e "${GREEN}  ✓ Overall Status: HEALTHY${NC}"
    else
        echo -e "${RED}  ✗ Overall Status: DEGRADED — Check failures above${NC}"
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# ─── Main ─────────────────────────────────────────────────
cd "$PROJECT_DIR"

if [[ "$WATCH_MODE" == "true" ]]; then
    echo "Watch mode — refreshing every 30 seconds (Ctrl+C to stop)"
    while true; do
        clear
        run_check
        sleep 30
    done
else
    run_check
fi
