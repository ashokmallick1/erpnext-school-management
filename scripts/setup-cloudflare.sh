#!/usr/bin/env bash
##############################################################
# ERPNext School — Cloudflare Tunnel Setup Script
# Automates tunnel creation and domain configuration
#
# Usage: bash scripts/setup-cloudflare.sh
#
# Prerequisites:
#   - Cloudflare account with a domain
#   - ERPNext running on localhost:8080
#   - cloudflared CLI installed (or use Docker)
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

SITE_NAME="${SITE_NAME:-school.localhost}"
SITE_DOMAIN="${SITE_DOMAIN:-erp.school.example.com}"
NGINX_PORT="${NGINX_PORT:-8080}"

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   ERPNext School — Cloudflare Tunnel Setup               ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

cat << 'INSTRUCTIONS'
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OVERVIEW: Cloudflare Tunnel provides secure HTTPS access to
your ERPNext installation without:
  ✓ Exposing any ports publicly
  ✓ Port forwarding on your router
  ✓ Public IP address
  ✓ SSL certificate management

ARCHITECTURE:
  Internet → Cloudflare Edge → Tunnel → Docker → ERPNext
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
INSTRUCTIONS

log_step "STEP 1: Create Cloudflare Account and Add Domain"
echo ""
echo "  1. Go to https://dash.cloudflare.com/sign-up"
echo "  2. Add your domain to Cloudflare (change nameservers)"
echo "  3. Wait for DNS propagation (can take up to 24h)"
echo "  4. Confirm domain is 'Active' in Cloudflare dashboard"
echo ""
read -rp "  Press ENTER when your domain is active in Cloudflare... "

log_step "STEP 2: Enable Cloudflare Zero Trust"
echo ""
echo "  1. Go to: https://one.dash.cloudflare.com/"
echo "  2. Click 'Get started' or log in"
echo "  3. Set up your team name (e.g., 'yourschool')"
echo "     → This creates: yourschool.cloudflareaccess.com"
echo ""
read -rp "  Press ENTER when Zero Trust is enabled... "

log_step "STEP 3: Create the Tunnel"
echo ""
echo "  OPTION A — Dashboard (Recommended for beginners):"
echo "  1. Go to: Zero Trust → Networks → Tunnels"
echo "  2. Click 'Create a tunnel'"
echo "  3. Choose 'Cloudflared'"
echo "  4. Name it: 'erpnext-school'"
echo "  5. Choose 'Docker' as the environment"
echo "  6. Copy the tunnel token (starts with 'eyJ...')"
echo ""
echo "  OPTION B — CLI (Advanced):"
echo "    Install cloudflared: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/"
echo "    cloudflared tunnel login"
echo "    cloudflared tunnel create erpnext-school"
echo "    cloudflared tunnel token erpnext-school"
echo ""
read -rp "  Paste your tunnel token here: " TUNNEL_TOKEN

# ─── Update .env with token ──────────────────────────────
log_step "Saving tunnel token"
sed -i.bak "s|^CLOUDFLARE_TUNNEL_TOKEN=.*|CLOUDFLARE_TUNNEL_TOKEN=${TUNNEL_TOKEN}|" "$PROJECT_DIR/.env"
log_success "Token saved to .env"

log_step "STEP 4: Configure Public Hostname in Tunnel"
echo ""
echo "  In the tunnel configuration:"
echo ""
echo "  Public hostname:"
echo "    Subdomain: erp"
echo "    Domain:    school.example.com  ← your domain"
echo "    Path:      (leave empty)"
echo ""
echo "  Service:"
echo "    Type: HTTP"
echo "    URL:  frontend:8080"
echo ""
echo "  Additional settings (click 'Additional application settings'):"
echo "    HTTP Host Header: ${SITE_DOMAIN}"
echo ""
echo "  Click 'Save tunnel'"
echo ""
read -rp "  Press ENTER when the public hostname is configured... "

log_step "STEP 5: Register domain with ERPNext site"
echo ""
log_info "Adding domain ${SITE_DOMAIN} to ERPNext site..."

docker compose exec -T backend \
    bench setup add-domain "${SITE_DOMAIN}" \
    --site "${SITE_NAME}" || \
    log_warn "Domain add failed — may already be registered"

docker compose restart frontend
log_success "Domain registered with ERPNext"

log_step "STEP 6: Enable Access Policies (Zero Trust)"
echo ""
echo "  To restrict who can access your school ERP:"
echo ""
echo "  1. Go to: Zero Trust → Access → Applications"
echo "  2. Click 'Add an application'"
echo "  3. Choose 'Self-hosted'"
echo "  4. Application name: 'School ERP'"
echo "  5. Application domain: ${SITE_DOMAIN}"
echo "  6. Policy:"
echo "     - Name: School Staff"
echo "     - Action: Allow"
echo "     - Include: Emails ending in '@school.example.com'"
echo "       OR Include: Everyone (if ERPNext login is sufficient)"
echo "  7. Save application"
echo ""
log_warn "IMPORTANT: Add your email to the allowed list or set to 'Allow All'"
echo ""
read -rp "  Press ENTER when access policies are configured... "

log_step "STEP 7: Restart Cloudflare Tunnel"
echo ""
log_info "Restarting cloudflared container..."
docker compose up -d cloudflared --force-recreate
sleep 10
log_success "Tunnel container restarted"

log_step "STEP 8: Verify tunnel is working"
echo ""
log_info "Checking tunnel status..."
sleep 5

CF_LOGS=$(docker compose logs --tail=10 cloudflared 2>&1)
if echo "$CF_LOGS" | grep -qi "registered tunnel\|connection\|Connected"; then
    log_success "Tunnel is connected!"
else
    log_warn "Tunnel may still be connecting. Check: docker compose logs cloudflared"
fi

log_info "Testing HTTPS endpoint..."
HTTP_STATUS=$(curl -so /dev/null -w "%{http_code}" --max-time 30 \
    "https://${SITE_DOMAIN}" 2>/dev/null || echo "000")

if [[ "$HTTP_STATUS" =~ ^(200|302|301)$ ]]; then
    log_success "HTTPS endpoint responding! (HTTP $HTTP_STATUS)"
else
    log_warn "HTTPS endpoint returned HTTP $HTTP_STATUS — may need more time"
    log_info "DNS propagation can take 5-10 minutes after tunnel setup"
fi

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Cloudflare Tunnel Setup Complete! 🌐                  ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║                                                          ║${NC}"
echo -e "${GREEN}║  Your school ERP is now accessible at:                  ║${NC}"
echo -e "${GREEN}║  https://${SITE_DOMAIN}         ║${NC}"
echo -e "${GREEN}║                                                          ║${NC}"
echo -e "${GREEN}║  Features:                                               ║${NC}"
echo -e "${GREEN}║  ✓ HTTPS with Cloudflare SSL certificate                ║${NC}"
echo -e "${GREEN}║  ✓ No ports exposed on your network                     ║${NC}"
echo -e "${GREEN}║  ✓ DDoS protection by Cloudflare                        ║${NC}"
echo -e "${GREEN}║  ✓ Global CDN for static assets                          ║${NC}"
echo -e "${GREEN}║                                                          ║${NC}"
echo -e "${GREEN}║  Monitor: docker compose logs -f cloudflared            ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
