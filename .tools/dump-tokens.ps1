param([string]$Path)
$errors = $null
$tokens = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
if ($errors) {
    Write-Host "Parse errors: $($errors.Count)" -ForegroundColor Yellow
} else {
    Write-Host "No parse errors" -ForegroundColor Green
}

for ($i = 0; $i -lt $tokens.Count; $i++) {
    $t = $tokens[$i]
    $pos = $t.Extent.StartLineNumber
    $txt = $t.Text -replace "\r","[CR]" -replace "\n","[LF]"
    Write-Host ("{0,5}: Line {1,4} Kind:{2,20} Text:'{3}'" -f $i, $pos, $t.Kind, $txt)
}
