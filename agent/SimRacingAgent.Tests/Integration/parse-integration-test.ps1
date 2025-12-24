$scriptPath = 'E:\Workspaces\Git\SimRacing\USBDeviceManager\agent\SimRacingAgent.Tests\Integration\test-agent-integration.ps1'
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$errors)
if ($errors -and $errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Host $_.Message -ForegroundColor Red }
    exit 2
} else {
    Write-Host 'Parse OK'
    exit 0
}
