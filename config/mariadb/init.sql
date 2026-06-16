-- MariaDB Initialization Script
-- Runs once when container is first created
-- File: /docker-entrypoint-initdb.d/init.sql

-- ─── Ensure proper character set ─────────────────────────
SET NAMES utf8mb4;
SET CHARACTER SET utf8mb4;

-- ─── Configure root user ──────────────────────────────────
-- Allow root from any host (needed for bench site creation)
ALTER USER IF EXISTS 'root'@'localhost' IDENTIFIED BY 'Root@School2026!SecurePass';
CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY 'Root@School2026!SecurePass';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;

-- ─── Create frappe user ───────────────────────────────────
CREATE USER IF NOT EXISTS 'frappe'@'%' IDENTIFIED BY 'Frappe@School2026!';

-- ─── Create default database placeholder ──────────────────
-- Frappe will create the actual site database automatically
CREATE DATABASE IF NOT EXISTS `_frappe_site`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

GRANT ALL PRIVILEGES ON `_frappe_site`.* TO 'frappe'@'%';

-- ─── Allow Frappe to create site databases ────────────────
GRANT ALL PRIVILEGES ON `school_%`.* TO 'frappe'@'%';
GRANT ALL PRIVILEGES ON `_frappe_%`.* TO 'frappe'@'%';

-- ─── Performance tuning ───────────────────────────────────
SET GLOBAL innodb_buffer_pool_size = 2*1024*1024*1024;

-- ─── Flush privileges ─────────────────────────────────────
FLUSH PRIVILEGES;

-- ─── Log initialization ───────────────────────────────────
SELECT 'ERPNext School Database Initialized Successfully' AS status;
SELECT NOW() AS initialized_at;
