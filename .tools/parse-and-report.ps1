param([string[]]$Files)

foreach ($f in $Files) {
    Write-Host "Parsing: $f" -ForegroundColor Cyan
    $tokens = $null; $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($f,[ref]$tokens,[ref]$errors) | Out-Null
    if ($errors -and $errors.Count -gt 0) {
        foreach ($e in $errors) {
            Write-Host "- ERROR: $($e.Message)" -ForegroundColor Red
            $start = $e.Extent.StartScriptPosition
            Write-Host "  At: Line $($start.Line), Column $($start.Column)"
        }
    } else {
        Write-Host "- OK" -ForegroundColor Green
    }
    Write-Host ""
}
