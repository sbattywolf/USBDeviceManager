<#
Run only selected integration tests (InteractiveMode and DashboardConnectivity)
This script is a temporary runner used to capture focused logs for debugging.
#>

param()

$ErrorActionPreference = 'Stop'

Set-Location $PSScriptRoot

. .\test-agent-integration.ps1

Write-TestLog "Running selected integration tests (InteractiveMode, DashboardConnectivity)" "Info"

$results = @{}

try {
    $results.InteractiveMode = Test-InteractiveMode
} catch {
    Write-TestLog "Exception running InteractiveMode: $($_.Exception.Message)" "Error"
    $results.InteractiveMode = $false
}

try {
    $results.DashboardConnectivity = Test-DashboardConnectivity
} catch {
    Write-TestLog "Exception running DashboardConnectivity: $($_.Exception.Message)" "Error"
    $results.DashboardConnectivity = $false
}

Write-TestLog "Selected test results: $(($results | ConvertTo-Json -Compress))" "Info"

$failed = $results.GetEnumerator() | Where-Object { -not $_.Value }
if ($failed) { exit 1 } else { exit 0 }




