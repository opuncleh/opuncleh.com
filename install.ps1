# Opuncleh Installer for Windows
# Usage: powershell -c "irm https://opuncleh.com/install.ps1 | iex"

param(
    [string]$Tag = "latest",
    [ValidateSet("npm", "git")]
    [string]$InstallMethod = "git",
    [string]$GitDir,
    [switch]$NoOnboard,
    [switch]$NoGitUpdate,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "  🦞 Opuncleh Installer" -ForegroundColor Cyan
Write-Host "  da lobster haz arived on ur windows masheen" -ForegroundColor Gray
Write-Host ""

# Check if running in PowerShell
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host "Error: PowerShell 5+ required" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Windows detected" -ForegroundColor Green

if (-not $PSBoundParameters.ContainsKey("InstallMethod")) {
    if (-not [string]::IsNullOrWhiteSpace($env:OPUNCLEH_INSTALL_METHOD)) {
        $InstallMethod = $env:OPUNCLEH_INSTALL_METHOD
    }
}
if (-not $PSBoundParameters.ContainsKey("GitDir")) {
    if (-not [string]::IsNullOrWhiteSpace($env:OPUNCLEH_GIT_DIR)) {
        $GitDir = $env:OPUNCLEH_GIT_DIR
    }
}
if (-not $PSBoundParameters.ContainsKey("NoOnboard")) {
    if ($env:OPUNCLEH_NO_ONBOARD -eq "1") {
        $NoOnboard = $true
    }
}
if (-not $PSBoundParameters.ContainsKey("NoGitUpdate")) {
    if ($env:OPUNCLEH_GIT_UPDATE -eq "0") {
        $NoGitUpdate = $true
    }
}
if (-not $PSBoundParameters.ContainsKey("DryRun")) {
    if ($env:OPUNCLEH_DRY_RUN -eq "1") {
        $DryRun = $true
    }
}

if ([string]::IsNullOrWhiteSpace($GitDir)) {
    $userHome = [Environment]::GetFolderPath("UserProfile")
    $GitDir = (Join-Path $userHome "opuncleh")
}

# Check for Node.js
function Check-Node {
    try {
        $nodeVersion = (node -v 2>$null)
        if ($nodeVersion) {
            $version = [int]($nodeVersion -replace 'v(\d+)\..*', '$1')
            if ($version -ge 22) {
                Write-Host "[OK] Node.js $nodeVersion found" -ForegroundColor Green
                return $true
            } else {
                Write-Host "[!] Node.js $nodeVersion found, but v22+ required" -ForegroundColor Yellow
                return $false
            }
        }
    } catch {
        Write-Host "[!] Node.js not found" -ForegroundColor Yellow
        return $false
    }
    return $false
}

# Install Node.js
function Install-Node {
    Write-Host "[*] Installing Node.js..." -ForegroundColor Yellow

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "  Using winget..." -ForegroundColor Gray
        winget install OpenJS.NodeJS.LTS --source winget --accept-package-agreements --accept-source-agreements
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        if (Check-Node) {
            Write-Host "[OK] Node.js installed via winget" -ForegroundColor Green
            return
        }
        Write-Host "[!] winget completed, but Node.js is still unavailable in this shell" -ForegroundColor Yellow
        Write-Host "Restart PowerShell and re-run the installer." -ForegroundColor Yellow
        exit 1
    }

    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Host "  Using Chocolatey..." -ForegroundColor Gray
        choco install nodejs-lts -y
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        Write-Host "[OK] Node.js installed via Chocolatey" -ForegroundColor Green
        return
    }

    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        Write-Host "  Using Scoop..." -ForegroundColor Gray
        scoop install nodejs-lts
        Write-Host "[OK] Node.js installed via Scoop" -ForegroundColor Green
        return
    }

    Write-Host ""
    Write-Host "Error: Could not find a package manager (winget, choco, or scoop)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install Node.js 22+ manually:" -ForegroundColor Yellow
    Write-Host "  https://nodejs.org/en/download/" -ForegroundColor Cyan
    exit 1
}

function Check-Git {
    try {
        $null = Get-Command git -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Install-Git {
    Write-Host "[*] Installing Git..." -ForegroundColor Yellow

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install Git.Git --source winget --accept-package-agreements --accept-source-agreements
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        return
    }

    if (Get-Command choco -ErrorAction SilentlyContinue) {
        choco install git -y
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        return
    }

    Write-Host "Please install Git manually: https://git-scm.com/download/win" -ForegroundColor Yellow
    exit 1
}

function Install-Pnpm {
    Write-Host "[*] Installing pnpm..." -ForegroundColor Yellow
    npm install -g pnpm
    Write-Host "[OK] pnpm installed" -ForegroundColor Green
}

function Check-Pnpm {
    try {
        $null = Get-Command pnpm -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# Main installation
Write-Host ""
Write-Host "Install plan" -ForegroundColor Cyan
Write-Host "  OS: Windows"
Write-Host "  Install method: $InstallMethod"
Write-Host "  Git directory: $GitDir"
Write-Host ""

# Step 1: Check/Install Node.js
Write-Host "[1/3] Preparing environment" -ForegroundColor Cyan
if (-not (Check-Node)) {
    Install-Node
    if (-not (Check-Node)) {
        Write-Host "Failed to install Node.js" -ForegroundColor Red
        exit 1
    }
}

# Step 2: Install Opuncleh
Write-Host ""
Write-Host "[2/3] Installing Opuncleh" -ForegroundColor Cyan

if ($InstallMethod -eq "git") {
    if (-not (Check-Git)) {
        Install-Git
    }
    Write-Host "[OK] Git found" -ForegroundColor Green

    if (-not (Check-Pnpm)) {
        Install-Pnpm
    }
    Write-Host "[OK] pnpm ready" -ForegroundColor Green

    if (Test-Path $GitDir) {
        Write-Host "[*] Updating existing checkout..." -ForegroundColor Yellow
        Push-Location $GitDir
        if (-not $NoGitUpdate) {
            git pull --ff-only
        }
    } else {
        Write-Host "[*] Cloning Opuncleh..." -ForegroundColor Yellow
        git clone https://github.com/opuncleh/opuncleh.git $GitDir
        Push-Location $GitDir
    }

    Write-Host "[*] Installing dependencies..." -ForegroundColor Yellow
    pnpm install

    Write-Host "[*] Building..." -ForegroundColor Yellow
    pnpm build

    # Create wrapper script
    $binDir = Join-Path $env:USERPROFILE ".local\bin"
    if (-not (Test-Path $binDir)) {
        New-Item -ItemType Directory -Path $binDir -Force | Out-Null
    }

    $wrapperPath = Join-Path $binDir "opuncleh.cmd"
    $wrapperContent = "@echo off`nnode `"$GitDir\dist\entry.js`" %*"
    Set-Content -Path $wrapperPath -Value $wrapperContent

    # Add to PATH if not already there
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath -notlike "*$binDir*") {
        [Environment]::SetEnvironmentVariable("Path", "$binDir;$userPath", "User")
        $env:Path = "$binDir;$env:Path"
        Write-Host "[OK] Added $binDir to PATH" -ForegroundColor Green
    }

    Pop-Location
    Write-Host "[OK] Opuncleh installed from source" -ForegroundColor Green
}

# Step 3: Finalize
Write-Host ""
Write-Host "[3/3] Finalizing setup" -ForegroundColor Cyan

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  🦞 Opuncleh installed successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Source: $GitDir"
Write-Host "Binary: $binDir\opuncleh.cmd"
Write-Host ""

if (-not $NoOnboard) {
    Write-Host "Starting onboarding..." -ForegroundColor Cyan
    & opuncleh onboard
} else {
    Write-Host "Run 'opuncleh onboard' to get started." -ForegroundColor Yellow
}
