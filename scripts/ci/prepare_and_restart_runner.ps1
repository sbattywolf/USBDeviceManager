<#
.SYNOPSIS
  Prepare and restart a GitHub Actions self-hosted runner with minimal operator action.

.DESCRIPTION
  - Checks for .NET 8 and, if missing, performs a non-admin install to C:\dotnet
    (when run without elevation) or calls the repo's `install_dotnet_on_runner.ps1`
    when running elevated.
  - Calls `ensure_runner_service.ps1` to restart the runner service or start the
    interactive `run.cmd` if a service is not present.
  - Writes logs to `C:\ci-artifacts\forensics\<timestamp>` for operator review.

.NOTES
  - For a system-wide install of .NET to `C:\Program Files\dotnet` you must
    run the `install_dotnet_on_runner.ps1` as Administrator.
#>

[CmdletBinding()]
param(
    [string]$RunnerDir = 'C:\actions-runner',
    [switch]$ForceDotnetInstall,
    [string]$DotnetUserInstallDir = 'C:\dotnet'
)

function Test-IsAdministrator {
    $current = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($current)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Write-Log($msg) {
    Write-Host $msg
    Add-Content -Path $Global:LogFile -Value ("$(Get-Date -Format o) `t $msg")
}

$stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
$forensics = "C:\ci-artifacts\forensics\$stamp"
New-Item -ItemType Directory -Path $forensics -Force | Out-Null
$Global:LogFile = Join-Path $forensics 'prepare_and_restart_runner.log'

Write-Log "prepare_and_restart_runner: RunnerDir=$RunnerDir ForceDotnetInstall=$ForceDotnetInstall"

# 1) Check dotnet
try {
    $sdks = & dotnet --list-sdks 2>$null
} catch {
    $sdks = $null
}

if ($sdks -and $sdks -match '^8\.') {
    Write-Log "Found .NET 8 SDK installed: $sdks"
} else {
    Write-Log "No .NET 8 SDK found on PATH."
    if (Test-IsAdministrator) {
        Write-Log "Running as Administrator. Calling repo installer if present."
        $repoInstaller = Join-Path -Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) -ChildPath 'install_dotnet_on_runner.ps1'
        if (Test-Path $repoInstaller) {
            Write-Log "Found installer at $repoInstaller. Executing..."
            & powershell -NoProfile -ExecutionPolicy Bypass -File $repoInstaller -Channel '8.0' -InstallDir 'C:\Program Files\dotnet' -ErrorAction Stop
            Write-Log "Admin installer finished."
        } else {
            Write-Log "Repo installer not found at $repoInstaller. Falling back to non-admin install."
        }
    }

    # If still no dotnet, attempt non-admin user-local install to $DotnetUserInstallDir
    try {
        $sdks = & dotnet --list-sdks 2>$null
    } catch { $sdks = $null }

    if (-not ($sdks -and $sdks -match '^8\.')) {
        Write-Log "Attempting non-admin install to $DotnetUserInstallDir ..."
        $tempScript = Join-Path $env:TEMP 'dotnet-install.ps1'
        try {
            Invoke-WebRequest -Uri 'https://dot.net/v1/dotnet-install.ps1' -OutFile $tempScript -UseBasicParsing -ErrorAction Stop
            & $tempScript -Channel '8.0' -InstallDir $DotnetUserInstallDir -Architecture x64
            Write-Log "Non-admin dotnet install completed. Adding $DotnetUserInstallDir to PATH for this session."
            $env:PATH = "$DotnetUserInstallDir;$env:PATH"
        } catch {
            Write-Log "Non-admin install failed: $_"
            Write-Log "Operator intervention required to install .NET 8 as Administrator. See C:\ci-artifacts\forensics\$stamp"
        }
    }
}

# 2) Restart or start runner
Write-Log "Invoking ensure_runner_service.ps1 to restart/start the runner."
$ensureScript = Join-Path -Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) -ChildPath 'ensure_runner_service.ps1'
if (Test-Path $ensureScript) {
    try {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $ensureScript -Action restart -RunnerDir $RunnerDir 2>&1 | Tee-Object -FilePath (Join-Path $forensics 'ensure_runner_service.log')
        Write-Log "ensure_runner_service completed."
    } catch {
        Write-Log "ensure_runner_service failed: $_"
    }
} else {
    Write-Log "ensure_runner_service.ps1 not found at $ensureScript. Starting run.cmd if present."
    $runCmd = Join-Path -Path $RunnerDir -ChildPath 'run.cmd'
    if (Test-Path $runCmd) {
        Write-Log "Starting run.cmd in new window (non-service mode)."
        Start-Process -FilePath $runCmd -WorkingDirectory $RunnerDir -WindowStyle Normal
        Write-Log "Started run.cmd."
    } else {
        Write-Log "run.cmd not found in $RunnerDir. Please verify RunnerDir or install the runner as a service."
    }
}

Write-Log "Completed. For logs see $forensics"

Exit 0
