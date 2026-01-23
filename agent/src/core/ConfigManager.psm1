# Wrapper module to adapt test expected path to real Configuration.psm1
$real = Join-Path $PSScriptRoot "..\..\SimRacingAgent\Utils\Configuration.psm1"
if (Test-Path $real) {
    Import-Module $real -Force
} else {
    Write-Warning "Config wrapper: real module not found at $real"
}

try {
    Export-ModuleMember -Function * -ErrorAction Stop
} catch {
    Write-Verbose "Export-ModuleMember skipped (not running inside a module): $($_.Exception.Message)"
}




