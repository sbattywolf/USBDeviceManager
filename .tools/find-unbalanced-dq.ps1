param([string]$Path)
$lines = Get-Content -LiteralPath $Path -Encoding UTF8
$cum = 0
for ($i=0; $i -lt $lines.Length; $i++) {
    $line = $lines[$i]
    $count = ($line.ToCharArray() | Where-Object { $_ -eq '"' }).Count
    $cum += $count
    if ($cum % 2 -ne 0) {
        Write-Host "Unbalanced double-quote detected at line $($i+1): $line"
        break
    }
}
if ($cum % 2 -eq 0) { Write-Host 'All double-quotes balanced (even count cumulative)'}