Write-Host 'Starting server test script'
try {
    $serverDir = Resolve-Path -Path '.\server\USBDeviceManager' -ErrorAction Stop
} catch {
    Write-Host 'Server folder not found:'; Write-Host $_.Exception.Message; exit 2
}
Push-Location $serverDir
$cwd = Get-Location
$outLog = Join-Path -Path $cwd -ChildPath 'server.log'
$errLog = Join-Path -Path $cwd -ChildPath 'server.err'
try {
    $proc = Start-Process -FilePath dotnet -ArgumentList 'run' -WorkingDirectory $cwd -RedirectStandardOutput $outLog -RedirectStandardError $errLog -PassThru -ErrorAction Stop
    Write-Host "Started process PID=$($proc.Id)"
} catch {
    Write-Host 'Start-Process failed:'
    Write-Host $_.Exception.Message
} finally {
    Pop-Location
}
