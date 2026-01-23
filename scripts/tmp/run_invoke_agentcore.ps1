. 'E:/Workspaces/Git/SimRacing/USBDeviceManager/agent/SimRacingAgent.Tests/TestRunner.ps1'
Write-Host 'Discovered invokers:'
Get-Command -Name 'Invoke-*Tests' -CommandType Function -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_.Name }
Write-Host '--- Running Invoke-AgentCoreTests ---'
try {
    $res = Invoke-AgentCoreTests -ErrorAction Stop
    Write-Host 'Invoker returned:'
    $res | ConvertTo-Json -Depth 6
} catch {
    Write-Host 'ERROR MESSAGE:' $_.Exception.Message
    Write-Host 'ERROR TYPE:' ($_.Exception.GetType().FullName)
    Write-Host 'STACK:'
    Write-Host $_.Exception.StackTrace
    if ($_.Exception.InnerException) {
        Write-Host 'INNER MESSAGE:' $_.Exception.InnerException.Message
        Write-Host 'INNER STACK:'
        Write-Host $_.Exception.InnerException.StackTrace
    }
    exit 2
}
Write-Host '--- Done ---'
