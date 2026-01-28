param(
  [int]$Interval = 15
)

$scriptName = 'artifact_scan_streamed.ps1'
Write-Output "Scanner monitor started at $(Get-Date -Format o)"
while ($true) {
  $procs = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and ($_.CommandLine -match $scriptName) }
  $pl = Get-ChildItem .\artifacts\*-progress.log -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($pl) {
    Write-Output "[$(Get-Date -Format o)] Progress log: $($pl.Name) lastWrite=$($pl.LastWriteTime)"
    Get-Content $pl.FullName -Tail 5 -ErrorAction SilentlyContinue | ForEach-Object { Write-Output "  $_" }
  } else {
    Write-Output "[$(Get-Date -Format o)] No progress log yet"
  }

  if (-not $procs) {
    Write-Output 'Scanner process not found; exiting monitor loop.'
    break
  }

  Start-Sleep -Seconds $Interval
}

Write-Output 'Scanner monitor: checking for final JSON output...'
$js = Get-ChildItem .\artifacts\*-p*.json -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($js) {
  Write-Output "Found JSON: $($js.FullName)"
  try {
    $r = Get-Content $js.FullName -Raw | ConvertFrom-Json
    Write-Output ("Summary: found={0} count={1}" -f $r.found, $r.count)
  } catch {
    Write-Output 'Failed to parse JSON output'
  }
} else {
  Write-Output 'No JSON outputs found'
}
