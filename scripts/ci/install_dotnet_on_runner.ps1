<#
Install .NET 8 system-wide on a Windows self-hosted runner.

Usage (run as Administrator):
  powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\ci\install_dotnet_on_runner.ps1

What it does:
- Checks for administrative privileges.
- Checks whether a .NET 8 SDK is already installed.
- Downloads the official dotnet-install script and installs .NET 8 to C:\Program Files\dotnet.
- Attempts to restart any running GitHub Actions runner service instances (best-effort).

IMPORTANT: Running this script requires Administrator privileges. The machine may need a reboot
or the runner service restarted for changes to be picked up by the runner.
#>

Param(
    [string]$Channel = '8.0',
    [string]$InstallDir = 'C:\Program Files\dotnet',
    [switch]$Force
)

function Write-Info { Write-Host "[INFO]" $args }
function Write-Warn { Write-Host "[WARN]" $args -ForegroundColor Yellow }
function Write-Err  { Write-Host "[ERROR]" $args -ForegroundColor Red }

function Test-IsAdministrator {
    $current = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($current)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdministrator)) {
    Write-Err "This script must be run as Administrator. Open an elevated PowerShell and re-run."
    exit 1
}

Write-Info "Running as Administrator. Checking existing dotnet installation..."

try {
    $dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
} catch {
    $dotnet = $null
}

if ($dotnet -and -not $Force) {
    try {
        $sdks = & dotnet --list-sdks 2>$null
    } catch {
        $sdks = $null
    }
    if ($sdks -and $sdks -match '^8\.') {
        Write-Info "Found .NET 8 SDK installed. No action required."
        exit 0
    }
}

$tempScript = Join-Path $env:TEMP 'dotnet-install.ps1'
Write-Info "Downloading dotnet-install script to $tempScript ..."
try {
    Invoke-WebRequest -UseBasicParsing -Uri 'https://dot.net/v1/dotnet-install.ps1' -OutFile $tempScript -ErrorAction Stop
} catch {
    Write-Err "Failed to download dotnet-install.ps1: $_"
    exit 2
}

Write-Info "Installing .NET Channel $Channel to $InstallDir ... this may take several minutes."
try {
    & $tempScript -Channel $Channel -InstallDir $InstallDir -Architecture x64 -Verbose
    if ($LASTEXITCODE -ne 0) {
        Write-Err "dotnet-install exited with code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
} catch {
    Write-Err "Installation failed: $_"
    exit 3
}

Write-Info "Installation script completed. Verifying installation..."
try {
    $sdks = & "$InstallDir\dotnet.exe" --list-sdks 2>$null
} catch {
    $sdks = $null
}

if ($sdks -and $sdks -match '^8\.') {
    Write-Info "Successfully installed .NET 8:"
    Write-Host $sdks
} else {
    Write-Warn "Could not verify .NET 8 in $InstallDir. It may require a PATH update or system restart."
}

Write-Info "Attempting to restart GitHub Actions runner services (best-effort)."
try {
    $runnerServices = Get-Service | Where-Object { $_.Name -like 'actions.runner*' -or $_.DisplayName -like '*Actions Runner*' }
    if ($runnerServices) {
        foreach ($s in $runnerServices) {
            Write-Info "Restarting service $($s.Name) ..."
            try { Restart-Service -Name $s.Name -Force -ErrorAction Stop; Write-Info "Restarted $($s.Name)" } catch { Write-Warn "Failed to restart $($s.Name): $_" }
        }
    } else {
        Write-Info "No runner services found to restart. Consider restarting the machine or the runner process manually."
    }
} catch {
    Write-Warn "Service restart attempt failed: $_"
}

Write-Info "Done. If the Actions runner process was running as a service, it should pick up the new .NET installation after a service restart or reboot."
Write-Info "If CI still reports missing dotnet, please reboot the machine and run `dotnet --info` to confirm."

exit 0
