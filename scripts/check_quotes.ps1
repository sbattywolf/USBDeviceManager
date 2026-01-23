$path = '.\agent\SimRacingAgent.Tests\TestRunner.ps1'
$lines = Get-Content -Path $path -Raw -Encoding UTF8 -ErrorAction Stop -Split "`n"
$cumulative = 0
for ($i = 0; $i -lt $lines.Length; $i++) {
    $line = $lines[$i]
    $count = ($line -split '"').Length - 1
    $cumulative += $count
    if ($cumulative % 2 -ne 0) {
        Write-Host "Unbalanced double quote at line $($i+1): $line" -ForegroundColor Yellow
        break
    }
}
if ($cumulative % 2 -eq 0) { Write-Host "No unbalanced double quotes detected (cumulative even)" -ForegroundColor Green }
