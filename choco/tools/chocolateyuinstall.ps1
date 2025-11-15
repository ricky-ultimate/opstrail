$ErrorActionPreference = 'Stop'

$packageName = 'opstrail'

Write-Host "Uninstalling OpsTrail..." -ForegroundColor Cyan

# End any active session
try {
    & trail log --session-end 2>$null
    Write-Host "✓ Ended active session" -ForegroundColor Green
} catch {
    # Silently continue if trail is not available
}

# Remove from PowerShell profile
$profilePaths = @(
    $PROFILE.CurrentUserAllHosts,
    $PROFILE.CurrentUserCurrentHost,
    $PROFILE.AllUsersAllHosts,
    $PROFILE.AllUsersCurrentHost
)

$removed = $false
foreach ($profilePath in $profilePaths) {
    if ($profilePath -and (Test-Path $profilePath)) {
        try {
            $content = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue

            if ($content -match 'OpsTrail.*Terminal Activity Tracker') {
                # Remove the entire OpsTrail integration block
                $pattern = '(?sm)^.*?# OpsTrail - Terminal Activity Tracker Integration.*?Write-Host.*OpsTrail tracking enabled.*?$'
                $newContent = $content -replace $pattern, ''

                # Clean up multiple blank lines
                $newContent = $newContent -replace '(\r?\n){3,}', "`n`n"
                $newContent = $newContent.Trim()

                if ($newContent) {
                    Set-Content $profilePath $newContent -NoNewline
                } else {
                    # If profile is now empty, remove it
                    Remove-Item $profilePath -Force
                }

                Write-Host "✓ Removed OpsTrail integration from: $profilePath" -ForegroundColor Green
                $removed = $true
            }
        } catch {
            Write-Warning "Could not modify profile: $profilePath"
        }
    }
}

if (-not $removed) {
    Write-Host "✓ No profile modifications found" -ForegroundColor Yellow
}

# Ask user if they want to keep their activity data
Write-Host ""
$dataDir = Join-Path $env:USERPROFILE ".opstrail"
if (Test-Path $dataDir) {
    Write-Host "Activity data directory found: $dataDir" -ForegroundColor Cyan
    Write-Host ""
    $response = Read-Host "Do you want to delete your activity history? (y/N)"

    if ($response -eq 'y' -or $response -eq 'Y') {
        try {
            Remove-Item $dataDir -Recurse -Force
            Write-Host "✓ Deleted activity data" -ForegroundColor Green
        } catch {
            Write-Warning "Could not delete activity data directory: $dataDir"
            Write-Warning "You may need to delete it manually"
        }
    } else {
        Write-Host "✓ Activity data preserved at: $dataDir" -ForegroundColor Green
        Write-Host "  You can safely delete this directory later if needed" -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  OpsTrail uninstalled successfully!" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Restart your PowerShell session to complete removal" -ForegroundColor White
Write-Host "  2. (Optional) Manually delete $dataDir if you kept it" -ForegroundColor White
Write-Host ""
Write-Host "Thank you for using OpsTrail!" -ForegroundColor Cyan
Write-Host ""
