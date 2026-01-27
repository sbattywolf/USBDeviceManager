# Retry wrapper for transient NuGet failures (3 attempts with exponential backoff)
$maxAttempts = 3
$baseDelay = 5
$success = $false
for ($i = 1; $i -le $maxAttempts; $i++) {
  Write-Host "dotnet restore attempt $i of $maxAttempts"
  dotnet restore ./USBDeviceManager.sln --verbosity minimal
  if ($LASTEXITCODE -eq 0) {
    $success = $true
    break
  }
  if ($i -lt $maxAttempts) {
    $delay = $baseDelay * [math]::Pow(2, $i - 1)
    Write-Host "Restore failed; sleeping $delay seconds before retrying..."
    Start-Sleep -Seconds $delay
  }
}
if (-not $success) {
  Write-Error "dotnet restore failed after $maxAttempts attempts"
  exit 1
}
