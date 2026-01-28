$path = 'E:\Workspaces\Git\SimRacing\USBDeviceManager\artifacts\artifact-scan-streamed-full.ndjson'
if (-not (Test-Path $path)) { Write-Output "Missing: $path"; exit 2 }
try {
  $f = [System.IO.File]::Open($path,[System.IO.FileMode]::Open,[System.IO.FileAccess]::ReadWrite,[System.IO.FileShare]::None)
  $f.Close()
  Write-Output "Unlocked: $path"
} catch {
  Write-Output "Locked: $($_.Exception.Message)"
  exit 1
}
