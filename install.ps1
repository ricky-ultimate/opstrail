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
Register-EngineEvent PowerShell.Exiting -Action {
    & trail log --session-end 2>$null
}

# Helper function: Jump back in time
function trail-back {
    param([string]$when = "30m")
    $path = & trail back $when
    if ($path -and (Test-Path $path)) {
        Set-Location $path
        Write-Host "Jumped back to: $path" -ForegroundColor Green
    }
}

# Helper function: Resume last session
function trail-resume {
    $output = & trail resume
    Write-Host $output

    # Extract path from resume output
    $pathLine = $output | Select-String -Pattern "Path: (.+)"
    if ($pathLine) {
        $path = $pathLine.Matches.Groups[1].Value.Trim()
        if (Test-Path $path) {
            $response = Read-Host "`nJump to this location? (y/n)"
            if ($response -eq 'y' -or $response -eq 'Y') {
                Set-Location $path
                Write-Host "Resumed at: $path" -ForegroundColor Green
            }
        }
    }
}

Write-Host "OpsTrail tracking enabled" -ForegroundColor Cyan
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
    $profileContent = $profileContent -replace '(?s)# OpsTrail.*?Write-Host "OpsTrail tracking enabled".*?\n', ''
    Set-Content $PROFILE $profileContent.Trim()
}

# Add integration
Add-Content $PROFILE "`n$OpsTrailIntegration"

Write-Host "`nOpsTrail PowerShell integration installed!" -ForegroundColor Green
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
