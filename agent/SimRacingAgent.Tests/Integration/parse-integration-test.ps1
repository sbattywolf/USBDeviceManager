$scriptPath = 'E:\Workspaces\Git\SimRacing\USBDeviceManager\agent\SimRacingAgent.Tests\Integration\test-agent-integration.ps1'
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$errors)
if ($errors -and $errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_.Message }
    exit 2
} else {
    Write-Output 'Parse OK'
    exit 0
}




