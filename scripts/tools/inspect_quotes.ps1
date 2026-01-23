param(
    [string]$File = "agent/SimRacingAgent.Tests/TestRunner.ps1"
)

$content = Get-Content -Raw -LiteralPath $File -ErrorAction Stop

# Count total double-quote characters
$totalDQ = ($content.ToCharArray() | Where-Object { $_ -eq '"' }).Count
Write-Host "Total double-quote characters: $totalDQ"

# Print lines with odd number of double-quotes
$lines = Get-Content -LiteralPath $File
for ($i=0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    $count = ($line.ToCharArray() | Where-Object { $_ -eq '"' }).Count
    if ($count % 2 -ne 0) {
        Write-Host "Line $($i+1): odd double-quote count ($count): $line" -ForegroundColor Yellow
    }
}
