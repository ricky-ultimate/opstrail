$ErrorActionPreference = 'Stop'

$packageName = 'opstrail'
$toolsDir    = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$url64       = 'https://github.com/ricky-ultimate/opstrail/releases/download/v0.1.3/opstrail-windows-x86_64.zip'

$packageArgs = @{
  packageName    = $packageName
  unzipLocation  = $toolsDir
  url64bit       = $url64
  checksum64     = 'PUT_ACTUAL_SHA256_HERE'
  checksumType64 = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs

$extractedExe = Get-ChildItem -Path $toolsDir -Filter "trail.exe" -Recurse | Select-Object -First 1
if ($extractedExe -and $extractedExe.DirectoryName -ne $toolsDir) {
    Move-Item -Path $extractedExe.FullName -Destination $toolsDir -Force
}

$trailPath = Join-Path $toolsDir "trail.exe"
if (-not (Test-Path $trailPath)) {
    throw "trail.exe not found after installation"
}

$integrationSource = Join-Path $toolsDir "integration.ps1"
if (-not (Test-Path $integrationSource)) {
    throw "integration.ps1 not found in package tools directory"
}

$OpsTrailIntegration = Get-Content $integrationSource -Raw

$profilePath = $PROFILE.CurrentUserAllHosts
if (-not $profilePath) { $profilePath = $PROFILE }

$profileDir = Split-Path -Parent $profilePath
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

if (Test-Path $profilePath) {
    $content = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
    if ($content -notmatch '# OpsTrail - Terminal Activity Tracker Integration') {
        Add-Content $profilePath "`n$OpsTrailIntegration"
        Write-Host "Added OpsTrail integration to PowerShell profile" -ForegroundColor Green
    } else {
        Write-Host "OpsTrail integration already exists in profile" -ForegroundColor Yellow
    }
} else {
    New-Item -ItemType File -Path $profilePath -Force | Out-Null
    Set-Content $profilePath $OpsTrailIntegration
    Write-Host "Created PowerShell profile with OpsTrail integration" -ForegroundColor Green
}

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
