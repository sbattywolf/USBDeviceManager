$err=[ref]$null
[System.Management.Automation.Language.Parser]::ParseFile('E:/Workspaces/Git/SimRacing/USBDeviceManager/scripts/stop-test-environment.ps1',[ref]$null,$err)
if($err.Value){
    Write-Host 'PARSE_ERRORS'
    $err.Value | ForEach-Object { Write-Host $_.Message }
    exit 1
} else {
    Write-Host 'PARSE_OK'
}
