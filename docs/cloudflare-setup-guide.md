# ERPNext School Management System — Cloudflare Tunnel Setup Guide

> **Audience:** System administrators setting up external access to ERPNext School.  
> **Prerequisite:** ERPNext must be running locally (complete the Installation Guide first).

---

## Table of Contents
1. [Why Cloudflare Tunnel?](#1-why-cloudflare-tunnel)
2. [Prerequisites](#2-prerequisites)
3. [Part 1: Account and Domain Setup](#part-1-cloudflare-account-and-domain-setup)
4. [Part 2: Zero Trust Setup](#part-2-zero-trust-setup)
5. [Part 3: Create a Tunnel](#part-3-create-a-tunnel)
6. [Part 4: Get the Tunnel Token](#part-4-get-the-tunnel-token)
7. [Part 5: Configure Public Hostname](#part-5-configure-public-hostname)
8. [Part 6: Start the Cloudflare Container](#part-6-start-the-cloudflare-tunnel-container)
9. [Part 7: Register Domain with ERPNext](#part-7-register-domain-with-erpnext)
10. [Part 8: Access Policies](#part-8-access-policies-zero-trust)
11. [Part 9: DNS Configuration](#part-9-dns-configuration)
12. [Part 10: Cloudflare Security Settings](#part-10-cloudflare-security-settings)
13. [Part 11: Verification and Testing](#part-11-verification-and-testing)
14. [Part 12: Troubleshooting](#part-12-troubleshooting)

---

## 1. Why Cloudflare Tunnel?

Cloudflare Tunnel (formerly Argo Tunnel) provides a secure way to expose your ERPNext instance to the internet **without opening any inbound firewall ports**.

### Benefits

| Feature | Traditional Port Forward | Cloudflare Tunnel |
|---------|--------------------------|--------------------|
| Inbound ports open | ✅ Yes (risky) | ❌ No |
| DDoS protection | ❌ Manual | ✅ Automatic |
| HTTPS certificate | Manual setup | ✅ Automatic |
| Hides server IP | ❌ No | ✅ Yes |
| Zero Trust access | ❌ No | ✅ Yes |
| Cost | Free | Free tier available |
| Setup complexity | Medium | Low |

### How It Works

```
User Browser
    ↓ HTTPS
Cloudflare Edge (Global CDN + WAF)
    ↓ Encrypted tunnel (outbound from your server)
cloudflared container (in your Docker network)
    ↓ HTTP on internal Docker network
frontend container (nginx, port 8080)
    ↓ HTTP proxy
backend container (Gunicorn, port 8000)
```

The `cloudflared` process initiates an **outbound** connection to Cloudflare's edge. No inbound ports required on your router or firewall.

---

## 2. Prerequisites

- [ ] ERPNext running locally (all containers healthy)
- [ ] A registered domain name (e.g., `myschool.com`)
- [ ] Access to your domain's DNS registrar (to update nameservers)
- [ ] A Cloudflare account (free tier sufficient)
- [ ] `CLOUDFLARE_TUNNEL_TOKEN` ready to add to `.env`

---

## Part 1: Cloudflare Account and Domain Setup

### Step 1.1: Create a Cloudflare Account

1. Go to **https://dash.cloudflare.com/sign-up**
2. Enter your email and create a password
3. Verify your email address
4. Select the **Free** plan (sufficient for most schools)

### Step 1.2: Add Your Domain

1. From the Cloudflare dashboard, click **Add a Site** (or **Add a domain**)
2. Enter your domain name (e.g., `myschool.com`) — do NOT include `www.`
3. Click **Continue**
4. Select the **Free** plan → **Continue**
5. Cloudflare will scan your existing DNS records
6. Review the imported records → Click **Continue**
7. Cloudflare will show you **two nameservers**, for example:
   ```
   aria.ns.cloudflare.com
   blake.ns.cloudflare.com
   ```

### Step 1.3: Update Nameservers at Your Registrar

Log in to wherever you bought your domain (GoDaddy, Namecheap, Google Domains, etc.) and:

1. Find **DNS Settings** or **Nameservers**
2. Change to **Custom Nameservers**
3. Delete the existing nameservers
4. Add both Cloudflare nameservers from Step 1.2
5. Save the changes

> ⏳ **Wait time:** DNS propagation typically takes 5–30 minutes. Maximum 48 hours.

### Step 1.4: Verify Domain is Active

**Bash:**
```bash
# Check nameservers have propagated
dig NS myschool.com +short

# Expected output:
# aria.ns.cloudflare.com.
# blake.ns.cloudflare.com.
```

**PowerShell:**
```powershell
# Check nameservers
Resolve-DnsName myschool.com -Type NS | Select-Object NameHost
```

The Cloudflare dashboard will show a **green checkmark** and "Active" status when propagation is complete.

---

## Part 2: Zero Trust Setup

### Step 2.1: Access Zero Trust Dashboard

1. In the Cloudflare dashboard, click **Zero Trust** in the left sidebar
2. Or navigate directly to: **https://one.dash.cloudflare.com**

### Step 2.2: Create a Zero Trust Organization

1. On first access, you'll be prompted to create an organization
2. Enter a **Team Name** (e.g., `myschool` — this becomes `myschool.cloudflareaccess.com`)
3. Select the **Free plan** → Click **Proceed**
4. Note your **Account ID** from the URL:
   ```
   https://one.dash.cloudflare.com/XXXXXXXXXXXXXXXX/
                                   ^^^^^^^^^^^^^^^^
                                   This is your Account ID
   ```

---

## Part 3: Create a Tunnel

### Step 3.1: Navigate to Tunnels

1. In Zero Trust dashboard → Left sidebar → **Networks** → **Tunnels**
2. Click **Create a tunnel**

### Step 3.2: Select Connector Type

1. Select **Cloudflared** as the connector type
2. Click **Next**

### Step 3.3: Name Your Tunnel

1. Enter a tunnel name: `erpnext-school-tunnel` (or similar descriptive name)
2. Click **Save tunnel**

### Step 3.4: Copy the Tunnel Token

After saving, Cloudflare will show an installation page with your tunnel token.

**⚠️ Important:** The token is shown in the connector command:
```bash
cloudflared service install eyJhIjoiYWJjZGVm...
```

The long string starting with `eyJ...` is your **Tunnel Token**. Copy the entire token.

---

## Part 4: Get the Tunnel Token

### Step 4.1: Locate the Token

If you need to find the token again:
1. Zero Trust → Networks → Tunnels → Click your tunnel name
2. Click the **...** (three dots) → **Configure**
3. Go to the **Connectors** tab
4. The token appears in the installation command

### Step 4.2: Add Token to .env

**Bash:**
```bash
# Edit your .env file
nano .env

# Find the line:
# CLOUDFLARE_TUNNEL_TOKEN=
# Replace with:
# CLOUDFLARE_TUNNEL_TOKEN=eyJhIjoiYWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXo...
```

**PowerShell:**
```powershell
# Edit .env
notepad .env
# Find CLOUDFLARE_TUNNEL_TOKEN= and paste your token after =
```

The token format looks like:
```
CLOUDFLARE_TUNNEL_TOKEN=eyJhIjoiYWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXoxMjM0NTY3ODkwYWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXoxMjM0NTY3ODkwYWJjZGVm
```

> ⚠️ **Security:** Treat this token like a password. Anyone with it can route traffic through your tunnel.

---

## Part 5: Configure Public Hostname

This tells Cloudflare which internal service to route traffic to.

### Step 5.1: Add a Public Hostname

1. In your tunnel settings → Click **Public Hostname** tab
2. Click **Add a public hostname**

### Step 5.2: Fill in the Hostname Configuration

| Field | Value | Notes |
|-------|-------|-------|
| Subdomain | `school` | Or leave blank for root domain |
| Domain | `myschool.com` | Your domain |
| Path | (leave empty) | Route all paths |
| Type | `HTTP` | NOT HTTPS |
| URL | `frontend:8080` | Docker service name + port |

> 🚨 **Critical:** The URL **must** be `frontend:8080` (the Docker service name), NOT `localhost:8080`. Cloudflared runs inside Docker and uses Docker's internal DNS.

### Step 5.3: Additional Settings (Optional but Recommended)

Expand **Additional application settings** → **TLS** section:
- **No TLS Verify:** Enable if frontend uses self-signed certificate
- **HTTP Host Header:** Set to `school.myschool.com` (your full domain)

### Step 5.4: Save the Hostname

Click **Save hostname**. Cloudflare automatically creates a DNS CNAME record.

---

## Part 6: Start the Cloudflare Tunnel Container

### Step 6.1: Cloudflare Service in docker-compose.yml

Your `docker-compose.yml` should include:

```yaml
cloudflared:
  image: cloudflare/cloudflared:latest
  restart: unless-stopped
  command: tunnel --no-autoupdate run
  environment:
    - TUNNEL_TOKEN=${CLOUDFLARE_TUNNEL_TOKEN}
  networks:
    - backend-net
  depends_on:
    - frontend
```

### Step 6.2: Start the Cloudflare Container

**Bash:**
```bash
docker compose up -d cloudflared

# Watch the logs
docker compose logs -f cloudflared
```

**PowerShell:**
```powershell
docker compose up -d cloudflared
docker compose logs -f cloudflared
```

### Step 6.3: Expected Healthy Log Output

```
cloudflared  | 2024-01-15T10:30:00Z INF Starting tunnel tunnelID=abc123
cloudflared  | 2024-01-15T10:30:01Z INF Connection registered connIndex=0 event=0 ip=198.41.200.100
cloudflared  | 2024-01-15T10:30:01Z INF Connection registered connIndex=1 event=0 ip=198.41.200.200
cloudflared  | 2024-01-15T10:30:01Z INF Registered tunnel connection
```

In the Cloudflare Zero Trust dashboard, your tunnel status will change from **Inactive** to **Healthy** (green dot) ✅

---

## Part 7: Register Domain with ERPNext

Frappe validates the `Host` header of incoming requests. You must register your public domain with the site.

### Step 7.1: Add Domain to ERPNext Site

**Bash:**
```bash
docker compose exec backend bench --site school.localhost setup add-domain school.myschool.com
```

**PowerShell:**
```powershell
docker compose exec backend bench --site school.localhost setup add-domain school.myschool.com
```

### Step 7.2: Update FRAPPE_SITE_NAME_HEADER

Edit `.env` and update:
```dotenv
# Change from:
FRAPPE_SITE_NAME_HEADER=school.localhost

# To your public domain:
FRAPPE_SITE_NAME_HEADER=school.myschool.com
```

Then restart the frontend:

**Bash:**
```bash
docker compose restart frontend
```

**PowerShell:**
```powershell
docker compose restart frontend
```

### Step 7.3: Verify Domain Registration

**Bash:**
```bash
docker compose exec backend cat /home/frappe/frappe-bench/sites/school.localhost/site_config.json
```

Look for your domain in the `domains` array:
```json
{
  "domains": ["school.myschool.com"],
  "db_name": "school_localhost",
  ...
}
```

---

## Part 8: Access Policies (Zero Trust)

Optionally restrict access so only authorized school staff can reach the login page.

### Step 8.1: Create an Access Application

1. Zero Trust → **Access** → **Applications** → **Add an application**
2. Select **Self-hosted**
3. Fill in:
   - **Application name:** ERPNext School Portal
   - **Application domain:** `school.myschool.com`
   - **Session duration:** 12 hours

### Step 8.2: Create an Access Policy

On the **Policies** step:

1. Click **Add a policy**
2. **Policy name:** School Staff Access
3. **Action:** Allow
4. **Include rule:**
   - Selector: **Emails ending in**
   - Value: `@myschool.edu` (your school's email domain)
5. Click **Save**

### Step 8.3: Bypass Policy for API and Assets

Add a second policy to bypass authentication for automated requests:

1. Click **Add a policy**
2. **Policy name:** Bypass API and Assets
3. **Action:** Bypass
4. **Include rule:**
   - Selector: **Everyone**
5. **Path:** `/api/*` and `/assets/*`

---

## Part 9: DNS Configuration

### Step 9.1: Verify CNAME Record

When you added the public hostname in Part 5, Cloudflare automatically created a DNS CNAME record:

| Type | Name | Content | Proxy Status |
|------|------|---------|---------------|
| CNAME | school | `<tunnel-id>.cfargotunnel.com` | Proxied (orange cloud) ✅ |

> 🔴 **Important:** The cloud icon MUST be **orange** (Proxied), not grey (DNS only). If it's grey, the tunnel won't work.

### Step 9.2: Verify DNS Propagation

**Bash:**
```bash
# Check the CNAME resolves
dig school.myschool.com CNAME +short

# Check it resolves to Cloudflare IPs
dig school.myschool.com A +short
```

**PowerShell:**
```powershell
Resolve-DnsName school.myschool.com -Type CNAME
Resolve-DnsName school.myschool.com -Type A
```

Expected A records: Cloudflare IP addresses (104.x.x.x or 172.x.x.x)

---

## Part 10: Cloudflare Security Settings

### 10.1 SSL/TLS Configuration

**Dashboard:** Cloudflare → Your Domain → **SSL/TLS** → **Overview**

1. Set encryption mode to: **Full (strict)**
2. Go to **Edge Certificates** tab:
   - Enable **Always Use HTTPS** ✅
   - Enable **HSTS** with:
     - Max Age: 6 months
     - Include Subdomains: ✅
   - Enable **Opportunistic Encryption** ✅
   - Minimum TLS version: **TLS 1.2**
   - Enable **TLS 1.3** ✅

### 10.2 WAF (Web Application Firewall)

**Dashboard:** Cloudflare → Your Domain → **Security** → **WAF**

1. Click **Managed Rules** tab
2. Enable **Cloudflare Managed Ruleset** ✅
3. Enable **Cloudflare OWASP Core Ruleset** ✅
4. Set sensitivity to: **High**

**Custom WAF Rule (block scanners):**
```
Rule Name: Block Common Scanners
Expression: (http.request.uri.path contains "/wp-admin") or 
            (http.request.uri.path contains "/etc/passwd") or
            (http.request.uri.path contains "/.env") or
            (http.request.uri.path contains "/phpmyadmin")
Action: Block
```

### 10.3 Rate Limiting

**Dashboard:** Security → **WAF** → **Rate limiting rules**

**Rule 1: Login Protection**
```
Name: Limit Login Attempts
URL: /api/method/login
Threshold: 5 requests per 60 seconds per IP
Action: Block for 1 hour
```

**Rule 2: API Rate Limit**
```
Name: API Rate Limit
URL: /api/*
Threshold: 300 requests per 60 seconds per IP  
Action: Managed Challenge
```

**Rule 3: Password Reset Protection**
```
Name: Password Reset Limit
URL: /api/method/frappe.core.doctype.user.user.reset_password
Threshold: 3 requests per 3600 seconds per IP
Action: Block for 24 hours
```

### 10.4 Bot Fight Mode

**Dashboard:** Security → **Bots**

1. Enable **Bot Fight Mode** ✅
2. Enable **Block AI Scrapers and Crawlers** ✅ (if desired)
3. Verified bots (Google, Bing): Allow (default)

### 10.5 Security Headers via Transform Rules

**Dashboard:** Rules → **Transform Rules** → **Modify Response Header**

Add these headers:

| Header | Value |
|--------|-------|
| `X-Frame-Options` | `SAMEORIGIN` |
| `X-Content-Type-Options` | `nosniff` |
| `Referrer-Policy` | `strict-origin-when-cross-origin` |
| `Permissions-Policy` | `geolocation=(), microphone=(), camera=()` |

---

## Part 11: Verification and Testing

### Step 11.1: Test HTTPS Access

**Bash:**
```bash
# Test HTTPS connection
curl -I https://school.myschool.com

# Expected:
# HTTP/2 200
# server: cloudflare
# cf-ray: ...
```

**PowerShell:**
```powershell
Invoke-WebRequest -Uri https://school.myschool.com -Method HEAD | Select-Object StatusCode, Headers
```

### Step 11.2: Verify HTTP Redirects to HTTPS

```bash
curl -I http://school.myschool.com

# Expected:
# HTTP/1.1 301 Moved Permanently
# Location: https://school.myschool.com/
```

### Step 11.3: Check Tunnel Status in Dashboard

1. Zero Trust → Networks → Tunnels
2. Your tunnel should show: 🟢 **Healthy**
3. Click the tunnel to see connection details (2–4 connections to Cloudflare edge)

### Step 11.4: Test Admin Login

1. Open `https://school.myschool.com` in an incognito browser window
2. Login with `Administrator` credentials
3. Verify Education module is accessible
4. Verify student records load correctly

---

## Part 12: Troubleshooting

### Issue 1: Tunnel Shows 'Inactive' / Container Not Starting

**Symptoms:** Tunnel status in dashboard is grey/inactive. Container exits immediately.

**Check logs:**
```bash
docker compose logs cloudflared
```

**Likely causes and fixes:**

```bash
# Cause 1: Invalid or missing token
# Fix: Verify token in .env
grep CLOUDFLARE_TUNNEL_TOKEN .env

# Cause 2: Network issue (container can't reach Cloudflare)
docker compose exec cloudflared curl -s https://api.cloudflare.com

# Cause 3: Wrong token format (includes extra whitespace)
# Fix: Ensure no spaces around = in .env
```

### Issue 2: 502 Bad Gateway

**Symptoms:** Cloudflare returns 502 error page.

**Cause:** The `frontend` container is not running or not listening on port 8080.

```bash
# Check frontend status
docker compose ps frontend
docker compose logs --tail=20 frontend

# Verify frontend is listening
docker compose exec frontend curl -s http://localhost:8080/

# Restart frontend
docker compose restart frontend
```

### Issue 3: CSS/JS Not Loading

**Symptoms:** Site loads but looks broken. Console shows 404 for static files.

**Cause:** Assets URL mismatch or assets not built.

```bash
# Rebuild assets
docker compose exec backend bench build --app frappe --app erpnext --app education

# Restart frontend to pick up new assets
docker compose restart frontend

# Clear Cloudflare cache
# Dashboard: Caching → Configuration → Purge Everything
```

### Issue 4: Login Redirect Loop

**Symptoms:** Login page refreshes endlessly. Never logs in.

**Cause:** `FRAPPE_SITE_NAME_HEADER` doesn't match the domain you're accessing.

```bash
# Check current setting
grep FRAPPE_SITE_NAME_HEADER .env

# Must match exactly what's in the browser URL bar
# If accessing school.myschool.com, set:
# FRAPPE_SITE_NAME_HEADER=school.myschool.com

# After changing .env:
docker compose restart frontend
```

### Issue 5: Tunnel Token Invalid

**Symptoms:** Logs show `failed to unmarshal tunnel token`

```bash
# The token may have been truncated. Verify it's complete:
grep CLOUDFLARE_TUNNEL_TOKEN .env | wc -c
# Token should be 200+ characters

# Get a new token from Cloudflare dashboard:
# Zero Trust → Networks → Tunnels → Your Tunnel → Configure → Connectors
# Copy the fresh token and update .env

docker compose up -d cloudflared
```

### Issue 6: DNS Not Propagated

**Symptoms:** `school.myschool.com` shows "This site can't be reached".

```bash
# Check DNS propagation
nslookup school.myschool.com 8.8.8.8

# Use DNS propagation checker:
# https://www.whatsmydns.net/#CNAME/school.myschool.com

# The CNAME must point to: <tunnel-id>.cfargotunnel.com
# If it shows your server IP, the DNS record is DNS-only (not proxied).
# Fix: In Cloudflare DNS, click the orange cloud icon next to the CNAME record.
```

---

## Summary

After completing this guide:
- ✅ Your ERPNext instance is accessible at `https://school.myschool.com`
- ✅ HTTPS is enforced with automatic certificate renewal
- ✅ No inbound ports are open on your server
- ✅ DDoS and WAF protection is active
- ✅ Rate limiting protects the login endpoint

Next step: **[School Configuration Guide](./school-configuration-guide.md)**

---

*Last updated: 2024 | ERPNext School Management System Documentation*
