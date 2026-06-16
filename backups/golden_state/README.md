# Agent Instructions: Golden State Restoration

## Purpose
This repository contains the **Quorvia Institution Management Platform**, a heavily customized deployment of Frappe/ERPNext v15. 

If you are an AI Agent, Developer, or DevOps engineer taking over this repository, you must understand that the configuration, dashboards, custom DocTypes (Hostel Module, Transport Module), and AI Chat settings are stored **inside the MariaDB database**, not just the filesystem.

To guarantee that you are working with the fully customized Quorvia state (and not a blank ERPNext instance), a **Golden Snapshot** has been preserved in this directory.

## Golden State Assets
- `database.sql`: A raw `mysqldump` of the Frappe database `_bd334df9d218bad6`. This contains all the mock data, Portals, Workspaces, Notifications, and system hardening settings.
- `restore_state.ps1`: A PowerShell script located at the root of the repository.

## How to Restore the Environment

If the Docker volumes (`frappe-bench`, `mariadb-data`, etc.) are ever wiped, or if this repository is cloned onto a fresh machine, the ERPNext deployment will boot up completely blank. 

**DO NOT run standard Frappe setup scripts.** Instead, run the restoration script to inject the golden state:

```powershell
# From the root of the repository
./restore_state.ps1
```

### Manual Restoration Steps (If script fails)
If you need to restore the state manually via a terminal:

1. Bring up the database and backend:
   ```bash
   docker compose up -d db backend
   ```
2. Wait 10 seconds for MariaDB to initialize.
3. Copy the dump into the `db` container:
   ```bash
   docker cp backups/golden_state/database.sql erpnext-school-db-1:/tmp/database.sql
   ```
4. Inject the SQL using the site credentials (found in `sites/school.localhost/site_config.json`):
   ```bash
   docker compose exec db bash -c "mysql -u _bd334df9d218bad6 -pxE1erZA7SaXSf9jl _bd334df9d218bad6 < /tmp/database.sql"
   ```
5. Migrate the Frappe site to finalize schema alignments:
   ```bash
   docker compose exec backend bench --site school.localhost migrate
   ```

## Next Steps
Once restored, the system will instantly possess the AI Chat endpoints, the customized Parent/Student/Teacher portals, the Transport/Hostel architecture, and the enforced Security Policies (12-hour sessions, 2FA enabled). You may safely resume development or run integration tests.
