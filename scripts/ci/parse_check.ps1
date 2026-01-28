$target = Resolve-Path '.\scripts\process-menu.ps1'
$errors = [ref]@()
[System.Management.Automation.Language.Parser]::ParseFile($target.Path, [ref]$null, $errors)
if ($errors.Value) {
    foreach ($e in $errors.Value) {
        Write-Host ("ERROR: {0} at {1}:{2}-{3}" -f $e.Message, $e.Extent.File, $e.Extent.StartLineNumber, $e.Extent.EndLineNumber)
    }
    exit 2
} else {
    Write-Host 'Parse OK'
    exit 0
}
