# Wrapper module to import the real AgentEngine implementation
$real = Join-Path $PSScriptRoot "..\..\SimRacingAgent\Core\AgentEngine.psm1"
if (Test-Path $real) {
    Import-Module $real -Force
} else {
    Write-Warning "AgentCore wrapper: real module not found at $real"
}

try {
    Export-ModuleMember -Function * -ErrorAction Stop
} catch {
    Write-Verbose "Export-ModuleMember skipped (not running inside a module): $($_.Exception.Message)"
}




