param([string]$OutJson = "E:\\Workspaces\\Git\\SimRacing\\USBDeviceManager\\artifacts\\artifact-scan-streamed-full-clean.json")
$p = Join-Path $PSScriptRoot "..\..\artifacts\artifact-scan-streamed-full.ndjson"
if (Test-Path $OutJson) { Remove-Item -LiteralPath $OutJson -Force }
Set-Content -LiteralPath $OutJson -Value '[' -Encoding UTF8
$inside=$false; $braceDepth=0; $buf=New-Object System.Collections.Generic.List[string]; $first=$true; $proc=0
Get-Content -LiteralPath $p | ForEach-Object {
    $line = $_
    $trim = $line.TrimStart()
    if (-not $inside -and $trim.StartsWith('{')) { $inside=$true; $braceDepth=0; $buf.Clear() }
    if ($inside) { $buf.Add($line) }
    $open = ([regex]::Matches($line, '\{')).Count
    $close = ([regex]::Matches($line, '\}')).Count
    $braceDepth += ($open - $close)
    if ($inside -and $braceDepth -le 0) {
        $inside=$false
        $jsonText=($buf -join "`n").Trim()
        try { $obj = $jsonText | ConvertFrom-Json -ErrorAction Stop } catch { Write-Host "SKIP malformed"; continue }
        $proc++
        $compact = $obj | ConvertTo-Json -Depth 20 -Compress
        if ($first) { Add-Content -LiteralPath $OutJson -Value $compact -Encoding UTF8; $first=$false } else { Add-Content -LiteralPath $OutJson -Value ("," + $compact) -Encoding UTF8 }
        if ($proc % 1000 -eq 0) { Write-Host "Wrote $proc objects so far" }
    }
}
Add-Content -LiteralPath $OutJson -Value ']' -Encoding UTF8
Write-Host "Done wrote objects: $proc -> $OutJson"