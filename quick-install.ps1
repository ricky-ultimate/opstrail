#Requires -Version 5.1

param(
    [string]$Version = "latest"
)

$ErrorActionPreference = "Stop"

function Write-Success { Write-Host $args -ForegroundColor Green }
function Write-Info    { Write-Host $args -ForegroundColor Cyan }
function Write-Failure { Write-Host $args -ForegroundColor Red }

$repo        = "ricky-ultimate/opstrail"
$InstallDir  = Join-Path $env:LOCALAPPDATA "opstrail"
$BinaryName  = "trail.exe"
$BinaryPath  = Join-Path $InstallDir $BinaryName

Write-Info "Installing OpsTrail..."

try {
    if ($Version -eq "latest") {
        Write-Info "Fetching latest release..."
        try {
            $release = Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest"
            $Version = $release.tag_name
        } catch {
            throw "Failed to fetch latest release. Please check your internet connection."
        }
    }

    Write-Info "Installing version: $Version"

    $downloadUrl  = "https://github.com/$repo/releases/download/$Version/opstrail-windows-x86_64.zip"
    $tempZip      = Join-Path $env:TEMP "opstrail.zip"
    $tempExtract  = Join-Path $env:TEMP "opstrail-extract"

    Write-Info "Downloading from GitHub..."
    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempZip -UseBasicParsing
    } catch {
        throw "Failed to download binary. The release asset may be missing or named differently."
    }

    Write-Info "Extracting..."
    if (Test-Path $tempExtract) {
        Remove-Item $tempExtract -Recurse -Force
    }
    Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force

    $exePath = Get-ChildItem -Path $tempExtract -Filter $BinaryName -Recurse | Select-Object -First 1
    if (-not $exePath) {
        throw "Binary ($BinaryName) not found in downloaded archive."
    }

    if (-not (Test-Path $InstallDir)) {
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    }

    Copy-Item $exePath.FullName $BinaryPath -Force
    Write-Success "Installed binary to: $BinaryPath"

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath -notlike "*$InstallDir*") {
        [Environment]::SetEnvironmentVariable("Path", "$userPath;$InstallDir", "User")
        $env:Path += ";$InstallDir"
        Write-Success "Added to PATH"
    } else {
        Write-Info "Already in PATH"
    }

    Write-Info "Fetching shell integration..."
    $integrationUrl = "https://raw.githubusercontent.com/$repo/refs/tags/$Version/assets/integration.ps1"
    try {
        $OpsTrailIntegration = (Invoke-WebRequest -Uri $integrationUrl -UseBasicParsing).Content
    } catch {
        throw "Failed to download integration script from: $integrationUrl"
    }

    $profilePath = $PROFILE.CurrentUserAllHosts
    if (-not $profilePath) { $profilePath = $PROFILE }

    $profileDir = Split-Path -Parent $profilePath
    if (-not (Test-Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }

    if (-not (Test-Path $profilePath)) {
        New-Item -ItemType File -Path $profilePath -Force | Out-Null
        Write-Success "Created PowerShell profile"
    }

    $profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue

    if ($profileContent -like "*OpsTrail - Terminal Activity Tracker*") {
        Write-Info "OpsTrail integration already exists in profile"
        $response = Read-Host "Replace with latest version? (y/N)"
        if ($response -eq "y" -or $response -eq "Y") {
            $pattern = '(?s)# OpsTrail - Terminal Activity Tracker Integration.*?Write-Host.*?OpsTrail tracking enabled.*?(\r?\n|$)'
            $profileContent = $profileContent -replace $pattern, ''
            $profileContent = $profileContent.Trim()
            Set-Content $profilePath "$profileContent`n$OpsTrailIntegration"
            Write-Success "Updated PowerShell profile"
        }
    } else {
        Add-Content $profilePath "`n$OpsTrailIntegration"
        Write-Success "Added OpsTrail integration to PowerShell profile"
    }

    Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
    Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue

    Write-Success "Installation complete!"
    Write-Info ""
    Write-Info "Quick start:"
    Write-Info "  1. Restart your terminal (or run: . `$PROFILE)"
    Write-Info "  2. OpsTrail will now track your commands automatically"
    Write-Info "  3. View timeline: trail timeline"
    Write-Info "  4. View stats:    trail stats"
    Write-Info "  5. Jump back:     trail back 30m"

} catch {
    Write-Failure "Installation failed: $_"
    Write-Info ""
    Write-Info "Try manual installation:"
    Write-Info "  1. Download from: https://github.com/$repo/releases"
    Write-Info "  2. Extract and run: .\install.ps1"
    exit 1
}
