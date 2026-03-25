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
