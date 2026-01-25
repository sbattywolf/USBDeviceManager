$port=62332
$end=(Get-Date).AddSeconds(30)
while((Get-Date) -lt $end) {
  $res = Test-NetConnection -ComputerName 127.0.0.1 -Port $port -WarningAction SilentlyContinue
  if($res -and $res.TcpTestSucceeded) {
    Write-Output "Port $port is open"
    exit 0
  }
  Start-Sleep -Seconds 1
}
Write-Output "Timeout waiting for port $port"
exit 2
