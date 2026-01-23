$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile('agent/SimRacingAgent.Tests\TestRunner.ps1',[ref]$tokens,[ref]$errors)
if ($errors) {
    foreach ($e in $errors) {
        Write-Host $e.Message
        Write-Host "At: $($e.Extent.StartLineNumber):$($e.Extent.StartColumn)"
    }
} else {
    Write-Host 'No parse errors'
}
