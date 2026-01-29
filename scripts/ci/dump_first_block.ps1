$p = Join-Path $PSScriptRoot "..\..\artifacts\artifact-scan-streamed-full.ndjson"
if (-not (Test-Path $p)) { Write-Error "Missing: $p"; exit 2 }
$inside = $false
$braceDepth = 0
$buffer = New-Object System.Collections.Generic.List[string]
Get-Content -LiteralPath $p | ForEach-Object {
    $line = $_
    if (-not $inside -and $line.TrimStart().StartsWith('{')) {
        $inside = $true; $braceDepth = 0; $buffer.Clear()
    }
    if ($inside) { $buffer.Add($line) }
    $open = ([regex]::Matches($line, '\{')).Count
    $close = ([regex]::Matches($line, '\}')).Count
    $braceDepth += ($open - $close)
    if ($inside -and $braceDepth -le 0) {
        $inside = $false
        $jsonText = ($buffer -join "`n").Trim()
        Write-Host "--- Block (first 800 chars) ---"
        Write-Host ($jsonText.Substring(0,[Math]::Min(800,$jsonText.Length)))
        Write-Host "--- Attempting ConvertFrom-Json ---"
        try { $obj = $jsonText | ConvertFrom-Json -ErrorAction Stop; Write-Host "ConvertFrom-Json OK. keys: " ($obj.PSObject.Properties.Name -join ',') } catch { Write-Host "ConvertFrom-Json FAILED: $($_.Exception.Message)" }
        exit 0
    }
}
Write-Host "No block parsed"
