# AI Agent Deployment & Operations Guide
**Target Audience**: Agentic AI platforms (e.g., AutoGPT, Devin, Antigravity, ChatGPT, Claude) interacting with this repository.

## 🧠 System Context
This repository contains a highly-customized, production-ready **ERPNext / Frappe v15** School Management System deployed via **Docker Compose**. It uses a custom built backend image (`erpnext-school-backend`) that pre-installs the `erpnext`, `hrms`, and `education` apps. 

### Critical Architecture Details (DO NOT ALTER UNLESS INSTRUCTED)
1. **Shared Volumes for Frontend Styling**: The `frontend` (Nginx) container uses the standard `frappe/erpnext:v15.111.0` image. To ensure the custom CSS/JS assets from the `hrms` and `education` apps are correctly served (and to avoid `404 Not Found` errors on `login.bundle.css`), the `apps` and `assets` volumes are explicitly mounted as shared volumes across both `backend` and `frontend` containers.
2. **Asset Compilation**: `bench build` MUST be run inside the `backend` container upon initial deployment so that the shared `assets` and `apps` volumes are populated with the freshly compiled frontend bundles.
3. **Cloudflare Tunnel**: The stack includes a `cloudflared` container that securely tunnels local traffic to the outside internet. The frontend container's port `8080` is NOT mapped to `0.0.0.0`; it is restricted to `127.0.0.1`.

---

## 🛠️ Deployment Steps for AI Agents

If you are an AI tasked with deploying this repository on a new server, follow these exact steps sequentially:

### Step 1: Initialize Environment Variables
Read `.env.example` to understand the required variables. Copy it to `.env` and generate secure passwords/tokens.
```bash
cp .env.example .env
```
*Action for AI*: Generate a new 32-character base64 Fernet key for `ENCRYPTION_KEY` and strong passwords for `ADMIN_PASSWORD` and MariaDB credentials. Write them into the `.env` file.

### Step 2: Build and Start the Cluster
The backend container needs to be built from the `Containerfile` (or `Dockerfile`) to bake in the custom apps.
```bash
# Build the custom backend image
docker compose build backend

# Bring up the cluster in detached mode
docker compose up -d
```
*Wait Condition*: Run `docker ps` and ensure the containers (especially `backend`, `frontend`, and `db`) are `Up` and transition to `healthy`.

### Step 3: Compile Frontend Assets (CRITICAL)
Once the containers are up, the Nginx `frontend` will NOT have the correct CSS/JS for the `education` and `hrms` modules until you compile them centrally.
```bash
# Compile all assets into the shared volumes
docker compose exec backend bench build
```
*Verification*: Run `curl -I -H "Host: school.localhost" http://localhost:8080/login` to verify that the CSS bundle returns an HTTP 200, not a 404.

### Step 4: Run the Setup Script
Execute the pre-configured Frappe school setup script to initialize fee structures, courses, and schedules.
```bash
# Run the automated school configuration script
docker compose exec backend bench --site school.localhost execute frappe.school_setup.run_setup
```

---

## 🔍 Troubleshooting Guide for AI Agents

1. **Unstyled Login Page (Missing CSS)**
   - *Symptom*: HTML is served but `login.bundle.css` returns `404 Not Found`.
   - *Fix*: The `apps` or `assets` volume is out of sync. Re-run `docker compose exec backend bench build` to update the shared volumes. Verify that `docker-compose.yml` mounts `apps:/home/frappe/frappe-bench/apps` on the `frontend` service.

2. **Database Connection Issues**
   - *Symptom*: MariaDB access denied or configurator fails to run `bench new-site`.
   - *Fix*: Verify that `MARIADB_ROOT_PASSWORD` in `.env` matches what is currently stored in the Docker volume. If the volume was created with a different password, either delete the volume `docker volume rm erpnext-school_db-data` or update the `.env` file.

3. **Cloudflare Tunnel Down**
   - *Symptom*: Public domain is unreachable.
   - *Fix*: Ensure `CLOUDFLARE_TUNNEL_TOKEN` is injected into the `.env` file. Restart the tunnel via `docker compose restart cloudflared`. Check logs with `docker compose logs cloudflared`.

---
*End of AI Instructions.*
