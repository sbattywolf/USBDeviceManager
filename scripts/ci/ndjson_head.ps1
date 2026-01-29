param(
    [int]$Count = 120
)
$path = Join-Path $PSScriptRoot "..\..\artifacts\artifact-scan-streamed-full.ndjson"
if (-not (Test-Path $path)) { Write-Error "File not found: $path"; exit 2 }
$i = 0
Get-Content -LiteralPath $path | ForEach-Object {
    $i++
    if ($i -le $Count) { '{0,4}: {1}' -f $i, $_ }
    else { return }
}
