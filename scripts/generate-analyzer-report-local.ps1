$log = 'artifacts/build_after_fix3.log'
$out = 'artifacts/analyzer-report.md'

if (-not (Test-Path $log)) {
    Write-Error "Log file not found: $log"
    exit 1
}

$lines = Get-Content $log
$allMatches = $lines | Select-String -Pattern 'warning\s+([A-Z]{2}\d+)' -AllMatches
$rules = $allMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value } | Group-Object | Sort-Object Count -Descending

Set-Content $out '# Analyzer Report\n' -Encoding UTF8

foreach ($r in $rules) {
    $rule = $r.Name
    $count = $r.Count
    Add-Content $out "`n## $rule - $count occurrences`n"
    $occ = $allMatches | Where-Object { $_.Line -match $rule }
    foreach ($m in $occ) {
        Add-Content $out ("- " + $m.Line.Trim())
    }
}

Write-Output ("Wrote $out")
