# Duplicate shim for tests referencing agent\shared path
Import-Module (Join-Path $PSScriptRoot "..\SimRacingAgent.Tests\shared\TestFramework.psm1") -ErrorAction SilentlyContinue

try {
	Export-ModuleMember -Function * -ErrorAction Stop
} catch {
	Write-Verbose "Export-ModuleMember skipped (not running inside a module): $($_.Exception.Message)"
}




