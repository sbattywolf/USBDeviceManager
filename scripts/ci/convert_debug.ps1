param([int]$Limit=20)
$p = Join-Path $PSScriptRoot "..\..\artifacts\artifact-scan-streamed-full.ndjson"
$inside = $false; $braceDepth=0; $buffer=New-Object System.Collections.Generic.List[string]
$proc=0
Get-Content -LiteralPath $p | ForEach-Object {
    $line = $_
    $trim = $line.TrimStart()
    if (-not $inside -and $trim.StartsWith('{')) { $inside=$true; $braceDepth=0; $buffer.Clear() }
    if ($inside) { $buffer.Add($line) }
    $open = ([regex]::Matches($line, '\{')).Count
    $close = ([regex]::Matches($line, '\}')).Count
    $braceDepth += ($open - $close)
    if ($inside -and $braceDepth -le 0) {
        $inside=$false
        $jsonText=($buffer -join "`n").Trim()
        try { $obj = $jsonText | ConvertFrom-Json -ErrorAction Stop } catch { Write-Host "SKIP malformed"; continue }
        $proc++
        Write-Host "Processed: $proc ; token=$($obj.token) ; path=$($obj.path)"
        if ($proc -ge $Limit) { Write-Host 'Reached limit' ; exit 0 }
    }
}
Write-Host "Done processed: $proc" 
