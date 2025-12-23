# Wrapper module to adapt test expected path to real Configuration.psm1
$real = Join-Path $PSScriptRoot "..\..\SimRacingAgent\Utils\Configuration.psm1"
if (Test-Path $real) {
    Import-Module $real -Force
} else {
    Write-Warning "Config wrapper: real module not found at $real"
}

Export-ModuleMember -Function * -ErrorAction SilentlyContinue
