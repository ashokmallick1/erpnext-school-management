$ErrorActionPreference = "Stop"

Write-Host "Restoring Quorvia Golden State..."
Write-Host "---------------------------------"

# Ensure containers are running
docker compose up -d db backend

Write-Host "Waiting for database to be ready..."
Start-Sleep -Seconds 10

# Copy the dump into the db container
Write-Host "Injecting database dump..."
docker cp backups\golden_state\database.sql erpnext-school-db-1:/tmp/database.sql

# Restore the dump using the credentials from site_config.json
Write-Host "Restoring database schema and data..."
docker compose exec db bash -c "mysql -u _bd334df9d218bad6 -pxE1erZA7SaXSf9jl _bd334df9d218bad6 < /tmp/database.sql"

# Run migrations to ensure everything is perfect
Write-Host "Running Frappe migrations..."
docker compose exec backend bench --site school.localhost migrate

Write-Host "State restored successfully! Your Quorvia instance is identical to the Golden Snapshot."
