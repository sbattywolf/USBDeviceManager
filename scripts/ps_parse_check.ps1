param(
    [string]$Path = '.\agent\SimRacingAgent.Tests\TestRunner.ps1'
)

$errors = $null
$tokens = $null
$ast = $null
[System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors) | Out-Null
if ($errors) {
    Write-Host "Parse errors for ${Path}:" -ForegroundColor Red
    foreach ($e in $errors) {
        Write-Host "Line $($e.Extent.StartLineNumber), Col $($e.Extent.StartColumnNumber): $($e.Message)"
    }
    exit 1
}
else {
    Write-Host "No parse errors detected in $Path" -ForegroundColor Green
}
