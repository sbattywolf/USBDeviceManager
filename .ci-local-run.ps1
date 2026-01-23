Set-Location 'E:\Workspaces\Git\SimRacing\USBDeviceManager'
Write-Host 'Restore...'
dotnet restore USBDeviceManager.sln
Write-Host 'Build...'
dotnet build USBDeviceManager.sln --configuration Release --no-restore
Write-Host 'Run dotnet tests...'
dotnet test USBDeviceManager.sln --configuration Debug --logger "trx;LogFileName=dotnet-tests-local.trx"
Write-Host 'Run Pester agent tests (if available)...'
if (Get-Command Invoke-Pester -ErrorAction SilentlyContinue) {
  Invoke-Pester -Script @{ Path = '.\agent\SimRacingAgent.Tests'; OutputFormat = 'NUnitXml'; OutputFile = 'agent-pester-results.xml' }
} else { Write-Host 'Pester not found, skipping Invoke-Pester.' }
Write-Host 'Run master TestRunner if present...'
if (Test-Path .\agent\SimRacingAgent.Tests\TestRunner.ps1) {
  Write-Host 'Invoking TestRunner...'
  & powershell -NoProfile -ExecutionPolicy Bypass -File .\agent\SimRacingAgent.Tests\TestRunner.ps1
} else { Write-Host 'No TestRunner found; skipping.' }
# Package artifacts
$ts = (Get-Date).ToString('yyyyMMdd-HHmmss')
$zip = Join-Path -Path 'publish' -ChildPath "ci-local-$ts.zip"
if (-not (Test-Path 'publish')) { New-Item -ItemType Directory -Path 'publish' | Out-Null }
$paths = @()
if (Test-Path 'test-results') { $paths += 'test-results\*' }
$trx = Get-ChildItem -Path . -Filter '*.trx' -Recurse -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }
if ($trx) { $paths += $trx }
if (Test-Path 'agent\SimRacingAgent.Tests') { $paths += 'agent\SimRacingAgent.Tests\**\logs\*' }
if (Test-Path 'server\USBDeviceManager.Tests') { $paths += 'server\USBDeviceManager.Tests\**\logs\*' }
if ($paths.Count -eq 0) { Write-Host 'No artifact paths found to compress.' } else {
  Compress-Archive -Path $paths -DestinationPath $zip -Force
  Write-Host "Created artifact bundle: $zip"
}