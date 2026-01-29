$path = Join-Path $PSScriptRoot 'Stop-AI-Env.ps1'
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
if ($errors -and $errors.Count -gt 0) {
    foreach ($e in $errors) {
        Write-Host ("ERROR: {0} at {1}:{2}" -f $e.Message, $e.Extent.StartLineNumber, $e.Extent.StartColumnNumber) -ForegroundColor Red
    }
    exit 1
} else {
    Write-Host 'No syntax errors' -ForegroundColor Green
}
