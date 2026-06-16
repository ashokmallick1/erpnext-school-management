# syntax=docker/dockerfile:1
##############################################################
# Custom ERPNext School Image
# Includes: ERPNext + Frappe Education + Frappe LMS + HRMS
# Base: frappe/base:15 → official Frappe base image
# Build: docker build -t school-erpnext:v15 .
##############################################################

FROM frappe/base:15 AS builder

# ─── App definitions ──────────────────────────────────────
# These versions are pinned. Update only after testing.
ARG ERPNEXT_VERSION=v15.68.1
ARG EDUCATION_VERSION=v1.0.0
ARG LMS_VERSION=v1.0.0
ARG HRMS_VERSION=v15.28.0
ARG PAYMENTS_VERSION=v0.0.2

USER frappe
WORKDIR /home/frappe/frappe-bench

# ─── Install bench CLI ────────────────────────────────────
RUN pip install frappe-bench

# ─── Initialize bench ─────────────────────────────────────
RUN bench init \
    --frappe-branch version-15 \
    --skip-redis-config-generation \
    --verbose \
    /home/frappe/frappe-bench

WORKDIR /home/frappe/frappe-bench

# ─── Get ERPNext ──────────────────────────────────────────
RUN bench get-app \
    --branch version-15 \
    erpnext \
    https://github.com/frappe/erpnext

# ─── Get Payments (dependency) ────────────────────────────
RUN bench get-app \
    --branch version-15 \
    payments \
    https://github.com/frappe/payments

# ─── Get HRMS ─────────────────────────────────────────────
RUN bench get-app \
    --branch version-15 \
    hrms \
    https://github.com/frappe/hrms

# ─── Get Frappe Education ─────────────────────────────────
RUN bench get-app \
    --branch main \
    education \
    https://github.com/frappe/education

# ─── Get Frappe LMS ───────────────────────────────────────
RUN bench get-app \
    --branch main \
    lms \
    https://github.com/frappe/lms

# ─── Production build ─────────────────────────────────────
RUN bench build --production

##############################################################
# Final production image
##############################################################
FROM frappe/frappe-nginx:${ERPNEXT_VERSION} AS frontend

COPY --from=builder /home/frappe/frappe-bench/sites /home/frappe/frappe-bench/sites
COPY --from=builder /home/frappe/frappe-bench/apps /home/frappe/frappe-bench/apps

##############################################################
# Worker image
##############################################################
FROM frappe/frappe-worker:${ERPNEXT_VERSION} AS backend

COPY --from=builder /home/frappe/frappe-bench /home/frappe/frappe-bench

WORKDIR /home/frappe/frappe-bench
USER frappe
