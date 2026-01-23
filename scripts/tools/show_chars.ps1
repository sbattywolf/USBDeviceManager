param(
    [string]$File = "agent/SimRacingAgent.Tests/TestRunner.ps1",
    [int]$Start = 466,
    [int]$End = 474
)

$lines = Get-Content -LiteralPath $File
for ($i = $Start; $i -le $End; $i++) {
    $line = $lines[$i-1]
    Write-Host ('Line ' + $i + ': ' + $line)
    for ($j=0; $j -lt $line.Length; $j++) {
        $ch = $line[$j]
        $code = [int][char]$ch
        Write-Host "  [$j] '$ch' => $code"
    }
}
