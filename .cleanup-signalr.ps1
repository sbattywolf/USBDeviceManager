$procs = Get-CimInstance Win32_Process | Where-Object { ($_.CommandLine -and $_.CommandLine -like '*signalr-client*') -or ($_.Name -like '*SignalRTest*') }
if ($procs) {
    $procs | ForEach-Object { Stop-Process -Id $_.ProcessId -Force; Write-Output "Stopped $($_.ProcessId) $($_.Name)" }
} else {
    Write-Output "No matching processes found."
}

$folder = Join-Path $PSScriptRoot 'tools\signalr-client'
if (Test-Path $folder) {
    Remove-Item -LiteralPath $folder -Recurse -Force -ErrorAction SilentlyContinue
    if (!(Test-Path $folder)) { Write-Output "Removed folder: $folder" } else { Write-Output "Failed to remove folder: $folder" }
} else {
    Write-Output "Folder not found: $folder"
}
