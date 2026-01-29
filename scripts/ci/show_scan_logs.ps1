$base = 'E:\Workspaces\Git\SimRacing\USBDeviceManager\artifacts'
$files = @('artifact-scan-streamed-full.log','artifact-scan-streamed-restart.log','artifact-scan-progress.log')
foreach ($f in $files) {
  $path = Join-Path $base $f
  if (Test-Path $path) {
    Write-Output "=== $f ==="
    Get-Content -Path $path -Tail 200 -ErrorAction SilentlyContinue
    Write-Output ""
  } else {
    Write-Output "(missing) $f"
  }
}
