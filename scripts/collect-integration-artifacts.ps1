# Collect integration test TRX and TestResults into timestamped artifacts folder
$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$dst = Join-Path (Convert-Path '.') ("artifacts\\local-integration-run_$ts")
New-Item -ItemType Directory -Path $dst -Force | Out-Null
$src = 'server\\USBDeviceManager.Tests\\TestResults'
$trx = Join-Path $src 'integration-run.trx'
if (Test-Path $trx) { Copy-Item -Path $trx -Destination $dst -Force }
Copy-Item -Path (Join-Path $src '*') -Destination $dst -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "Artifacts copied to: $dst"
Get-ChildItem $dst -Recurse | ForEach-Object { Write-Host $_.FullName }
