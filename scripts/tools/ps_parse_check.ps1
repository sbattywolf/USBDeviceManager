param(
    [string]$FilePath = "agent/SimRacingAgent.Tests/TestRunner.ps1"
)

$errs = $null
$tokens = $null

try {
    [System.Management.Automation.Language.Parser]::ParseFile($FilePath, [ref]$tokens, [ref]$errs)
}
catch {
    Write-Host "Parser invocation failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 2
}

if ($errs -and $errs.Count -gt 0) {
    foreach ($e in $errs) {
          Write-Host "Parse error at $($e.Extent.StartLineNumber):$($e.Extent.StartColumn) - $($e.Message)" -ForegroundColor Red
    }
    exit 1
}
else {
    Write-Host "Parse OK" -ForegroundColor Green
}
