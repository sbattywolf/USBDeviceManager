param(
    [string]$NdjsonPath = "E:\\Workspaces\\Git\\SimRacing\\USBDeviceManager\\artifacts\\artifact-scan-streamed-full.ndjson",
    [string]$OutDir = "E:\\Workspaces\\Git\\SimRacing\\USBDeviceManager\\artifacts\\ndjson-malformed",
    [int]$Limit = 1000
)
if (-not (Test-Path $NdjsonPath)) { Write-Error "NDJSON not found: $NdjsonPath"; exit 2 }
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }

$inside = $false
$braceDepth = 0
$bufferLines = New-Object System.Collections.Generic.List[string]
$proc=0
$malformed=0
$recovered=0
Get-Content -LiteralPath $NdjsonPath | ForEach-Object {
    $line = $_
    $trim = $line.TrimStart()
    if (-not $inside -and $trim.StartsWith('{')) {
        $inside = $true; $braceDepth = 0; $bufferLines.Clear()
    }
    if ($inside) { $bufferLines.Add($line) }
    $open = ([regex]::Matches($line, '\{')).Count
    $close = ([regex]::Matches($line, '\}')).Count
    $braceDepth += ($open - $close)
    if ($inside -and $braceDepth -le 0) {
        $inside = $false
        $jsonText = ($bufferLines -join "`n").Trim()
        $proc++
        try {
            $obj = $jsonText | ConvertFrom-Json -ErrorAction Stop
        } catch {
            # attempt simple fixes
            $malformed++
            $fixed = $jsonText -replace ',\s*\}', '}'
            try {
                $obj = $fixed | ConvertFrom-Json -ErrorAction Stop
                $recovered++
            } catch {
                $idx = '{0:000000}' -f $malformed
                $path = Join-Path $OutDir "malformed-$idx.json"
                Set-Content -LiteralPath $path -Value $jsonText -Encoding UTF8
            }
        }
        if ($proc % 1000 -eq 0) { Write-Host "Scanned $proc objects (malformed: $malformed, recovered: $recovered)" }
        if ($Limit -and $proc -ge $Limit) { return }
    }
}
Write-Host "Done. scanned: $proc ; malformed: $malformed ; recovered: $recovered ; saved malformed to: $OutDir"