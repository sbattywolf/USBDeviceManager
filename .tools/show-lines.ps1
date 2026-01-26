param([string]$Path, [int]$Start=1, [int]$End=10)
$text = Get-Content -Raw -LiteralPath $Path -Encoding UTF8
$lines = $text -split "\r?\n"
$StartIndex = [Math]::Max(0, $Start - 1)
$EndIndex = [Math]::Min($lines.Length - 1, $End - 1)
for ($i = $StartIndex; $i -le $EndIndex; $i++) {
    $ln = $lines[$i]
    $vis = $ln -replace "`r","[CR]" -replace "`n","[LF]" -replace "`t","[TAB]"
    Write-Host ("{0,4}: {1}" -f ($i+1), $vis)
}
