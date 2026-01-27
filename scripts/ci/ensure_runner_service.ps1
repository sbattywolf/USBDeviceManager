<#
.SYNOPSIS
  Manage GitHub Actions self-hosted runner service/process on Windows.

.DESCRIPTION
  Detects whether the runner is installed as a Windows service (typical
  service name starts with actions.runner) or is running as a foreground
  `Runner.Listener` process (launched via run.cmd). Supports status/stop/start/restart.

.EXAMPLE
  .\ensure_runner_service.ps1 -Action status -RunnerDir C:\actions-runner

.EXAMPLE
  .\ensure_runner_service.ps1 -Action restart -RunnerDir C:\actions-runner
#>

[CmdletBinding()]
param(
    [ValidateSet('status','stop','start','restart')]
    [string]$Action = 'status',

    [string]$RunnerDir = (Get-Location).Path
)

Write-Host "ensure_runner_service: Action=$Action RunnerDir=$RunnerDir"

function Find-RunnerService {
    Get-Service -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like 'actions.runner*' -or $_.DisplayName -like '*actions.runner*' }
}

function Find-RunnerProcess {
    Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -eq 'Runner.Listener' -or $_.ProcessName -eq 'runner' }
}

$svc = Find-RunnerService
$proc = Find-RunnerProcess

switch ($Action) {
    'status' {
        if ($svc) {
            Write-Host "Found service:`n  Name: $($svc.Name)`n  DisplayName: $($svc.DisplayName)`n  Status: $($svc.Status)"
        } else {
            Write-Host "No actions.runner service found."
        }

        if ($proc) {
            $proc | Format-Table Id, ProcessName, CPU, StartTime -AutoSize
        } else {
            Write-Host "No Runner.Listener process found."
        }

        if (-not $svc -and -not $proc) {
            Write-Host "Runner not installed or not running. To start the runner interactively, run:"
            Write-Host "  cd $RunnerDir" -ForegroundColor Yellow
            Write-Host "  .\run.cmd" -ForegroundColor Yellow
        }
    }

    'stop' {
        if ($svc) {
            Write-Host "Stopping service $($svc.Name) ..."
            Stop-Service -Name $svc.Name -Force -ErrorAction Stop
            Write-Host "Service stopped."
        } elseif ($proc) {
            foreach ($p in $proc) {
                Write-Host "Stopping process Id=$($p.Id) Name=$($p.ProcessName) ..."
                Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
            }
            Write-Host "Process(es) stopped."
        } else {
            Write-Host "No service or process found to stop."
        }
    }

    'start' {
        if ($svc) {
            Write-Host "Starting service $($svc.Name) ..."
            Start-Service -Name $svc.Name -ErrorAction Stop
            Write-Host "Service started."
        } else {
            $runCmd = Join-Path -Path $RunnerDir -ChildPath 'run.cmd'
            if (Test-Path $runCmd) {
                Write-Host "No service found. Starting interactive runner via run.cmd (in new window)."
                Start-Process -FilePath $runCmd -WorkingDirectory $RunnerDir -WindowStyle Normal
                Write-Host "Started run.cmd (check its console)."
            } else {
                Write-Host "run.cmd not found in $RunnerDir. Ensure you passed the correct RunnerDir or copy this script into the runner folder."
            }
        }
    }

    'restart' {
        if ($svc) {
            Write-Host "Restarting service $($svc.Name) ..."
            Restart-Service -Name $svc.Name -Force -ErrorAction Stop
            Write-Host "Service restarted."
        } else {
            # stop any running process
            if ($proc) {
                foreach ($p in $proc) {
                    Write-Host "Stopping process Id=$($p.Id) Name=$($p.ProcessName) ..."
                    Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
                }
            }
            # start run.cmd if available
            $runCmd = Join-Path -Path $RunnerDir -ChildPath 'run.cmd'
            if (Test-Path $runCmd) {
                Write-Host "Starting interactive runner via run.cmd (in new window)."
                Start-Process -FilePath $runCmd -WorkingDirectory $RunnerDir -WindowStyle Normal
                Write-Host "Started run.cmd (check its console)."
            } else {
                Write-Host "run.cmd not found in $RunnerDir. If the runner should be a service, re-install it following GitHub's runner docs."
            }
        }
    }
}

Exit 0
