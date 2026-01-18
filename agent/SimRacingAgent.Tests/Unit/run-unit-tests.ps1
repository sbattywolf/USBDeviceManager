. $PSScriptRoot\AgentCoreTests.ps1

try {
    $res = Invoke-AgentCoreTests
    $outPath = Join-Path $PSScriptRoot 'unit-results.json'
    $res | ConvertTo-Json -Depth 10 | Set-Content -Path $outPath -Encoding UTF8
    Write-Output "Unit tests completed. Results saved to: $outPath"
} catch {
    Write-Error "Unit tests failed to run: $($_.Exception.Message)"
}
if (-not $env:CI) { Read-Host 'Press Enter to continue' }



