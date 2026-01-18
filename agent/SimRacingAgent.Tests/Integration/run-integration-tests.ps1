$script:ErrorActionPreference = 'Stop'

try {
    Write-Output "Running focused integration tests (non-interactive)..."
    Set-Location $PSScriptRoot
    # Use the focused runner which avoids interactive prompts and captures logs
    . .\test-agent-integration-run-specific.ps1 -Verbose
    Write-Output "Integration tests completed."
} catch {
    Write-Error "Integration tests failed: $($_.Exception.Message)"
    exit 1
}



