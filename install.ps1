# OpsTrail PowerShell Integration Installer

$OpsTrailIntegration = @'

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

Register-EngineEvent PowerShell.Exiting -Action {
    try {
        if ($global:OpsTrail_TrailPath -and (Test-Path $global:OpsTrail_TrailPath)) {
            & $global:OpsTrail_TrailPath log --session-end
        } else {
            # Fallback to just calling trail
            & trail log --session-end 2>$null
        }
    } catch {
        # Silently fail - we're exiting anyway
    }
} -SupportEvent | Out-Null

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

# Check if profile exists
if (-not (Test-Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
    Write-Host "Created PowerShell profile at: $PROFILE" -ForegroundColor Green
}

# Check if already installed
$profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue

if ($profileContent -like "*OpsTrail*") {
    Write-Host "OpsTrail integration is already installed!" -ForegroundColor Yellow
    $response = Read-Host "Do you want to reinstall? (y/N)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        exit
    }

    # Remove old integration
    $profileContent = $profileContent -replace '(?s)# OpsTrail.*?Write-Host.*OpsTrail tracking enabled.*?\n', ''
    Set-Content $PROFILE $profileContent.Trim()
}

# Add integration
Add-Content $PROFILE "`n$OpsTrailIntegration"

Write-Host "`n✓ OpsTrail PowerShell integration installed!" -ForegroundColor Green
Write-Host "`nReload your profile to activate:" -ForegroundColor Cyan
Write-Host "  . `$PROFILE" -ForegroundColor Yellow
Write-Host "`nUseful commands:" -ForegroundColor Cyan
Write-Host "  trail today          - Today's summary" -ForegroundColor White
Write-Host "  trail timeline       - View activity timeline" -ForegroundColor White
Write-Host "  trail stats          - Activity statistics" -ForegroundColor White
Write-Host "  trail search <term>  - Search your history" -ForegroundColor White
Write-Host "  trail back 1h        - Where was I an hour ago?" -ForegroundColor White
Write-Host "  trail-back 30m       - Jump back 30 minutes" -ForegroundColor White
Write-Host "  trail-resume         - Resume last session" -ForegroundColor White
Write-Host "  trail note <text>    - Add a note" -ForegroundColor White
