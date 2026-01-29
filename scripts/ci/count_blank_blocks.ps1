$p = Join-Path $PSScriptRoot "..\..\artifacts\artifact-scan-streamed-full.ndjson"
if (-not (Test-Path $p)) { Write-Error "Missing: $p"; exit 2 }
$s = Get-Content -Raw -LiteralPath $p
$blocks = $s -split "\r?\n\r?\n+"
$blocks = $blocks | Where-Object { $_ -and ($_.Trim().Length -gt 0) }
Write-Host "Blank-separated blocks: $($blocks.Count)"
