$OpsTrailIntegration = @'

# OpsTrail - Terminal Activity Tracker Integration
$global:OpsTrailSessionStarted = $false

if (-not $global:OpsTrailSessionStarted) {
    & trail log --session-start 2>$null
    $global:OpsTrailSessionStarted = $true
}

function global:OpsTrail-LogCommand {
    $lastCmd = Get-History -Count 1 -ErrorAction SilentlyContinue
    if ($lastCmd) {
        $cmd = $lastCmd.CommandLine
        if ($cmd -like "trail *" -or $cmd -like "opstrail *" -or $cmd -like "*OpsTrail*") {
            return
        }
        $cwd = $PWD.Path
        & trail log --cmd "$cmd" --cwd "$cwd" 2>$null
    }
}

$global:OpsTrail_OriginalPrompt = $function:prompt

function global:prompt {
    OpsTrail-LogCommand
    & $global:OpsTrail_OriginalPrompt
}

$global:OpsTrail_TrailPath = (Get-Command trail -ErrorAction SilentlyContinue).Source
if (-not $global:OpsTrail_TrailPath) {
    $global:OpsTrail_TrailPath = (Get-Command trail.exe -ErrorAction SilentlyContinue).Source
}

$exitAction = [scriptblock]::Create(@"
    try {
        `$trailPath = '$($global:OpsTrail_TrailPath)'
        if (`$trailPath -and (Test-Path `$trailPath)) {
            & `$trailPath log --session-end
        } else {
            & trail log --session-end 2>`$null
        }
    } catch {}
"@)

Register-EngineEvent PowerShell.Exiting -Action $exitAction | Out-Null

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

function global:trail-resume {
    $fullOutput = & trail resume 2>&1
    $lines = $fullOutput -split "`n"
    $path = $lines | Select-Object -Last 1
    $info = $lines | Select-Object -SkipLast 1

    Write-Host ($info -join "`n")

    if ($path -and (Test-Path $path)) {
        Write-Host ""
        $response = Read-Host "Jump to this location? (y/n)"
        if ($response -eq 'y' -or $response -eq 'Y') {
            Set-Location $path
            Write-Host "Resumed at: $path" -ForegroundColor Green
        }
    }
}

function global:trail {
    param(
        [Parameter(Position=0)]
        [string]$subcommand,

        [Parameter(Position=1, ValueFromRemainingArguments=$true)]
        [string[]]$remainingArgs
    )

    if ($subcommand -eq "back" -and $remainingArgs.Count -gt 0) {
        $when = $remainingArgs[0]
        $configPath = Join-Path $env:USERPROFILE ".opstrail\config.json"
        $autoCdEnabled = $true

        if (Test-Path $configPath) {
            try {
                $config = Get-Content $configPath | ConvertFrom-Json
                if ($null -ne $config.auto_cd -and $null -ne $config.auto_cd.back) {
                    $autoCdEnabled = $config.auto_cd.back
                }
            } catch {}
        }

        if ($autoCdEnabled) {
            $rawOutput = & trail.exe back $when 2>$null
            $path = ($rawOutput -split "`n" | Select-Object -Last 1).Trim()

            if ($LASTEXITCODE -eq 0 -and $path -and (Test-Path $path)) {
                Set-Location $path
                Write-Host "Jumped back $when to: $path" -ForegroundColor Green
            } else {
                Write-Host "No activity found for '$when'" -ForegroundColor Red
            }
        } else {
            & trail.exe back $when
        }
        return
    }

    if ($subcommand -eq "resume") {
        $configPath = Join-Path $env:USERPROFILE ".opstrail\config.json"
        $autoCdEnabled = $true

        if (Test-Path $configPath) {
            try {
                $config = Get-Content $configPath | ConvertFrom-Json
                if ($null -ne $config.auto_cd -and $null -ne $config.auto_cd.resume) {
                    $autoCdEnabled = $config.auto_cd.resume
                }
            } catch {}
        }

        if ($autoCdEnabled) {
            $fullOutput = & trail.exe resume 2>&1
            $lines = $fullOutput -split "`n"
            $path = ($lines | Select-Object -Last 1).Trim()
            $info = $lines | Select-Object -SkipLast 1

            Write-Host ($info -join "`n")

            if ($path -and (Test-Path $path)) {
                Write-Host ""
                $response = Read-Host "Jump to this location? (y/n)"
                if ($response -eq 'y' -or $response -eq 'Y') {
                    Set-Location $path
                    Write-Host "Resumed at: $path" -ForegroundColor Green
                }
            }
        } else {
            & trail.exe resume
        }
        return
    }

    & trail.exe $subcommand @remainingArgs
}

Write-Host "OpsTrail tracking enabled" -ForegroundColor Cyan
'@

if (-not (Test-Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
    Write-Host "Created PowerShell profile at: $PROFILE" -ForegroundColor Green
}

$profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue

if ($profileContent -like "*OpsTrail*") {
    Write-Host "OpsTrail integration is already installed!" -ForegroundColor Yellow
    $response = Read-Host "Do you want to reinstall? (y/N)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        exit
    }
    $profileContent = $profileContent -replace '(?s)# OpsTrail.*?Write-Host.*OpsTrail tracking enabled.*?\n', ''
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
