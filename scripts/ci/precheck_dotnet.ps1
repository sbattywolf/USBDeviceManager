Write-Host 'Checking for system-installed dotnet...'
$dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
if ($null -ne $dotnet) {
  Write-Host 'dotnet is present on this runner:'
  dotnet --info
  exit 0
} else {
  Write-Host 'ERROR: dotnet is not installed on this self-hosted runner.'
  Write-Host 'Please run the runner maintenance script to install .NET system-wide:'
  Write-Host '  scripts/ci/install_dotnet_on_runner.ps1'
  Write-Host 'Or install .NET 8 as administrator on the host and restart the runner service.'
  exit 1
}
