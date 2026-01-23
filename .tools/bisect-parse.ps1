param([string]$Path)
$lines = Get-Content $Path
for ($n=1; $n -le $lines.Count; $n++) {
    $tmp = "$env:TEMP\parse_part.ps1"
    $lines[0..($n-1)] | Set-Content $tmp -Encoding utf8
    powershell -NoProfile -Command ". '$tmp'" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Fail at line $n"
        Write-Host $lines[$n-1]
        exit 0
    }
}
Write-Host 'All prefixes parsed'
