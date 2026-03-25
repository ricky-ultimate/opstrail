$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$IntegrationSource = Join-Path $ScriptDir "assets\integration.ps1"

if (-not (Test-Path $IntegrationSource)) {
    Write-Host "Error: assets\integration.ps1 not found. Run this script from the extracted archive." -ForegroundColor Red
    exit 1
}

$OpsTrailIntegration = Get-Content $IntegrationSource -Raw

if (-not (Test-Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
    Write-Host "Created PowerShell profile at: $PROFILE" -ForegroundColor Green
}

$profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue

if ($profileContent -like "*OpsTrail - Terminal Activity Tracker*") {
    Write-Host "OpsTrail integration is already installed!" -ForegroundColor Yellow
    $response = Read-Host "Do you want to reinstall? (y/N)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        exit
    }
    $profileContent = $profileContent -replace '(?s)# OpsTrail - Terminal Activity Tracker Integration.*?Write-Host.*?OpsTrail tracking enabled.*?(\r?\n|$)', ''
    Set-Content $PROFILE $profileContent.Trim()
}

Add-Content $PROFILE "`n$OpsTrailIntegration"

Write-Host ""
Write-Host "OpsTrail PowerShell integration installed!" -ForegroundColor Green
Write-Host ""
Write-Host "Reload your profile to activate:" -ForegroundColor Cyan
Write-Host "  . `$PROFILE" -ForegroundColor Yellow
Write-Host ""
Write-Host "Useful commands:" -ForegroundColor Cyan
Write-Host "  trail today                      - Today summary" -ForegroundColor White
Write-Host "  trail timeline                   - View activity timeline" -ForegroundColor White
Write-Host "  trail stats                      - Activity statistics (last 30 days)" -ForegroundColor White
Write-Host "  trail stats --week               - This week" -ForegroundColor White
Write-Host "  trail stats --month              - This month" -ForegroundColor White
Write-Host "  trail search <term>              - Search your history" -ForegroundColor White
Write-Host "  trail back 1h                    - Where was I an hour ago" -ForegroundColor White
Write-Host "  trail resume                     - Resume last session" -ForegroundColor White
Write-Host "  trail note <text>                - Add a note" -ForegroundColor White
Write-Host "  trail config show                - View configuration" -ForegroundColor White
Write-Host "  trail config set <key> <value>   - Change a setting" -ForegroundColor White
Write-Host "  trail prune                      - Remove events older than 90 days" -ForegroundColor White
Write-Host "  trail prune --dry-run            - Preview what would be pruned" -ForegroundColor White
Write-Host ""
