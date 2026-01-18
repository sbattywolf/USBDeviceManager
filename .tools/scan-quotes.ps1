param([string]$Path)
$text = Get-Content $Path -Raw
$len = $text.Length
$pos = 0
$line = 1
$col = 1
$inSingleHere = $false
$inDoubleHere = $false
$inDouble = $false
while ($pos -lt $len) {
    $ch = $text[$pos]
    # update line/col
    if ($ch -eq "`n") { $line++; $col = 1 } else { $col++ }

    # check for here-string start @' or @"
    if (-not $inSingleHere -and -not $inDoubleHere -and $pos+1 -lt $len -and $text[$pos] -eq '@') {
        $next = $text[$pos+1]
        if ($next -eq "'") { $inSingleHere = $true; $pos+=2; continue }
        if ($next -eq '"') { $inDoubleHere = $true; $pos+=2; continue }
    }
    # check for here-string end
    if ($inSingleHere -and $pos+1 -lt $len -and $text[$pos] -eq "'" -and $text[$pos+1] -eq '@') { $inSingleHere = $false; $pos+=2; continue }
    if ($inDoubleHere -and $pos+1 -lt $len -and $text[$pos] -eq '"' -and $text[$pos+1] -eq '@') { $inDoubleHere = $false; $pos+=2; continue }

    if (-not $inSingleHere -and -not $inDoubleHere) {
        if ($ch -eq '"') {
            # count backslashes before
            $k = $pos - 1; $slashes = 0
            while ($k -ge 0 -and $text[$k] -eq '\\') { $slashes++; $k-- }
            if (($slashes % 2) -eq 0) { $inDouble = -not $inDouble }
        }
    }
    $pos++
}
Write-Host "InSingleHere: $inSingleHere, InDoubleHere: $inDoubleHere, InDoubleQuote: $inDouble"; Write-Host "Last line: $line, col: $col" 
