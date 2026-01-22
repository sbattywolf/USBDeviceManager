<#
.SYNOPSIS
  Validate prerequisites for running the Agent E2E tests on a Windows runner.

.DESCRIPTION
  Performs basic environment checks: PowerShell version, available disk space,
  presence of `dotnet` and minimum .NET SDK version (8.x), `git` availability,
  and optionally performs a quick `dotnet restore` + `dotnet build` of the
  E2E test project to validate toolchain functionality.

.PARAMETER RunBuild
  When specified, the script will attempt to restore and build the E2E test
  project (`server/AgentE2E.Tests`). Use on a machine where you want to
  validate the full toolchain.

.EXAMPLE
  pwsh -NoProfile -ExecutionPolicy Bypass .\scripts\check-e2e-runner.ps1 -RunBuild
#>

[CmdletBinding()]
param(
    [switch]$RunBuild,
    [int]$MinDotnetMajor = 8
)

function Write-Ok($msg) { Write-Host "[OK]    $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function Write-Err($msg) { Write-Host "[ERROR] $msg" -ForegroundColor Red }

try {
    Write-Host "Validating E2E runner prerequisites..."

    # PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    Write-Ok "PowerShell version $($psVersion.ToString())"

    # Disk space on current drive
    $drive = Get-Item -Path . | Select-Object -ExpandProperty PSDrive
    $freeGB = [math]::Round(($drive.Free / 1GB),2)
    if ($freeGB -lt 5) {
        Write-Warn "Low free disk space on drive $($drive.Name): $freeGB GB (recommended >= 5 GB)"
    } else {
        Write-Ok "Free disk space on drive $($drive.Name): $freeGB GB"
    }

    # Check git
    $git = Get-Command git -ErrorAction SilentlyContinue
    if (-not $git) {
        Write-Err "git not found on PATH"
        exit 2
    } else {
        $gv = git --version
        Write-Ok "$gv"
    }

    # Check dotnet
    $dot = Get-Command dotnet -ErrorAction SilentlyContinue
    if (-not $dot) {
        Write-Err "dotnet CLI not found on PATH"
        exit 3
    }

    $sdks = & dotnet --list-sdks 2>&1
    if ($LASTEXITCODE -ne 0 -or -not $sdks) {
        Write-Err "Failed to enumerate installed .NET SDKs: $sdks"
        exit 4
    }

    Write-Host "Installed .NET SDKs:`n$sdks"
    $hasMin = $sdks -match "^$MinDotnetMajor\."
    if (-not $hasMin) {
        Write-Warn "No .NET $MinDotnetMajor SDK found. Recommended to install .NET $MinDotnetMajor SDK."
    } else {
        Write-Ok "Found .NET $MinDotnetMajor SDK"
    }

    if ($RunBuild) {
        Write-Host "Performing quick restore + build of E2E test project (server/AgentE2E.Tests)..."
        Push-Location "server/AgentE2E.Tests"
        try {
            dotnet restore --verbosity minimal
            if ($LASTEXITCODE -ne 0) { throw 'dotnet restore failed' }
            dotnet build --configuration Release --no-restore
            if ($LASTEXITCODE -ne 0) { throw 'dotnet build failed' }
            Write-Ok "Quick build succeeded"
        }
        finally { Pop-Location }
    }

    Write-Host "Runner checks completed successfully."
    exit 0
}
catch {
    Write-Err "Exception during checks: $($_.Exception.Message)"
    exit 10
}
