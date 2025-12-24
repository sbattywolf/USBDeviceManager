$ErrorActionPreference = 'Stop'

Set-Location $PSScriptRoot

if (-not (Test-Path .\logs)) { New-Item -ItemType Directory -Path .\logs | Out-Null }
$logFile = Join-Path $PSScriptRoot 'logs\integration-run-latest.log'
if (Test-Path $logFile) { Remove-Item $logFile -Force }

Write-Host "Running server integration tests (Integration namespace)"

# Path to the test project
$testProject = (Resolve-Path -Path "..\USBDeviceManager.Tests.csproj").Path

# Use filter to run only tests under the Integration namespace
$filter = 'FullyQualifiedName~USBDeviceManager.Tests.Integration'

$dotnetArgs = @('test', $testProject, '--no-build', '--verbosity', 'minimal', '--results-directory', '.\TestResults', '--logger', 'trx;LogFileName=integration.trx', '--filter', $filter)

Write-Host ("dotnet {0}" -f ($dotnetArgs -join ' '))

# Run and capture output reliably
& dotnet @dotnetArgs 2>&1 | Tee-Object -FilePath $logFile
$exit = $LASTEXITCODE

if ($exit -eq 0) {
    Write-Host "Integration tests succeeded"
} else {
    Write-Error "Integration tests failed with exit code $exit"
}

exit $exit
