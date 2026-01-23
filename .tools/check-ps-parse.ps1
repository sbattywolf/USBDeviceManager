param([string]$Path)
$errors = $null
$tokens = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tokens,[ref]$errors)
if ($errors) {
    foreach ($e in $errors) {
        Write-Host $e.Message
        Write-Host ("At: {0}:{1}" -f $e.Extent.StartLineNumber, $e.Extent.StartColumn)
    }
} else {
    Write-Host 'No parse errors'
}
