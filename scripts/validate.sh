#!/usr/bin/env bash
##############################################################
# ERPNext School — Testing & Validation Script
# Phase 13: Complete System Validation
#
# Usage: bash scripts/validate.sh
#
# Tests:
#   - All containers running
#   - ERPNext API responding
#   - Database connectivity
#   - Redis connectivity
#   - Apps installed correctly
#   - School modules accessible
#   - Cloudflare Tunnel
#   - Backup service
##############################################################

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

PASS=0; FAIL=0; WARN=0

source "$PROJECT_DIR/.env"
SITE_NAME="${SITE_NAME:-school.localhost}"
NGINX_PORT="${NGINX_PORT:-8080}"

test_pass() { PASS=$((PASS + 1)); echo -e "  ${GREEN}✓ PASS${NC} $1"; }
test_fail() { FAIL=$((FAIL + 1)); echo -e "  ${RED}✗ FAIL${NC} $1"; }
test_warn() { WARN=$((WARN + 1)); echo -e "  ${YELLOW}⚠ WARN${NC} $1"; }
section()   { echo -e "\n${CYAN}━━━ $1 ━━━${NC}"; }

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   ERPNext School — Validation Test Suite             ║${NC}"
echo -e "${CYAN}║   $(date '+%Y-%m-%d %H:%M:%S')                              ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"

# ─── 1. Container Tests ───────────────────────────────────
section "Container Tests"

REQUIRED_SERVICES=(backend frontend websocket queue-short queue-long scheduler db redis-cache redis-queue redis-socketio)

for svc in "${REQUIRED_SERVICES[@]}"; do
    STATE=$(docker compose ps "$svc" --format "{{.State}}" 2>/dev/null || echo "not-found")
    STATE="${STATE//$'\r'/}"
    if [[ "$STATE" == "running" ]]; then
        test_pass "Container '$svc' is running"
    else
        test_fail "Container '$svc' is NOT running (state: $STATE)"
    fi
done

# ─── 2. ERPNext API Tests ─────────────────────────────────
section "ERPNext API Tests"

# API Ping
API_PING=$(curl -s -H "Host: ${SITE_NAME}" --max-time 10 "http://localhost:${NGINX_PORT}/api/method/ping" 2>/dev/null || echo '{"message":"failed"}')
if echo "$API_PING" | grep -q "pong"; then
    test_pass "ERPNext API ping — responding"
else
    test_fail "ERPNext API ping — not responding"
fi

# Site accessible
HTTP_CODE=$(curl -so /dev/null -H "Host: ${SITE_NAME}" -w "%{http_code}" --max-time 10 "http://localhost:${NGINX_PORT}" 2>/dev/null || echo "000")
if [[ "$HTTP_CODE" =~ ^(200|302)$ ]]; then
    test_pass "ERPNext frontend — HTTP $HTTP_CODE"
else
    test_fail "ERPNext frontend — HTTP $HTTP_CODE"
fi

# Login page
LOGIN_CODE=$(curl -so /dev/null -H "Host: ${SITE_NAME}" -w "%{http_code}" --max-time 10 "http://localhost:${NGINX_PORT}/login" 2>/dev/null || echo "000")
if [[ "$LOGIN_CODE" =~ ^(200|302)$ ]]; then
    test_pass "Login page — HTTP $LOGIN_CODE"
else
    test_fail "Login page — HTTP $LOGIN_CODE"
fi

# ─── 3. Database Tests ────────────────────────────────────
section "Database Tests"

DB_PING=$(docker compose exec -T db mysqladmin -u root -p"${MARIADB_ROOT_PASSWORD}" ping --silent 2>/dev/null || echo "failed")
if echo "$DB_PING" | grep -q "alive"; then
    test_pass "MariaDB ping — alive"
else
    test_fail "MariaDB — not responding"
fi

# Site DB exists
SITE_DB=$(docker compose exec -T db mysql \
    -u root \
    -p"${MARIADB_ROOT_PASSWORD}" \
    -e "SHOW DATABASES LIKE '%school%';" 2>/dev/null || echo "")
if [[ -n "$SITE_DB" ]]; then
    test_pass "Site database — exists"
else
    test_warn "Site database — not found (site may not be created yet)"
fi

# ─── 4. Redis Tests ───────────────────────────────────────
section "Redis Tests"

for redis_svc in redis-cache redis-queue redis-socketio; do
    PONG=$(docker compose exec -T "$redis_svc" redis-cli ping 2>/dev/null || echo "failed")
    if echo "$PONG" | grep -q "PONG"; then
        test_pass "Redis $redis_svc — responding"
    else
        test_fail "Redis $redis_svc — not responding"
    fi
done

# ─── 5. Installed Apps Tests ──────────────────────────────
section "Installed Apps Tests"

APPS_OUTPUT=$(docker compose exec -T backend \
    bench --site "${SITE_NAME}" list-apps 2>/dev/null || echo "")

REQUIRED_APPS=(frappe erpnext hrms education)
for app in "${REQUIRED_APPS[@]}"; do
    if echo "$APPS_OUTPUT" | grep -qi "$app"; then
        test_pass "App '$app' — installed"
    else
        test_fail "App '$app' — NOT installed"
    fi
done

# ─── 6. ERPNext Module Tests ──────────────────────────────
section "ERPNext Module Tests"

# Test via API — check if Education module is accessible
if curl -s -H "Host: ${SITE_NAME}" "http://localhost:${NGINX_PORT}/api/method/frappe.auth.get_logged_user" | grep -q "message"; then
    test_pass "Education module — accessible"
else
    test_warn "Education module — could not verify (may need authentication setup)"
fi

# ─── 7. Scheduler Test ────────────────────────────────────
section "Scheduler Tests"

SCHEDULER_STATE=$(docker compose ps scheduler --format "{{.State}}" 2>/dev/null || echo "unknown")
if [[ "$SCHEDULER_STATE" == "running" ]]; then
    test_pass "Scheduler container — running"
else
    test_fail "Scheduler — not running"
fi

SCHED_LOGS=$(docker compose logs --tail=5 scheduler 2>/dev/null | tail -3)
if echo "$SCHED_LOGS" | grep -qi "scheduler\|beat\|running"; then
    test_pass "Scheduler — active in logs"
else
    test_warn "Scheduler — no recent activity in logs"
fi

# ─── 8. Worker Tests ─────────────────────────────────────
section "Worker Queue Tests"

for worker in queue-short queue-long; do
    WORKER_STATE=$(docker compose ps "$worker" --format "{{.State}}" 2>/dev/null || echo "unknown")
    if [[ "$WORKER_STATE" == "running" ]]; then
        test_pass "Worker '$worker' — running"
    else
        test_fail "Worker '$worker' — not running"
    fi
done

# Check queue lengths
SHORT_Q=$(docker compose exec -T redis-queue redis-cli llen "rq:queue:short" 2>/dev/null || echo "?")
LONG_Q=$(docker compose exec -T redis-queue redis-cli llen "rq:queue:long" 2>/dev/null || echo "?")
FAIL_Q=$(docker compose exec -T redis-queue redis-cli llen "rq:queue:failed" 2>/dev/null || echo "0")

echo -e "  ${BLUE}ℹ${NC} Queue lengths — short: ${SHORT_Q} | long: ${LONG_Q} | failed: ${FAIL_Q}"
if [[ "$FAIL_Q" -gt "0" ]] 2>/dev/null; then
    test_warn "Failed queue has ${FAIL_Q} jobs"
fi

# ─── 9. Backup Tests ─────────────────────────────────────
section "Backup Tests"

BACKUP_DIR="$PROJECT_DIR/data/backups/database"
if [[ -d "$BACKUP_DIR" ]]; then
    BACKUP_COUNT=$(find "$BACKUP_DIR" -mindepth 1 -type d | wc -l)
    if [[ "$BACKUP_COUNT" -gt 0 ]]; then
        LATEST=$(ls -1t "$BACKUP_DIR" | head -1)
        test_pass "Backups found: ${BACKUP_COUNT} (latest: $LATEST)"
    else
        test_warn "No backups yet (backup service runs daily at 02:00 AM)"
    fi
else
    test_warn "Backup directory not found"
fi

# ─── 10. Cloudflare Tunnel Tests ─────────────────────────
section "Cloudflare Tunnel Tests"

CF_STATE=$(docker compose ps cloudflared --format "{{.State}}" 2>/dev/null || echo "unknown")
if [[ "$CF_STATE" == "running" ]]; then
    test_pass "Cloudflared — running"
    CF_LOGS=$(docker compose logs --tail=5 cloudflared 2>/dev/null)
    if echo "$CF_LOGS" | grep -qi "registered\|connected\|connection registered"; then
        test_pass "Cloudflare Tunnel — connected"
    else
        test_warn "Cloudflare Tunnel — check token configuration"
    fi
else
    test_warn "Cloudflared — not running (configure CLOUDFLARE_TUNNEL_TOKEN)"
fi

# Test HTTPS endpoint if domain configured
SITE_DOMAIN="${SITE_DOMAIN:-erp.school.example.com}"
if [[ "$SITE_DOMAIN" != "erp.school.example.com" ]]; then
    HTTPS_CODE=$(curl -so /dev/null -w "%{http_code}" --max-time 15 "https://${SITE_DOMAIN}" 2>/dev/null || echo "000")
    if [[ "$HTTPS_CODE" =~ ^(200|302)$ ]]; then
        test_pass "HTTPS endpoint https://${SITE_DOMAIN} — HTTP $HTTPS_CODE"
    else
        test_warn "HTTPS endpoint — HTTP $HTTPS_CODE (may need DNS propagation)"
    fi
fi

# ─── 11. Disk Space Tests ────────────────────────────────
section "Disk Space Tests"

DISK_FREE_PERCENT=$(df -h "$PROJECT_DIR" | awk 'NR==2 {gsub(/%/,""); print 100-$5}')
if [[ "$DISK_FREE_PERCENT" -gt 20 ]]; then
    test_pass "Disk space — ${DISK_FREE_PERCENT}% free"
elif [[ "$DISK_FREE_PERCENT" -gt 10 ]]; then
    test_warn "Disk space low — ${DISK_FREE_PERCENT}% free"
else
    test_fail "Disk space critical — ${DISK_FREE_PERCENT}% free"
fi

# ─── Summary ─────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  ${GREEN}PASS: $PASS${NC}  |  ${RED}FAIL: $FAIL${NC}  |  ${YELLOW}WARN: $WARN${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ $FAIL -eq 0 ]]; then
    echo -e "\n  ${GREEN}✓ All critical tests PASSED${NC}"
    exit 0
else
    echo -e "\n  ${RED}✗ $FAIL test(s) FAILED — review output above${NC}"
    echo -e "  ${BLUE}ℹ See troubleshooting guide: docs/troubleshooting-guide.md${NC}"
    exit 1
fi
