<#
Assert `process-menu` mock run produced expected marker and pid files.
Usage:
  powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\ci\assert_process_menu_mock_results.ps1 [-Role server|agent|both]
Env:
  PROCESS_MENU_TEST_MARKER - optional path to marker file (default: scripts/ci/process-menu-run.marker)
#>
param(
    [ValidateSet('server','agent','both')]
    [string]$Role = 'both'
)

# Resolve marker path
$marker = $env:PROCESS_MENU_TEST_MARKER
if (-not $marker) { $marker = 'scripts/ci/process-menu-run.marker' }
# Resolve marker path: prefer CWD-relative if present, else fall back to repo-root-relative
if (-not [System.IO.Path]::IsPathRooted($marker)) {
    if (Test-Path $marker) {
        $marker = (Resolve-Path $marker).ProviderPath
    } else {
        $repoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
        $candidate = Join-Path -Path $repoRoot -ChildPath $marker
        if (Test-Path $candidate) { $marker = $candidate }
    }
}

$failures = @()

function Fail([string]$msg) { Write-Host "FAIL: $msg" -ForegroundColor Red; $script:failures += $msg }
function Pass([string]$msg) { Write-Host "OK: $msg" -ForegroundColor Green }

# Check marker
if (-not (Test-Path $marker)) {
    Fail "Marker file not found: $marker"
} else {
    $raw = Get-Content $marker -Raw
    if ($Role -in @('server','both')) {
        if ($raw -match 'MOCK_MARK\s+Start-ServerDetached\s+PID=(\d+)') {
            Pass "Found server start marker (PID=$($Matches[1]))"
        } else {
            Fail "Server start marker missing or malformed in $marker"
        }
    }
    if ($Role -in @('agent','both')) {
        if ($raw -match 'MOCK_MARK\s+Start-AgentDetached\s+PID=(\d+)') {
            Pass "Found agent start marker (PID=$($Matches[1]))"
        } else {
            Fail "Agent start marker missing or malformed in $marker"
        }
    }
}

# Check pid files
$repoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
if ($Role -in @('server','both')) {
    $mockS = Join-Path -Path $repoRoot -ChildPath 'scripts/ci/mock_server.pid'
    if (Test-Path $mockS) { $s = (Get-Content $mockS -Raw).Trim(); if ($s -match '^\d+$') { Pass "mock_server.pid exists: $s" } else { Fail "mock_server.pid content invalid: '$s'" } }
    else { Fail "mock_server.pid missing: $mockS" }
}
if ($Role -in @('agent','both')) {
    $mockA = Join-Path -Path $repoRoot -ChildPath 'scripts/ci/mock_agent.pid'
    if (Test-Path $mockA) { $a = (Get-Content $mockA -Raw).Trim(); if ($a -match '^\d+$') { Pass "mock_agent.pid exists: $a" } else { Fail "mock_agent.pid content invalid: '$a'" } }
    else { Fail "mock_agent.pid missing: $mockA" }
}

if ($failures.Count -gt 0) {
    Write-Host "Assertions failed: $($failures.Count)" -ForegroundColor Red
    exit 1
} else {
    Write-Host 'All assertions passed.' -ForegroundColor Cyan
    exit 0
}
