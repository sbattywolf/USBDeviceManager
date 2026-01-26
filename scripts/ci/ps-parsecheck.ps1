param(
    [Parameter(Mandatory=$true)]
    [string[]]$Paths
)

foreach ($p in $Paths) {
    if (-not (Test-Path $p)) { Write-Host "MISSING: $p"; exit 2 }
    Write-Host "Parsing: $p"
    $tokens = $null
    $errors = $null
    try {
        [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path -LiteralPath $p).ProviderPath, [ref]$tokens, [ref]$errors)
        if ($errors -and $errors.Count -gt 0) {
            Write-Error ([string]::Format("Parse errors in {0}`n{1}", $p, ($errors | Out-String)))
            exit 1
        } else {
            Write-Host ("PARSE_OK: {0}" -f $p)
        }
    } catch {
        Write-Error ([string]::Format("Exception parsing {0}: {1}", $p, $_.Exception.Message))
        exit 3
    }
}
exit 0
