# Duplicate shim for tests referencing agent\shared path
Import-Module (Join-Path $PSScriptRoot "..\SimRacingAgent.Tests\shared\TestFramework.psm1") -ErrorAction SilentlyContinue

Export-ModuleMember -Function * -ErrorAction SilentlyContinue




