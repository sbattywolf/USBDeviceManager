param([string]$Path)
$text = Get-Content -Raw -LiteralPath $Path
$dq = ($text.ToCharArray() | Where-Object { $_ -eq '"' }).Count
$sq = ($text.ToCharArray() | Where-Object { $_ -eq "'" }).Count
Write-Host "DoubleQuotes: $dq  SingleQuotes: $sq"