#!/usr/bin/env bash
##############################################################
# ERPNext School — Complete Installation & Setup Script
# Phase 4: ERPNext Installation + School Configuration
# Usage: bash scripts/install.sh
# Run AFTER: docker compose up -d (all services healthy)
##############################################################

set -euo pipefail

# ─── Colors ───────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ─── Load environment ─────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$(dirname "$SCRIPT_DIR")/.env"

if [[ ! -f "$ENV_FILE" ]]; then
    echo -e "${RED}ERROR: .env file not found at $ENV_FILE${NC}"
    exit 1
fi

source "$ENV_FILE"

# ─── Functions ────────────────────────────────────────────
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
log_step() { echo -e "\n${CYAN}══════════════════════════════════════════${NC}"; echo -e "${CYAN}  STEP: $1${NC}"; echo -e "${CYAN}══════════════════════════════════════════${NC}"; }

# Execute command in backend container
bench_exec() {
    docker compose exec -T backend bash -c "$1"
}

# ─── STEP 0: Wait for services ────────────────────────────
log_step "0: Waiting for all services to be healthy"

MAX_WAIT=300
WAIT=0
while ! docker compose exec -T db mysqladmin ping -h"localhost" --silent 2>/dev/null; do
    if [[ $WAIT -ge $MAX_WAIT ]]; then
        log_error "Database did not become ready in ${MAX_WAIT}s"
    fi
    log_info "Waiting for MariaDB... (${WAIT}s)"
    sleep 5
    WAIT=$((WAIT + 5))
done
log_success "MariaDB is ready"

for redis_svc in redis-cache redis-queue redis-socketio; do
    WAIT=0
    while ! docker compose exec -T "$redis_svc" redis-cli ping 2>/dev/null | grep -q PONG; do
        if [[ $WAIT -ge 60 ]]; then
            log_error "$redis_svc did not become ready"
        fi
        sleep 3
        WAIT=$((WAIT + 3))
    done
    log_success "$redis_svc is ready"
done

# ─── STEP 1: Copy common site config ──────────────────────
log_step "1: Configuring common site settings"

docker compose cp config/common_site_config.json backend:/home/frappe/frappe-bench/sites/common_site_config.json
log_success "Common site config deployed"

# ─── STEP 2: Create new site ──────────────────────────────
log_step "2: Creating Frappe site: ${SITE_NAME}"

bench_exec "
    cd /home/frappe/frappe-bench && \
    bench new-site ${SITE_NAME} \
        --db-host db \
        --db-port 3306 \
        --db-root-username root \
        --db-root-password '${MARIADB_ROOT_PASSWORD}' \
        --admin-password '${ADMIN_PASSWORD}' \
        --no-mariadb-socket \
        --verbose
"
log_success "Site ${SITE_NAME} created"

# ─── STEP 3: Install ERPNext ──────────────────────────────
log_step "3: Installing ERPNext"

bench_exec "
    cd /home/frappe/frappe-bench && \
    bench --site ${SITE_NAME} install-app erpnext
"
log_success "ERPNext installed"

# ─── STEP 4: Install Payments ────────────────────────────
log_step "4: Installing Payments (dependency)"

bench_exec "
    cd /home/frappe/frappe-bench && \
    bench --site ${SITE_NAME} install-app payments
"
log_success "Payments installed"

# ─── STEP 5: Install HRMS ─────────────────────────────────
log_step "5: Installing Frappe HRMS"

bench_exec "
    cd /home/frappe/frappe-bench && \
    bench --site ${SITE_NAME} install-app hrms
"
log_success "HRMS installed"

# ─── STEP 6: Install Education ────────────────────────────
log_step "6: Installing Frappe Education"

bench_exec "
    cd /home/frappe/frappe-bench && \
    bench --site ${SITE_NAME} install-app education
"
log_success "Frappe Education installed"

# ─── STEP 7: Install LMS ──────────────────────────────────
log_step "7: Installing Frappe LMS"

bench_exec "
    cd /home/frappe/frappe-bench && \
    bench --site ${SITE_NAME} install-app lms
"
log_success "Frappe LMS installed"

# ─── STEP 8: Run migrations ───────────────────────────────
log_step "8: Running database migrations"

bench_exec "
    cd /home/frappe/frappe-bench && \
    bench --site ${SITE_NAME} migrate
"
log_success "Migrations completed"

# ─── STEP 9: Set site as default ──────────────────────────
log_step "9: Setting default site"

bench_exec "
    cd /home/frappe/frappe-bench && \
    bench use ${SITE_NAME}
"
log_success "Default site set to ${SITE_NAME}"

# ─── STEP 10: Configure scheduler ────────────────────────
log_step "10: Enabling scheduler"

bench_exec "
    cd /home/frappe/frappe-bench && \
    bench --site ${SITE_NAME} enable-scheduler
"
log_success "Scheduler enabled"

# ─── STEP 11: Clear caches ───────────────────────────────
log_step "11: Clearing caches"

bench_exec "
    cd /home/frappe/frappe-bench && \
    bench --site ${SITE_NAME} clear-cache && \
    bench --site ${SITE_NAME} clear-website-cache
"
log_success "Caches cleared"

# ─── STEP 12: School configuration ───────────────────────
log_step "12: Applying school configuration"

bench_exec "
    cd /home/frappe/frappe-bench && \
    bench --site ${SITE_NAME} execute school_setup.setup_school
" 2>/dev/null || log_warn "Custom school setup not found — configure manually via UI"

# ─── STEP 13: Create roles ────────────────────────────────
log_step "13: Setting up school roles and permissions"

bench_exec "
    cd /home/frappe/frappe-bench && python3 -c \"
import frappe
frappe.init(site='${SITE_NAME}')
frappe.connect()

# Create custom roles for school
roles = [
    'Principal',
    'Teacher',
    'Parent',
    'Student Portal User',
    'Receptionist',
    'Transport Manager',
    'Librarian',
    'Hostel Manager',
]

for role_name in roles:
    if not frappe.db.exists('Role', role_name):
        role = frappe.get_doc({
            'doctype': 'Role',
            'role_name': role_name,
            'desk_access': 1,
            'is_custom': 1,
        })
        role.insert(ignore_permissions=True)
        print(f'Created role: {role_name}')
    else:
        print(f'Role already exists: {role_name}')

frappe.db.commit()
frappe.destroy()
print('All school roles created successfully')
\"
"
log_success "School roles configured"

# ─── STEP 14: Configure system settings ──────────────────
log_step "14: Configuring system settings"

bench_exec "
    cd /home/frappe/frappe-bench && python3 -c \"
import frappe
frappe.init(site='${SITE_NAME}')
frappe.connect()
frappe.set_user('Administrator')

# System Settings
settings = frappe.get_doc('System Settings')
settings.country = 'India'
settings.language = 'en'
settings.time_zone = 'Asia/Kolkata'
settings.date_format = 'dd-mm-yyyy'
settings.time_format = 'HH:mm:ss'
settings.float_precision = 2
settings.currency_precision = 2
settings.minimum_password_score = 3
settings.password_reset_limit = 3
settings.session_expiry = '06:00:00'
settings.session_expiry_mobile = '720:00:00'
settings.enable_two_factor_auth = 0
settings.allow_login_using_mobile_number = 1
settings.allow_login_using_user_name = 1
settings.login_with_email_link = 1
settings.max_file_size = 52428800
settings.save(ignore_permissions=True)

frappe.db.commit()
frappe.destroy()
print('System settings configured')
\"
"
log_success "System settings configured"

# ─── STEP 15: Restart services ───────────────────────────
log_step "15: Restarting services"

docker compose restart backend websocket queue-short queue-long scheduler
log_success "Services restarted"

# ─── Done! ────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ERPNext School Installation Complete! 🎉           ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║                                                      ║${NC}"
echo -e "${GREEN}║  Site:    http://localhost:${NGINX_PORT}                    ║${NC}"
echo -e "${GREEN}║  User:    Administrator                              ║${NC}"
echo -e "${GREEN}║  Pass:    ${ADMIN_PASSWORD}                  ║${NC}"
echo -e "${GREEN}║                                                      ║${NC}"
echo -e "${GREEN}║  Next: Configure Cloudflare Tunnel                   ║${NC}"
echo -e "${GREEN}║  See: docs/cloudflare-setup.md                      ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
