param([string]$Path)
$lines = Get-Content $Path
$inDouble = $false
for ($i=0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    # count unescaped double quotes
    $count = 0
    $j = 0
    while ($j -lt $line.Length) {
        if ($line[$j] -eq '"') {
            # check backslashes before quote
            $k=$j-1; $slashes=0
            while ($k -ge 0 -and $line[$k] -eq '\\') { $slashes++; $k-- }
            if (($slashes % 2) -eq 0) { $count++ }
        }
        $j++
    }
    if (($count % 2) -ne 0) {
        $inDouble = -not $inDouble
    }
    if ($inDouble) { Write-Host "Line $($i+1): possible inside-unclosed-double-quote -> $line" }
}
if (-not $inDouble) { Write-Host 'No open double-quote detected at EOF' } else { Write-Host 'Double-quote left open at EOF' }
