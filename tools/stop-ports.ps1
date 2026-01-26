$port = $env:TEST_PORT
if (-not $port) { $port = 5000 } else { $port = [int]$port }
$ports = @($port, ($port + 1))
$pids = Get-NetTCPConnection -LocalPort $ports -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -ErrorAction SilentlyContinue | Sort-Object -Unique
if ($pids) {
    Write-Output "Stopping PIDs: $pids"
    Stop-Process -Id $pids -Force -ErrorAction SilentlyContinue
} else {
    Write-Output "No processes found on ports $($ports -join '/')"
}
Start-Sleep -Milliseconds 500
Get-NetTCPConnection -LocalPort $ports -ErrorAction SilentlyContinue | Select-Object LocalAddress,LocalPort,State,OwningProcess | Format-Table -AutoSize
