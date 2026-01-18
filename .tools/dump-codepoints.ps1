param([string]$Path, [int]$Line=1)
$text = Get-Content -Raw -LiteralPath $Path -Encoding UTF8
$lines = $text -split "\r?\n"
$idx = $Line - 1
if ($idx -lt 0 -or $idx -ge $lines.Length) { Write-Error "Line out of range"; exit 1 }
$s = $lines[$idx]
Write-Host "Line $Line length: $($s.Length)"
for ($i=0; $i -lt $s.Length; $i++) {
    $ch = $s[$i]
    $cp = [int][char]$ch
    $display = $ch
    switch ($cp) {
        13 { $display = '[CR]' }
        10 { $display = '[LF]' }
        9  { $display = '[TAB]' }
    }
    Write-Host ("{0,4}: U+{1:X4} ({2}) => '{3}'" -f $i, $cp, $cp, $display)
}
