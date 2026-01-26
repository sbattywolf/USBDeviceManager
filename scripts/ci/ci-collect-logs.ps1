param(
  [string]$OutDir = 'artifacts/ci-logs',
  [int]$MaxLines = 500
)
# Create output directory
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
$meta = @{
  run = $env:GITHUB_RUN_ID
  job = $env:GITHUB_JOB
  runner = $env:RUNNER_OS
  sha = $env:GITHUB_SHA
}
$meta | ConvertTo-Json | Out-File -FilePath (Join-Path $OutDir 'meta.json') -Encoding utf8

# Save system info
try { systeminfo | Out-File -FilePath (Join-Path $OutDir 'systeminfo.txt') -Encoding utf8 } catch { Write-Host 'systeminfo not available' }

# Save env
Get-ChildItem env: | Sort-Object Name | ForEach-Object { "{0}={1}" -f $_.Name, $_.Value } | Out-File -FilePath (Join-Path $OutDir 'env.txt') -Encoding utf8

# Collect common logs if present
$possibleLogs = @('server_out.txt','server_err.txt','tmp-server.out','tmp-server.err','scripts/tmp/ef.log')
foreach ($p in $possibleLogs) {
  if (Test-Path $p) { Get-Content -Path $p -Tail $MaxLines -ErrorAction SilentlyContinue | Out-File -FilePath (Join-Path $OutDir (Split-Path $p -Leaf)) -Encoding utf8 }
}

# Zip outputs
$zip = Join-Path $OutDir ("ci-logs-${env:GITHUB_RUN_ID}-${env:GITHUB_JOB}.zip")
if (Test-Path $zip) { Remove-Item $zip -Force }
try { Compress-Archive -Path (Join-Path $OutDir '*') -DestinationPath $zip -Force; Write-Host "Created $zip" } catch { Write-Host "Failed to create zip: $_" }
