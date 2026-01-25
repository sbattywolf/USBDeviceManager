$log='ci/server.log'
$err='ci/server.err'
if(Test-Path $log){Remove-Item $log -Force}
if(Test-Path $err){Remove-Item $err -Force}
$args = @('run','--project','server/USBDeviceManager','--configuration','Release','--urls','http://127.0.0.1:62332','--no-build')
$proc = Start-Process -FilePath 'dotnet' -ArgumentList $args -RedirectStandardOutput $log -RedirectStandardError $err -NoNewWindow -PassThru
Write-Output ("Server started (pid {0}), waiting up to 30s for readiness markers..." -f $proc.Id)
$end=(Get-Date).AddSeconds(30)
while((Get-Date) -lt $end) {
  $content = ''
  if(Test-Path $log) { $content = Get-Content $log -Raw -ErrorAction SilentlyContinue }
  if($content -match 'Now listening on' -or $content -match '\[DIAG\] ApplicationStarted') {
    Write-Output 'Readiness marker found'
    exit 0
  }
  Start-Sleep -Seconds 1
}
Write-Output 'Timeout waiting for readiness markers'
exit 2
