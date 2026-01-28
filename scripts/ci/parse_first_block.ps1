# Parse first non-empty JSON block from pretty-printed NDJSON
$path = Join-Path $PSScriptRoot "..\..\artifacts\artifact-scan-streamed-full.ndjson"
if (-not (Test-Path $path)) { Write-Error "File not found: $path"; exit 2 }
$s = Get-Content -Raw -LiteralPath $path
# Split on one or more blank lines (handles CRLF and LF)
$blocks = $s -split "\r?\n\r?\n+"
# Remove empty blocks
$blocks = $blocks | Where-Object { $_ -and ($_.Trim().Length -gt 0) }
Write-Host "Blocks: $($blocks.Count)"
$first = $blocks | Select-Object -First 1
Write-Host "--- First block preview (first 400 chars) ---"
Write-Host ($first.Substring(0, [Math]::Min(400, $first.Length)))
try {
    $obj = $first | ConvertFrom-Json -ErrorAction Stop
    Write-Host "Parsed object type: $($obj.GetType().FullName)"
    if ($obj.PSObject.Properties.Name -contains 'token') { Write-Host "token: $($obj.token)" }
    if ($obj.PSObject.Properties.Name -contains 'path') { Write-Host "path: $($obj.path)" }
    if ($obj.PSObject.Properties.Name -contains 'line') { Write-Host "line: $($obj.line)" }
    Write-Host "--- Parsed object keys ---"
    $obj.PSObject.Properties.Name | ForEach-Object { Write-Host " - $_" }
} catch {
    Write-Host "Parse failed: $($_.Exception.Message)"
}
