##############################################################
# ERPNext School --- Windows PowerShell Deployment Script
# Equivalent of scripts/deploy.sh for Windows Docker Desktop
#
# Usage: PowerShell -ExecutionPolicy Bypass -File deploy.ps1
# Or in PowerShell: .\deploy.ps1
##############################################################

[CmdletBinding()]
param(
    [switch]$SkipBuild,
    [switch]$Help
)

# --------- Color functions ------------------------------------------------------------------------------------------------------------------
function Write-Info    { param($m) Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Write-Success { param($m) Write-Host "[OK]   $m" -ForegroundColor Green }
function Write-Warn    { param($m) Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Write-Err     { param($m) Write-Host "[ERR]  $m" -ForegroundColor Red }
function Write-Step    { param($m) Write-Host "`n--------- $m ---------" -ForegroundColor Magenta }

if ($Help) {
    Write-Host @"
ERPNext School --- Windows Deployment Script

Usage: .\deploy.ps1 [options]

Options:
  -SkipBuild    Skip Docker image build (use if image already built)
  -Help         Show this help message

Prerequisites:
  - Docker Desktop installed and running
  - WSL2 enabled
  - Git installed
  - .env file configured

"@
    exit 0
}

# --------- Banner ---------------------------------------------------------------------------------------------------------------------------------------------
Write-Host @"

  ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  ---  ERPNext School --- Windows Deployment                 ---
  ---  ERPNext v15 + Education + LMS + HRMS                ---
  ------------------------------------------------------------------------------------------------------------------------------------------------------------------------

"@ -ForegroundColor Cyan

# --------- STEP 0: Pre-flight checks ------------------------------------------------------------------------------------
Write-Step "Pre-flight Checks"

# Check Docker
try {
    $dockerVersion = docker --version 2>&1
    Write-Success "Docker: $dockerVersion"
} catch {
    Write-Err "Docker not found. Install Docker Desktop from https://docker.com"
    exit 1
}

# Check Docker is running
try {
    docker info 2>&1 | Out-Null
    Write-Success "Docker daemon is running"
} catch {
    Write-Err "Docker is not running. Start Docker Desktop."
    exit 1
}

# Check .env
if (-not (Test-Path ".env")) {
    Write-Err ".env file not found. Copy .env from this directory and configure."
    exit 1
}
Write-Success ".env file found"

# --------- STEP 1: Create data directories ---------------------------------------------------------------
Write-Step "Creating Data Directories"

$dirs = @(
    "data\sites",
    "data\sites\assets",
    "data\logs",
    "data\mariadb",
    "data\redis-queue",
    "data\backups",
    "data\backups\database",
    "data\backups\files",
    "data\backups\logs"
)

foreach ($dir in $dirs) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Success "Created: $dir"
    } else {
        Write-Info "Exists: $dir"
    }
}

# --------- STEP 2: Build Docker image ---------------------------------------------------------------------------------
if (-not $SkipBuild) {
    Write-Step "Building Docker Image (15-30 minutes)"
    Write-Warn "This downloads and compiles all dependencies --- be patient!"

    # Read apps.json and encode to base64
    $appsJson = Get-Content "apps.json" -Raw
    $appsBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($appsJson))

    # Read .env for image name
    $envContent = Get-Content ".env" | Where-Object { $_ -match "^[A-Z]" }
    $customImage = ($envContent | Where-Object { $_ -match "^CUSTOM_IMAGE=" }) -replace "CUSTOM_IMAGE=", ""
    $customTag = ($envContent | Where-Object { $_ -match "^CUSTOM_TAG=" }) -replace "CUSTOM_TAG=", ""

    if (-not $customImage) { $customImage = "school-erpnext" }
    if (-not $customTag) { $customTag = "v15.109.3" }

    Write-Info "Building: ${customImage}:${customTag}"

    docker build `
        "--build-arg=FRAPPE_PATH=https://github.com/frappe/frappe" `
        "--build-arg=FRAPPE_BRANCH=version-15" `
        "--build-arg=PYTHON_VERSION=3.11.9" `
        "--build-arg=NODE_VERSION=22.0.0" `
        "--build-arg=APPS_JSON_BASE64=$appsBase64" `
        "--tag=${customImage}:${customTag}" `
        "--tag=${customImage}:latest" `
        "--file=Containerfile" `
        "--progress=plain" `
        "."

    if ($LASTEXITCODE -ne 0) {
        Write-Err "Image build failed. Check logs above."
        exit 1
    }
    Write-Success "Image built: ${customImage}:${customTag}"
} else {
    Write-Warn "Skipping build (--SkipBuild flag set)"
}

# --------- STEP 3: Start infrastructure ---------------------------------------------------------------------------
Write-Step "Starting Infrastructure (DB + Redis)"
docker compose up -d db redis-cache redis-queue redis-socketio

Write-Info "Waiting for MariaDB (up to 2 minutes)..."
$maxWait = 120; $waited = 0
do {
    Start-Sleep -Seconds 5
    $waited += 5
    $result = docker compose exec db mysqladmin ping --silent 2>&1
    if ($waited % 15 -eq 0) { Write-Info "Still waiting... ${waited}s" }
} while ($result -notmatch "mysqld is alive" -and $waited -lt $maxWait)

if ($result -notmatch "mysqld is alive") {
    Write-Err "MariaDB not ready after ${maxWait}s"
    exit 1
}
Write-Success "MariaDB is ready"

Start-Sleep -Seconds 5
Write-Success "Redis services started"

# --------- STEP 4: Run configurator ---------------------------------------------------------------------------------------
Write-Step "Running Configurator"
docker compose up configurator
Write-Success "Configuration written"

# --------- STEP 5: Start all services ---------------------------------------------------------------------------------
Write-Step "Starting All Services"
docker compose up -d

Write-Info "Waiting for backend to be ready (up to 3 minutes)..."
$maxWait = 180; $waited = 0
do {
    Start-Sleep -Seconds 5
    $waited += 5
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8000/api/method/ping" -TimeoutSec 5 -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) { break }
    } catch {}
    if ($waited % 30 -eq 0) { Write-Info "Still waiting... ${waited}s" }
} while ($waited -lt $maxWait)

Write-Success "Backend is ready"

# --------- STEP 6: Install ERPNext ------------------------------------------------------------------------------------------
Write-Step "Installing ERPNext and School Apps"

# Read env values
$envLines = Get-Content ".env"
$siteName = ($envLines | Where-Object { $_ -match "^SITE_NAME=" }) -replace "SITE_NAME=", ""
$adminPass = ($envLines | Where-Object { $_ -match "^ADMIN_PASSWORD=" }) -replace "ADMIN_PASSWORD=", ""
$dbRootPass = ($envLines | Where-Object { $_ -match "^MARIADB_ROOT_PASSWORD=" }) -replace "MARIADB_ROOT_PASSWORD=", ""

if (-not $siteName) { $siteName = "school.localhost" }

Write-Info "Creating site: $siteName"

# Create site
docker compose exec backend bench new-site $siteName `
    --db-host db `
    --db-port 3306 `
    --db-root-username root `
    "--db-root-password=$dbRootPass" `
    "--admin-password=$adminPass" `
    --no-mariadb-socket `
    --mariadb-user-host-login-scope='%' `
    --force

Write-Success "Site created: $siteName"

# Install apps in order
$apps = @("erpnext", "payments", "hrms", "education", "lms")
foreach ($app in $apps) {
    Write-Info "Installing: $app"
    docker compose exec backend bench --site $siteName install-app $app
    Write-Success "$app installed"
}

# Run migrations
Write-Info "Running migrations..."
docker compose exec backend bench --site $siteName migrate
Write-Success "Migrations complete"

# Enable scheduler
docker compose exec backend bench --site $siteName enable-scheduler

# Clear cache
docker compose exec backend bench --site $siteName clear-cache

# --------- STEP 7: Show status ------------------------------------------------------------------------------------------------------
Write-Step "Deployment Status"
docker compose ps

Write-Host @"

  ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  ---   Deployment Complete! ----                            ---
  ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  ---                                                      ---
  ---  URL:      http://localhost:8080                     ---
  ---  Username: Administrator                             ---
  ---  Password: (see ADMIN_PASSWORD in .env)              ---
  ---                                                      ---
  ---  Next: Set up Cloudflare Tunnel                      ---
  ---    bash scripts/setup-cloudflare.sh                  ---
  ---                                                      ---
  ---  Monitor: .\health-check.ps1                         ---
  ------------------------------------------------------------------------------------------------------------------------------------------------------------------------

"@ -ForegroundColor Green

