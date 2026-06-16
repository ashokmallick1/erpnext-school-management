# syntax=docker/dockerfile:1.7-labs
##############################################################
# ERPNext School Custom Image
# Based on: Official Frappe Docker custom image approach
# Source: https://github.com/frappe/frappe_docker
# Apps baked in: ERPNext + Payments + HRMS + Education + LMS
#
# Build commands (run from project root):
#   export APPS_JSON_BASE64=$(base64 -w 0 apps.json)   # Linux/Mac
#   $env:APPS_JSON_BASE64=[Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes((Get-Content apps.json -Raw)))  # Windows PowerShell
#
#   docker build \
#     --build-arg=FRAPPE_PATH=https://github.com/frappe/frappe \
#     --build-arg=FRAPPE_BRANCH=version-15 \
#     --build-arg=PYTHON_VERSION=3.11.9 \
#     --build-arg=NODE_VERSION=18.20.4 \
#     --build-arg=APPS_JSON_BASE64=$APPS_JSON_BASE64 \
#     --tag=school-erpnext:v15.109.3 \
#     --file=Containerfile \
#     --no-cache .
##############################################################

ARG PYTHON_VERSION=3.11.9
ARG DEBIAN_BASE=bookworm

FROM python:${PYTHON_VERSION}-slim-${DEBIAN_BASE} AS base

ARG FRAPPE_BRANCH=version-15
ARG FRAPPE_PATH=https://github.com/frappe/frappe
ARG APPS_JSON_BASE64
ARG NODE_VERSION=22.0.0

# ─── System dependencies ──────────────────────────────────
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    # Build tools
    build-essential \
    curl \
    git \
    # MariaDB client
    default-libmysqlclient-dev \
    mariadb-client \
    pkg-config \
    # Image processing
    libjpeg-dev \
    libpng-dev \
    libwebp-dev \
    # PDF generation
    libpango-1.0-0 \
    libpangoft2-1.0-0 \
    libharfbuzz0b \
    # Crypto
    libssl-dev \
    libffi-dev \
    # Barcode generation
    zbar-tools \
    libzbar0 \
    # Network tools
    wget \
    cron \
    # Cleanup
    && rm -rf /var/lib/apt/lists/*

# ─── Node.js ──────────────────────────────────────────────
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g yarn@1.22.22 && \
    rm -rf /var/lib/apt/lists/*

# ─── wkhtmltopdf (for PDF reports/report cards) ───────────
RUN wget -q https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.bookworm_amd64.deb && \
    apt-get update && \
    apt-get install -y ./wkhtmltox_0.12.6.1-3.bookworm_amd64.deb && \
    rm wkhtmltox_0.12.6.1-3.bookworm_amd64.deb && \
    rm -rf /var/lib/apt/lists/*

# ─── Create frappe user ───────────────────────────────────
RUN useradd -ms /bin/bash frappe
USER frappe

# ─── Set up frappe-bench ──────────────────────────────────
WORKDIR /home/frappe

# ─── Install bench CLI ────────────────────────────────────
RUN pip install --user frappe-bench

ENV PATH="/home/frappe/.local/bin:${PATH}"

# ─── Initialize bench ─────────────────────────────────────
RUN bench init \
    --frappe-path ${FRAPPE_PATH} \
    --frappe-branch ${FRAPPE_BRANCH} \
    --skip-redis-config-generation \
    --skip-assets \
    frappe-bench

WORKDIR /home/frappe/frappe-bench

# ─── Write apps.json ──────────────────────────────────────
RUN echo "${APPS_JSON_BASE64}" | base64 -d > /tmp/apps.json

# ─── Install all apps from apps.json ──────────────────────
RUN cat <<'EOF' > /tmp/install_apps.py
import sys
import json
import subprocess

apps = json.load(sys.stdin)
for app in apps:
    url = app['url']
    branch = app.get('branch', 'main')
    app_name = url.rstrip('/').split('/')[-1]
    print(f'Installing {app_name} from {url} ({branch})')
    result = subprocess.run(
        ['bench', 'get-app', '--branch', branch, url],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print(f'ERROR: {result.stderr}')
        sys.exit(1)
    print(f'✓ {app_name} installed')
EOF
RUN cat /tmp/apps.json | python3 /tmp/install_apps.py

# ─── Build frontend assets (production) ───────────────────
RUN bench build \
    --production \
    --hard-link

# ─── Set correct permissions ──────────────────────────────
RUN find /home/frappe/frappe-bench -not -path '*/\.*' -not -path '*/node_modules/*' \
    -exec chmod o+r {} \; 2>/dev/null || true

##############################################################
# PRODUCTION IMAGE — Nginx frontend
##############################################################
FROM nginx:1.25-alpine AS frontend

# Copy built assets
COPY --from=base --chown=nginx:nginx \
    /home/frappe/frappe-bench/sites /home/frappe/frappe-bench/sites

COPY --from=base --chown=nginx:nginx \
    /home/frappe/frappe-bench/apps/frappe/frappe/public \
    /home/frappe/frappe-bench/apps/frappe/frappe/public

# Nginx config for ERPNext
COPY config/nginx/nginx.conf /etc/nginx/nginx.conf
COPY config/nginx/frappe.conf /etc/nginx/conf.d/default.conf

EXPOSE 8080

##############################################################
# PRODUCTION IMAGE — Backend (gunicorn)
##############################################################
FROM base AS backend

# Expose gunicorn port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=5 --start-period=60s \
    CMD curl -f http://localhost:8000/api/method/ping || exit 1

CMD ["gunicorn", \
     "--chdir=/home/frappe/frappe-bench/sites", \
     "--bind=0.0.0.0:8000", \
     "--workers=4", \
     "--worker-class=gthread", \
     "--threads=4", \
     "--timeout=120", \
     "--keep-alive=5", \
     "--max-requests=2000", \
     "--max-requests-jitter=200", \
     "--log-level=warning", \
     "--error-logfile=-", \
     "--access-logfile=-", \
     "frappe.app:application"]
