# Debug wrapper: invoke full agent tests and capture last error details
. "e:\Workspaces\Git\SimRacing\USBDeviceManager\agent\SimRacingAgent.Tests\TestRunner.ps1"

try {
    $res = Invoke-FullAgentTests -Verbose
    Write-Output "Invoke-FullAgentTests returned: $(($res | ConvertTo-Json -Depth 5))"
}
catch {
    Write-Output "Caught exception during Invoke-FullAgentTests"
    Write-Output "Exception Message: $($_.Exception.Message)"
    Write-Output "Exception Type: $($_.Exception.GetType().FullName)"
    Write-Output "Exception StackTrace: $($_.Exception.StackTrace)"
    Write-Output "Error[0]: $($Error[0] | Out-String)"
}

if ($Error.Count -gt 0) { Write-Output "Total errors: $($Error.Count)" }
else { Write-Output "No errors in global error collection." }
