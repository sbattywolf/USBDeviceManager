$p = Join-Path $PSScriptRoot "..\..\artifacts\artifact-scan-streamed-full.ndjson"
if (-not (Test-Path $p)) { Write-Error "Missing: $p"; exit 2 }
$totalLines = (Get-Content -LiteralPath $p | Measure-Object -Line).Lines
$starts = 0
$tokenLines = 0
Get-Content -LiteralPath $p | ForEach-Object { $line = $_; if ($line.TrimStart().StartsWith('{')) { $starts++ }; if ($line -match '"token"') { $tokenLines++ } }
$info = Get-Item -LiteralPath $p
Write-Host "File: $p"
Write-Host "Size (bytes): $($info.Length)"
Write-Host "Total lines: $totalLines"
Write-Host "Lines starting with '{' : $starts"
Write-Host "Lines containing \"token\": $tokenLines"
