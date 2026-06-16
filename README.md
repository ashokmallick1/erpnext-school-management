# ERPNext School Management System

> **Complete, Production-Ready, Open-Source School Management System**  
> Built on ERPNext v15 · Docker Desktop · Cloudflare Tunnel  
> Research-Validated June 2026

---

## 🏫 What You Get

A full **K-12 School Management System** including:

| Module | Features |
|--------|---------|
| **Student Management** | Profiles, photos, documents, medical info, emergency contacts, lifecycle |
| **Parent Portal** | Guardian login, communication, fee tracking, student progress |
| **Admissions** | Online applications, document uploads, approval workflow, enrollment |
| **Academics** | Programs, courses, timetable, teacher assignment, curriculum |
| **Attendance** | Student & teacher attendance, reports, absence notifications |
| **Examinations** | Schedules, marks entry, grading, GPA, report cards, transcripts |
| **Fee Management** | Structures, scholarships, installments, invoices, payment tracking |
| **Library** | Books, inventory, lending, returns, fines |
| **Transport** | Vehicles, routes, drivers, student assignments |
| **Hostel** | Rooms, allocations, hostel fees |
| **HR & Payroll** | Teachers, staff, payroll (via Frappe HRMS) |
| **LMS** | Online courses, assignments, quizzes, certificates |
| **AI Assistant** | Optional AI for teachers and school administration |

---

## 🔬 Validated Software Stack

> **Research conducted:** June 2026  
> **All versions confirmed as of research date**

| Component | Version | Status | Source |
|-----------|---------|--------|--------|
| ERPNext | **v15.109.3** | ✅ Active (EOL end-2027) | frappe/erpnext |
| Frappe Framework | **v15.111.1** | ✅ Active | frappe/frappe |
| Frappe Education | **version-15** branch | ✅ Active, Official | frappe/education |
| Frappe LMS | **version-15** branch | ✅ Active, Official | frappe/lms |
| Frappe HRMS | **version-15** branch | ✅ Active, Official | frappe/hrms |
| Frappe Payments | **version-15** branch | ✅ Maintained | frappe/payments |
| MariaDB | **10.6** | ✅ Required by ERPNext v15 | Official |
| Redis | **7.2** | ✅ Stable | Official Alpine |
| Cloudflare Tunnel | **latest** | ✅ Active | cloudflare/cloudflared |

---

## ⚡ Quick Start (15 Minutes to Running System)

### Prerequisites

- **Docker Desktop** with WSL2 (Windows) / Docker Engine (Linux/Mac)
- **8GB RAM** minimum (16GB recommended)
- **50GB free disk** space
- **Internet connection** (for image downloads)
- **Cloudflare account** with a domain (for public access)

### 1. Clone & Configure

```bash
git clone https://github.com/yourorg/erpnext-school.git
cd erpnext-school

# Configure your settings
cp .env .env.backup
nano .env   # Or use any text editor
```

**Critical settings to change in `.env`:**
```
ADMIN_PASSWORD=YourSecurePassword123!
MARIADB_ROOT_PASSWORD=YourSecureRootPassword!
MARIADB_PASSWORD=YourSecureFrappePassword!
BACKUP_ENCRYPTION_KEY=your-strong-passphrase
CLOUDFLARE_TUNNEL_TOKEN=your-cf-token-from-dashboard
SITE_DOMAIN=erp.yourschool.com
```

### 2. Deploy (All-in-One)

```bash
# Linux/Mac
bash scripts/deploy.sh

# Windows PowerShell
.\deploy.ps1
```

This single command:
1. Creates all required directories
2. Builds the custom Docker image (~20 min)
3. Starts all services
4. Creates the ERPNext site
5. Installs all school apps
6. Configures school settings

### 3. Access

```
Local: http://localhost:8080
Username: Administrator
Password: (your ADMIN_PASSWORD from .env)
```

### 4. Set Up Cloudflare Tunnel

```bash
bash scripts/setup-cloudflare.sh
```

Then access your school at: `https://erp.yourschool.com`

---

## 📁 Project Structure

```
erpnext-school/
│
├── .env                    ← Environment configuration (CONFIGURE THIS)
├── docker-compose.yml      ← All Docker services
├── Containerfile           ← Custom image with all school apps
├── apps.json               ← Apps to bake into the image
├── deploy.ps1              ← Windows PowerShell deployment
│
├── config/
│   ├── mariadb/
│   │   ├── my.cnf          ← MariaDB optimization settings
│   │   └── init.sql        ← Database initialization
│   ├── cloudflare/
│   │   └── config.yml      ← Cloudflare Tunnel config (alt. method)
│   ├── ai/
│   │   └── ai_config.toml  ← AI module settings
│   ├── common_site_config.json  ← Frappe common config
│   └── site_config.json    ← Site-specific config
│
├── scripts/
│   ├── deploy.sh           ← Main deployment script
│   ├── build.sh            ← Docker image builder
│   ├── install.sh          ← ERPNext site installer
│   ├── init-dirs.sh        ← Directory initializer
│   ├── backup-cron.sh      ← Automated backup daemon
│   ├── restore.sh          ← Backup restore script
│   ├── upgrade.sh          ← System upgrade script
│   ├── health-check.sh     ← System health monitor
│   ├── validate.sh         ← Complete validation suite
│   ├── setup-cloudflare.sh ← Cloudflare Tunnel wizard
│   └── school-setup.py     ← School configuration script
│
├── data/                   ← All persistent data (created by init-dirs.sh)
│   ├── sites/              ← Frappe sites (configs + files)
│   ├── mariadb/            ← Database data
│   ├── logs/               ← Application logs
│   ├── redis-queue/        ← Redis queue persistence
│   └── backups/            ← Encrypted backups
│
└── docs/
    ├── installation-guide.md
    ├── cloudflare-setup-guide.md
    ├── school-configuration-guide.md
    ├── mobile-api-guide.md
    ├── backup-restore-guide.md
    ├── upgrade-guide.md
    ├── security-guide.md
    └── troubleshooting-guide.md
```

---

## 🏗️ Architecture

```
Internet
    │
    │ HTTPS (Cloudflare SSL)
    ▼
┌─────────────────┐
│   Cloudflare    │  DDoS protection, WAF, CDN
│   Edge Network  │
└────────┬────────┘
         │ Encrypted Tunnel
         ▼
┌─────────────────────────────────────────────────────────────┐
│  Docker Desktop (Your Machine)                              │
│                                                             │
│  ┌────────────┐    ┌────────────────────────────────────┐  │
│  │ cloudflared│───▶│  frontend (Nginx:8080)             │  │
│  │  Tunnel    │    │  Static assets + reverse proxy     │  │
│  └────────────┘    └──────────────┬─────────────────────┘  │
│                                   │                         │
│                    ┌──────────────▼─────────────────────┐  │
│                    │  backend (Gunicorn:8000)            │  │
│                    │  ERPNext + Education + LMS + HRMS  │  │
│                    └──┬──────────────────────────────────┘  │
│                       │                                     │
│         ┌─────────────┼──────────────────┐                 │
│         ▼             ▼                  ▼                  │
│  ┌────────────┐ ┌──────────┐ ┌───────────────────┐        │
│  │  MariaDB   │ │  Redis   │ │   Redis Queue     │        │
│  │  10.6      │ │  Cache   │ │   + SocketIO      │        │
│  │ (Database) │ │  512MB   │ │   Workers         │        │
│  └────────────┘ └──────────┘ └───────────────────┘        │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐  │
│  │  Background Services                                │  │
│  │  scheduler | queue-short | queue-long | backup      │  │
│  └─────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## 📖 Documentation

| Guide | Description |
|-------|-------------|
| [Installation Guide](docs/installation-guide.md) | Step-by-step setup |
| [Cloudflare Setup](docs/cloudflare-setup-guide.md) | Public HTTPS access |
| [School Configuration](docs/school-configuration-guide.md) | K-12 setup via UI |
| [Mobile API](docs/mobile-api-guide.md) | Parent/Teacher/Student apps |
| [Backup & Restore](docs/backup-restore-guide.md) | Data protection |
| [Upgrade Guide](docs/upgrade-guide.md) | Safe upgrades |
| [Security Guide](docs/security-guide.md) | Hardening & compliance |
| [Troubleshooting](docs/troubleshooting-guide.md) | Common issues & fixes |

---

## 🔑 Default Roles

| Role | Access Level | Portal |
|------|-------------|--------|
| Administrator | Full system | Desk |
| Principal | All school data | Desk |
| Teacher | Students, attendance, marks | Desk |
| Parent | Own child's data | Web Portal |
| Student Portal User | Own data | Web Portal |
| Accounts Manager | Finance, fees | Desk |
| Librarian | Library module | Desk |
| Transport Manager | Transport module | Desk |
| Hostel Manager | Hostel module | Desk |
| School Receptionist | Admissions, basic info | Desk |

---

## 🔧 Common Commands

```bash
# View all services status
docker compose ps

# View logs (all services)
docker compose logs -f

# View specific service logs
docker compose logs -f backend

# Run health check
bash scripts/health-check.sh

# Run validation tests
bash scripts/validate.sh

# Manual backup
docker compose exec backend bench --site school.localhost backup --with-files

# List installed apps
docker compose exec backend bench --site school.localhost list-apps

# Clear cache
docker compose exec backend bench --site school.localhost clear-cache

# Access bench CLI
docker compose exec backend bash

# Access MariaDB
docker compose exec db mysql -uroot -p

# Restart all services
docker compose restart
```

---

## 🛡️ Security Features

- ✅ No ports exposed to internet (Cloudflare Tunnel only)
- ✅ HTTPS everywhere (Cloudflare SSL)
- ✅ Cloudflare DDoS protection
- ✅ Database on internal Docker network only
- ✅ Redis on internal Docker network only
- ✅ Encrypted backups (AES-256-CBC)
- ✅ Password policy enforcement
- ✅ Session timeout
- ✅ CSRF protection (built into Frappe)
- ✅ SQL injection protection (Frappe ORM)
- ✅ Audit logs (built into ERPNext)

---

## 📞 Support

- **ERPNext Forum:** https://discuss.frappe.io
- **Frappe Education Issues:** https://github.com/frappe/education/issues
- **ERPNext Issues:** https://github.com/frappe/erpnext/issues
- **Documentation:** https://docs.frappe.io/education

---

## 📄 License

This project configuration is open-source under MIT License.  
ERPNext is licensed under GPL v3.  
Frappe Framework is licensed under MIT License.
