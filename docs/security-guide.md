# Security Hardening Guide — ERPNext School

> Complete security posture for production school deployment

---

## Security Architecture Overview

```
Internet
   │
   ▼  ◄── Cloudflare: DDoS, WAF, Bot Protection, SSL
Cloudflare Edge
   │
   │ AES-256 Encrypted Tunnel (outbound only)
   ▼
Docker Host (localhost only)
   │
   ├── frontend (8080 → only 127.0.0.1 binding)
   │      │
   │      ▼  (backend-net: internal: true)
   ├── backend, workers, scheduler
   │      │
   │      ├── db     (NO external port)
   │      ├── redis-* (NO external port)
   │      └── backup
   │
   └── cloudflared (outbound tunnel only)
```

**Key principle:** Zero inbound ports exposed to the internet or LAN.

---

## Layer 1: Cloudflare Security (Built-In)

### 1.1 DDoS Protection

Cloudflare provides **automatic DDoS mitigation** at the edge. No configuration needed — it's always on.

- Magic Transit (network layer)
- HTTP DDoS protection (application layer)
- Rate limiting by IP, ASN, or country

### 1.2 Web Application Firewall (WAF)

**Cloudflare Dashboard → Security → WAF**

Enable these rulesets:

| Ruleset | Protects Against |
|---------|-----------------|
| Cloudflare Managed Rules | Known attack patterns |
| OWASP Core Ruleset | SQL injection, XSS, RFI |
| Cloudflare Specials | Zero-day exploits |

```
WAF → Managed Rules → Cloudflare Managed Ruleset → Enabled
WAF → Managed Rules → OWASP Core Ruleset → Enabled (Sensitivity: Medium)
```

### 1.3 Rate Limiting Rules

**Security → WAF → Rate Limiting Rules → Create**

**Rule 1: Protect Login**
```
Rule name: Brute Force Protection
When: URI Path equals /api/method/login
Action: Block
Rate: 10 requests per 60 seconds per IP
Duration: 600 seconds (10 minutes)
```

**Rule 2: API Rate Limit**
```
Rule name: API Rate Limit
When: URI Path starts with /api/
Action: Block
Rate: 300 requests per 60 seconds per IP
Duration: 60 seconds
```

### 1.4 Bot Fight Mode

**Security → Bots → Bot Fight Mode → On**

This automatically challenges known bad bots.

### 1.5 Browser Integrity Check

**Security → Settings → Browser Integrity Check → On**

### 1.6 Security Headers

Cloudflare automatically adds:
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: SAMEORIGIN`

Add custom headers via **Transform Rules → Modify Response Headers:**

```
X-XSS-Protection: 1; mode=block
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: camera=(), microphone=(), geolocation=()
```

### 1.7 SSL/TLS Settings

**SSL/TLS → Overview → Full (Strict)**

**Edge Certificates:**
- Minimum TLS Version: TLS 1.2
- TLS 1.3: Enabled
- HSTS: Enabled (6 months)

---

## Layer 2: ERPNext Security Settings

### 2.1 Password Policy

**ERPNext → Settings → System Settings**

| Setting | Recommended Value |
|---------|-----------------|
| Minimum Password Score | 3 (Strong) |
| Password Reset Limit | 3 attempts |
| Session Expiry | 08:00:00 (8 hours) |
| Session Expiry Mobile | 720:00:00 (30 days) |

### 2.2 Two-Factor Authentication

```
Settings → System Settings → Enable Two Factor Authentication → ✓
Two Factor Method: TOTP (Google Authenticator / Authy)
```

Force 2FA for specific roles:
```
Settings → System Settings → Enforce on Roles → [Principal, System Manager]
```

### 2.3 Login Restrictions

```
Settings → System Settings
→ Allow Login Using Mobile Number: ✓
→ Allow Login Using User Name: ✓
→ Login With Email Link: ✓ (magic link)
→ Allow Consecutive Login Attempts: 5
→ Allow Login After Fail: 60 seconds
```

### 2.4 API Security

Disable unneeded public API endpoints:
```
Settings → Website Settings → Disable Signup: ✓ (unless needed for parent portal)
```

Restrict API access by role in **Role Permission Manager**.

### 2.5 Audit Logs

ERPNext automatically logs:
- All document changes (versions)
- Login/logout events
- Permission changes

**View audit trail:**
```
Settings → Activity Log
Settings → System Log
DocType → [any record] → Activity (tab)
```

Enable **Document Versioning** for sensitive doctypes:
```
Customization → DocType → Student → Track Changes: ✓
Customization → DocType → Fees → Track Changes: ✓
```

---

## Layer 3: Docker Network Security

### 3.1 Network Isolation

The `docker-compose.yml` defines two networks:

```yaml
networks:
  frontend-net:    # Nginx + Cloudflare Tunnel only
    driver: bridge

  backend-net:     # All internal services
    driver: bridge
    internal: true  # ← NO host access!
```

`internal: true` means containers on `backend-net` **cannot make outbound internet connections**. This isolates MariaDB, Redis, and workers completely.

### 3.2 Port Exposure

| Service | External Port | Binding |
|---------|--------------|---------|
| frontend | 8080 | 127.0.0.1 only |
| backend | none | internal only |
| db | none | internal only |
| redis-* | none | internal only |
| cloudflared | none | outbound tunnel only |

**Verify no unwanted ports:**
```bash
docker compose ps --format "table {{.Name}}\t{{.Ports}}"
```

### 3.3 Container Security

Add to `docker-compose.yml` for hardened containers:

```yaml
services:
  backend:
    security_opt:
      - no-new-privileges:true
    read_only: false  # ERPNext needs write access to sites/
    tmpfs:
      - /tmp
```

---

## Layer 4: Database Security

### 4.1 MariaDB Access

- **No external port** exposed (Docker internal only)
- **Root password** required for all administrative operations
- **Frappe user** has only necessary privileges

### 4.2 Database Hardening

In `config/mariadb/my.cnf`:
```ini
# Already configured:
skip-name-resolve      # Faster, prevents DNS-based attacks
symbolic-links=0       # Prevent filesystem traversal
local-infile=0         # Prevent LOAD DATA LOCAL INFILE attacks
```

### 4.3 Regular Password Rotation

```bash
# Rotate MariaDB root password (quarterly)
docker compose exec db mysql -u root -p -e \
  "ALTER USER 'root'@'%' IDENTIFIED BY 'NewRootPassword2026!'"

# Update .env
nano .env
# Change MARIADB_ROOT_PASSWORD=NewRootPassword2026!

# Update ERPNext site config
docker compose exec backend bench \
  --site school.localhost \
  set-config db_password "NewFrappePassword!"
```

---

## Layer 5: Backup Encryption

All backups are encrypted with **AES-256-CBC + PBKDF2**:

```bash
# Encryption
openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 \
  -pass "pass:${BACKUP_ENCRYPTION_KEY}" \
  -in database.sql.gz \
  -out database.sql.gz.enc

# Decryption
openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 \
  -pass "pass:${BACKUP_ENCRYPTION_KEY}" \
  -in database.sql.gz.enc \
  -out database.sql.gz
```

**Key storage:** Store `BACKUP_ENCRYPTION_KEY` in a password manager, **separate from the backup files**.

---

## Security Checklist

### Initial Setup
- [ ] Changed all default passwords in `.env`
- [ ] Generated proper Fernet `ENCRYPTION_KEY`
- [ ] Set strong `BACKUP_ENCRYPTION_KEY`
- [ ] Cloudflare Tunnel token configured
- [ ] WAF enabled in Cloudflare
- [ ] Rate limiting rules created
- [ ] Bot Fight Mode enabled

### ERPNext Configuration
- [ ] Two-factor authentication enabled
- [ ] Password minimum score = 3
- [ ] Session expiry set to 8 hours
- [ ] Admin password changed from default
- [ ] Unnecessary user accounts removed
- [ ] Role permissions reviewed
- [ ] Parent portal restricted to parent roles only

### Ongoing (Monthly)
- [ ] Review Activity Logs for anomalies
- [ ] Review user accounts (remove ex-staff)
- [ ] Test backup restore
- [ ] Check for ERPNext security updates
- [ ] Review Cloudflare security events
- [ ] Rotate backup encryption key (annually)

---

## Incident Response

### Suspected Breach

```bash
# 1. Immediately block all access
# Cloudflare Dashboard → Security → Under Attack Mode → On
# This forces CAPTCHA for all visitors

# 2. Check access logs
docker compose logs --tail=500 frontend | grep -i "POST\|DELETE\|PUT" > /tmp/recent-writes.log

# 3. Check for unauthorized users
docker compose exec backend bench \
  --site school.localhost \
  execute frappe.core.doctype.user.user.get_all_users

# 4. Force logout all sessions
docker compose exec backend bench \
  --site school.localhost \
  execute frappe.sessions.clear_all_sessions

# 5. Change admin password
docker compose exec backend bench \
  --site school.localhost \
  set-admin-password "NewSecurePassword2026!"

# 6. Review and restore from clean backup if needed
bash scripts/restore.sh --list
```

### Lost Admin Password

```bash
docker compose exec backend bench \
  --site school.localhost \
  set-admin-password "NewPassword123!"
```

### Compromised Cloudflare Token

```bash
# 1. Revoke old token in Cloudflare Dashboard
# Zero Trust → Networks → Tunnels → your-tunnel → Delete connector

# 2. Create new token
# Create a new connector in the dashboard

# 3. Update .env
nano .env
# CLOUDFLARE_TUNNEL_TOKEN=new-token

# 4. Restart tunnel
docker compose restart cloudflared
```
