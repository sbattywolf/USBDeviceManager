$p = Join-Path $PSScriptRoot "..\..\artifacts\artifact-scan-streamed-full.ndjson"
if (-not (Test-Path $p)) { Write-Error "Missing: $p"; exit 2 }
$count = 0
$sample = @()
Get-Content -LiteralPath $p | ForEach-Object {
    $line = $_
    if ($line.TrimStart().StartsWith('{')) {
        $count++
        if ($sample.Count -lt 10) { $sample += $line }
    }
}
Write-Host "Lines starting with '{' : $count"
Write-Host "--- Sample starts ---"
$sample | ForEach-Object { Write-Host $_ }
