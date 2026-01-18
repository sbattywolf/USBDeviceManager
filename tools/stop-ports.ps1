$pids = Get-NetTCPConnection -LocalPort 5000,5001 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -ErrorAction SilentlyContinue | Sort-Object -Unique
if ($pids) {
    Write-Output "Stopping PIDs: $pids"
    Stop-Process -Id $pids -Force -ErrorAction SilentlyContinue
} else {
    Write-Output "No processes found on ports 5000/5001"
}
Start-Sleep -Milliseconds 500
Get-NetTCPConnection -LocalPort 5000,5001 -ErrorAction SilentlyContinue | Select-Object LocalAddress,LocalPort,State,OwningProcess | Format-Table -AutoSize
