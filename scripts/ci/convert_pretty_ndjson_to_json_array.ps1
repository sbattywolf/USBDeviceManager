param(
    [string]$NdjsonPath = "E:\\Workspaces\\Git\\SimRacing\\USBDeviceManager\\artifacts\\artifact-scan-streamed-full.ndjson",
    [string]$OutJson = "E:\\Workspaces\\Git\\SimRacing\\USBDeviceManager\\artifacts\\artifact-scan-streamed-full-clean.json"
)
if (-not (Test-Path $NdjsonPath)) { Write-Error "NDJSON not found: $NdjsonPath"; exit 2 }
# Prepare output
if (Test-Path $OutJson) { Remove-Item -LiteralPath $OutJson -Force }
Set-Content -LiteralPath $OutJson -Value '[' -Encoding UTF8

$inside = $false
$braceDepth = 0
$bufferLines = New-Object System.Collections.Generic.List[string]
$first = $true
$processed = 0

Get-Content -LiteralPath $NdjsonPath | ForEach-Object {
    $line = $_
    $trim = $line.TrimStart()
    if (-not $inside -and $trim.StartsWith('{')) {
        $inside = $true
        $braceDepth = 0
        $bufferLines.Clear()
    }
    if ($inside) { $bufferLines.Add($line) }
    $open = ([regex]::Matches($line, '\\{')).Count
    $close = ([regex]::Matches($line, '\\}')).Count
    $braceDepth += ($open - $close)
    if ($inside -and $braceDepth -le 0) {
        $inside = $false
        $jsonText = ($bufferLines -join "`n").Trim()
        try {
            $obj = $jsonText | ConvertFrom-Json -ErrorAction Stop
        } catch {
            # Skip malformed block and continue
            continue
        }
        $processed++
        $compact = $obj | ConvertTo-Json -Depth 20 -Compress
        if ($first) {
            Add-Content -LiteralPath $OutJson -Value ($compact) -Encoding UTF8
            $first = $false
        } else {
            Add-Content -LiteralPath $OutJson -Value ("," + $compact) -Encoding UTF8
        }
    }
}
# Close array
Add-Content -LiteralPath $OutJson -Value ']' -Encoding UTF8
Write-Host "Wrote $OutJson (objects: $processed)"
