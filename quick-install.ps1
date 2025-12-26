#Requires -Version 5.1

<#
.SYNOPSIS
    Quick installer for OpsTrail - downloads and installs automatically
.DESCRIPTION
    Downloads the latest OpsTrail release, installs the binary, and configures
    PowerShell shell integration for activity tracking.
#>

param(
    [string]$Version = "latest"
)

$ErrorActionPreference = "Stop"

# Colors
function Write-Success { Write-Host $args -ForegroundColor Green }
function Write-Info { Write-Host $args -ForegroundColor Cyan }
function Write-Failure { Write-Host $args -ForegroundColor Red }
function Write-Warn { Write-Host $args -ForegroundColor Yellow }

$repo = "ricky-ultimate/opstrail"
$InstallDir = Join-Path $env:LOCALAPPDATA "opstrail"
$BinaryName = "trail.exe"
$BinaryPath = Join-Path $InstallDir $BinaryName

Write-Info "Installing OpsTrail..."

try {
    # Get latest release info
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

    # Download URL
    $downloadUrl = "https://github.com/$repo/releases/download/$Version/opstrail-$Version-x86_64-pc-windows-msvc.zip"
    $tempZip = Join-Path $env:TEMP "opstrail.zip"
    $tempExtract = Join-Path $env:TEMP "opstrail-extract"

    # Download
    Write-Info "Downloading from GitHub..."
    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempZip -UseBasicParsing
    } catch {
        throw "Failed to download binary. The release asset might be missing or named differently."
    }

    # Extract
    Write-Info "Extracting..."
    if (Test-Path $tempExtract) {
        Remove-Item $tempExtract -Recurse -Force
    }
    Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force

    # Find the binary (it might be in a nested folder based on the zip creation)
    $exePath = Get-ChildItem -Path $tempExtract -Filter $BinaryName -Recurse | Select-Object -First 1

    if (-not $exePath) {
        throw "Binary ($BinaryName) not found in downloaded archive"
    }

    # Create install directory
    if (-not (Test-Path $InstallDir)) {
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    }

    # Copy binary
    Copy-Item $exePath.FullName $BinaryPath -Force
    Write-Success "Installed binary to: $BinaryPath"

    # Add to PATH
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath -notlike "*$InstallDir*") {
        [Environment]::SetEnvironmentVariable("Path", "$userPath;$InstallDir", "User")
        $env:Path += ";$InstallDir"
        Write-Success "Added to PATH"
    } else {
        Write-Info "Already in PATH"
    }

    # --- Setup PowerShell profile ---
    Write-Info "Configuring PowerShell profile..."

    $profilePath = $PROFILE.CurrentUserAllHosts
    if (-not $profilePath) { $profilePath = $PROFILE }

    $integrationCode = @'

# OpsTrail - Terminal Activity Tracker Integration
$global:OpsTrailSessionStarted = $false

# Start session on profile load
if (-not $global:OpsTrailSessionStarted) {
    & trail log --session-start 2>$null
    $global:OpsTrailSessionStarted = $true
}

# Capture command history after execution
function global:OpsTrail-LogCommand {
    # Get the last command from history
    $lastCmd = Get-History -Count 1 -ErrorAction SilentlyContinue

    if ($lastCmd) {
        $cmd = $lastCmd.CommandLine

        # Skip trail commands to avoid recursion
        if ($cmd -like "trail *" -or $cmd -like "opstrail *" -or $cmd -like "*OpsTrail*") {
            return
        }

        $cwd = $PWD.Path

        # Log the command
        & trail log --cmd "$cmd" --cwd "$cwd" 2>$null
    }
}

# Wrap the prompt to log after each command
$global:OpsTrail_OriginalPrompt = $function:prompt

function global:prompt {
    OpsTrail-LogCommand
    & $global:OpsTrail_OriginalPrompt
}

# Register session end on exit
# Store trail path to ensure it's accessible during exit
$global:OpsTrail_TrailPath = (Get-Command trail -ErrorAction SilentlyContinue).Source
if (-not $global:OpsTrail_TrailPath) {
    $global:OpsTrail_TrailPath = (Get-Command trail.exe -ErrorAction SilentlyContinue).Source
}

# Create the action as a script block that captures the path
$exitAction = [scriptblock]::Create(@"
    try {
        `$trailPath = '$($global:OpsTrail_TrailPath)'
        if (`$trailPath -and (Test-Path `$trailPath)) {
            & `$trailPath log --session-end
        } else {
            & trail log --session-end 2>`$null
        }
    } catch {
        # Silently fail - we're exiting anyway
    }
"@)

Register-EngineEvent PowerShell.Exiting -Action $exitAction | Out-Null

# Helper function: Jump back in time
function global:trail-back {
    param([string]$when = "30m")
    $path = & trail back $when 2>$null
    if ($LASTEXITCODE -eq 0 -and $path -and (Test-Path $path)) {
        Set-Location $path
        Write-Host "Jumped back to: $path" -ForegroundColor Green
    } else {
        Write-Host "No activity found for that time" -ForegroundColor Red
    }
}

# Helper function: Resume last session
function global:trail-resume {
    $output = & trail resume 2>&1

    # Extract path from resume output
    $pathLine = $output | Select-String -Pattern "Path:\s*(.+)"

    if ($pathLine) {
        Write-Host $output
        $path = $pathLine.Matches.Groups[1].Value.Trim()

        if (Test-Path $path) {
            Write-Host ""
            $response = Read-Host "Jump to this location? (y/n)"
            if ($response -eq 'y' -or $response -eq 'Y') {
                Set-Location $path
                Write-Host "Resumed at: $path" -ForegroundColor Green
            }
        }
    } else {
        Write-Host $output
    }
}

# Override trail command to respect auto-cd config
function global:trail {
    param(
        [Parameter(Position=0)]
        [string]$subcommand,

        [Parameter(Position=1, ValueFromRemainingArguments=$true)]
        [string[]]$args
    )

    # For 'back' command, check config for auto-cd
    if ($subcommand -eq "back" -and $args.Count -gt 0) {
        $when = $args[0]

        # Check if auto-cd is enabled for 'back'
        $configPath = Join-Path $env:USERPROFILE ".opstrail\config.json"
        $autoCdEnabled = $true  # Default to true

        if (Test-Path $configPath) {
            try {
                $config = Get-Content $configPath | ConvertFrom-Json
                if ($null -ne $config.auto_cd -and $null -ne $config.auto_cd.back) {
                    $autoCdEnabled = $config.auto_cd.back
                }
            } catch {
                # If config parse fails, use default (true)
            }
        }

        if ($autoCdEnabled) {
            # Auto-cd enabled: change directory
            $path = & trail.exe back $when 2>$null

            if ($LASTEXITCODE -eq 0 -and $path -and (Test-Path $path)) {
                Set-Location $path
                Write-Host "Jumped back $when to: $path" -ForegroundColor Green
            } else {
                Write-Host "No activity found for '$when'" -ForegroundColor Red
            }
        } else {
            # Auto-cd disabled: just show the path
            & trail.exe back $when
        }
        return
    }

    # For 'resume' command, check config for auto-cd
    if ($subcommand -eq "resume") {
        # Check if auto-cd is enabled for 'resume'
        $configPath = Join-Path $env:USERPROFILE ".opstrail\config.json"
        $autoCdEnabled = $true  # Default to true

        if (Test-Path $configPath) {
            try {
                $config = Get-Content $configPath | ConvertFrom-Json
                if ($null -ne $config.auto_cd -and $null -ne $config.auto_cd.resume) {
                    $autoCdEnabled = $config.auto_cd.resume
                }
            } catch {
                # If config parse fails, use default (true)
            }
        }

        if ($autoCdEnabled) {
            # Auto-cd enabled: show output and prompt to jump
            $output = & trail.exe resume 2>&1
            $pathLine = $output | Select-String -Pattern "^[A-Z]:"

            if ($pathLine) {
                # Extract the last line which should be the path
                $path = $pathLine.Matches.Value | Select-Object -Last 1

                if (Test-Path $path) {
                    # Show the resume info first
                    $output | Where-Object { $_ -notmatch "^[A-Z]:" } | ForEach-Object { Write-Host $_ }

                    Write-Host ""
                    $response = Read-Host "Jump to this location? (y/n)"
                    if ($response -eq 'y' -or $response -eq 'Y') {
                        Set-Location $path
                        Write-Host "Resumed at: $path" -ForegroundColor Green
                    }
                } else {
                    Write-Host $output
                }
            } else {
                Write-Host $output
            }
        } else {
            # Auto-cd disabled: just show the output
            & trail.exe resume
        }
        return
    }

    # For all other commands, pass through to the real trail executable
    & trail.exe $subcommand @args
}

Write-Host "OpsTrail tracking enabled" -ForegroundColor Cyan
'@

    # Create profile directory if it doesn't exist
    $profileDir = Split-Path -Parent $profilePath
    if (-not (Test-Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }

    # Create profile file if it doesn't exist
    if (-not (Test-Path $profilePath)) {
        New-Item -ItemType File -Path $profilePath -Force | Out-Null
        Write-Success "Created PowerShell profile"
    }

    # Add or update function
    $profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue

    if ($profileContent -like "*OpsTrail*") {
        Write-Info "OpsTrail integration already exists in profile"
        $response = Read-Host "Replace with latest version? (y/N)"
        if ($response -eq "y" -or $response -eq "Y") {
            # Remove old block using Regex to match from Start header to End footer
            $pattern = '(?s)# OpsTrail.*?Write-Host.*OpsTrail tracking enabled.*'
            $profileContent = $profileContent -replace $pattern, ''
            $profileContent = $profileContent.Trim()
            Set-Content $profilePath "$profileContent`n$integrationCode"
            Write-Success "Updated PowerShell profile"
        }
    } else {
        Add-Content $profilePath "`n$integrationCode"
        Write-Success "Added OpsTrail integration to PowerShell profile"
    }

    # Cleanup
    Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
    Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue

    Write-Success "`n✓ Installation complete!"
    Write-Info "`nQuick start:"
    Write-Info "  1. Restart your terminal (or run: . `$PROFILE)"
    Write-Info "  2. OpsTrail will now track your commands automatically"
    Write-Info "  3. View timeline: trail timeline"
    Write-Info "  4. View stats: trail stats"
    Write-Info "  5. Jump back in time: trail back 30m"

} catch {
    Write-Failure "`nInstallation failed: $_"
    Write-Info "`nTry manual installation:"
    Write-Info "  1. Download from: https://github.com/$repo/releases"
    Write-Info "  2. Extract and run: .\install.ps1"
    exit 1
}
