$ErrorActionPreference = 'Stop'

$packageName = 'opstrail'
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$url64 = 'https://github.com/ricky-ultimate/opstrail/releases/download/v0.1.0/opstrail-v0.1.0-x86_64-pc-windows-msvc.zip'

$packageArgs = @{
  packageName   = $packageName
  unzipLocation = $toolsDir
  url64bit      = $url64
  checksum64    = 'PUT_ACTUAL_SHA256_HERE'
  checksumType64= 'sha256'
}

Install-ChocolateyZipPackage @packageArgs

# After extraction, move trail.exe to tools directory root if it's in a subdirectory
$extractedDir = Get-ChildItem -Path $toolsDir -Directory | Where-Object { $_.Name -like "opstrail-*" } | Select-Object -First 1
if ($extractedDir) {
    $trailExe = Join-Path $extractedDir.FullName "trail.exe"
    if (Test-Path $trailExe) {
        Move-Item -Path $trailExe -Destination $toolsDir -Force
        Write-Host "Moved trail.exe to $toolsDir"
    }
}

# Verify trail.exe exists
$trailPath = Join-Path $toolsDir "trail.exe"
if (-not (Test-Path $trailPath)) {
    throw "trail.exe not found after installation"
}

# PowerShell Integration
$integrationScript = @'

# OpsTrail - Terminal Activity Tracker Integration
$global:OpsTrailSessionStarted = $false

# Start session on profile load
if (-not $global:OpsTrailSessionStarted) {
    & trail log --session-start 2>$null
    $global:OpsTrailSessionStarted = $true
}

# Capture command history after execution
function global:OpsTrail-LogCommand {
    $lastCmd = Get-History -Count 1 -ErrorAction SilentlyContinue

    if ($lastCmd) {
        $cmd = $lastCmd.CommandLine

        # Skip trail commands to avoid recursion
        if ($cmd -like "trail *" -or $cmd -like "opstrail *" -or $cmd -like "*OpsTrail*") {
            return
        }

        $cwd = $PWD.Path
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
# Use full path to ensure trail.exe is found during exit
$script:TrailExePath = (Get-Command trail.exe -ErrorAction SilentlyContinue).Source
if (-not $script:TrailExePath) {
    $script:TrailExePath = "trail.exe"
}

Register-EngineEvent PowerShell.Exiting -Action {
    try {
        if ($script:TrailExePath) {
            & $script:TrailExePath log --session-end
        } else {
            & trail.exe log --session-end
        }
    } catch {
        # Silently fail if trail is not accessible
    }
} | Out-Null

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

# Override trail command to auto-cd for back/resume
function global:trail {
    param(
        [Parameter(Position=0)]
        [string]$subcommand,

        [Parameter(Position=1, ValueFromRemainingArguments=$true)]
        [string[]]$args
    )

    # For 'back' command, automatically cd
    if ($subcommand -eq "back" -and $args.Count -gt 0) {
        $when = $args[0]
        $path = & trail.exe back $when 2>$null

        if ($LASTEXITCODE -eq 0 -and $path -and (Test-Path $path)) {
            Set-Location $path
            Write-Host "Jumped back $when to: $path" -ForegroundColor Green
        } else {
            Write-Host "No activity found for '$when'" -ForegroundColor Red
        }
        return
    }

    # For 'resume' command, show info and prompt to jump
    if ($subcommand -eq "resume") {
        $output = & trail.exe resume 2>&1
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
        return
    }

    # For all other commands, pass through to the real trail executable
    & trail.exe $subcommand @args
}

Write-Host "✓ OpsTrail tracking enabled" -ForegroundColor Cyan
'@

# Add integration to PowerShell profile
$profilePath = $PROFILE.CurrentUserAllHosts
if (-not $profilePath) {
    $profilePath = $PROFILE
}

# Create profile directory if it doesn't exist
$profileDir = Split-Path -Parent $profilePath
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

# Create or update profile
if (Test-Path $profilePath) {
    $content = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
    if ($content -notmatch 'OpsTrail.*Terminal Activity Tracker') {
        Add-Content $profilePath "`n$integrationScript"
        Write-Host "✓ Added OpsTrail integration to PowerShell profile" -ForegroundColor Green
    } else {
        Write-Host "✓ OpsTrail integration already exists in profile" -ForegroundColor Yellow
    }
} else {
    New-Item -ItemType File -Path $profilePath -Force | Out-Null
    Set-Content $profilePath $integrationScript
    Write-Host "✓ Created PowerShell profile with OpsTrail integration" -ForegroundColor Green
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  OpsTrail installed successfully!" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Restart your PowerShell session OR run: . `$PROFILE" -ForegroundColor White
Write-Host "  2. Start using trail commands!" -ForegroundColor White
Write-Host ""
Write-Host "Quick start commands:" -ForegroundColor Cyan
Write-Host "  trail today          - Today's activity summary" -ForegroundColor White
Write-Host "  trail timeline       - View activity timeline" -ForegroundColor White
Write-Host "  trail stats          - View statistics" -ForegroundColor White
Write-Host "  trail back 1h        - Jump back 1 hour" -ForegroundColor White
Write-Host "  trail-back 30m       - Jump back 30 minutes" -ForegroundColor White
Write-Host "  trail-resume         - Resume last session" -ForegroundColor White
Write-Host "  trail note <text>    - Add a note" -ForegroundColor White
Write-Host ""
Write-Host "Documentation: https://github.com/ricky-ultimate/opstrail" -ForegroundColor DarkGray
Write-Host ""
