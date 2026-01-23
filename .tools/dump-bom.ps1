param([string]$Path)
$bytes = [System.IO.File]::ReadAllBytes($Path)
if ($bytes.Length -ge 3) {
    $b3 = ($bytes[0..2] | ForEach-Object { '{0:X2}' -f $_ }) -join ' '
    Write-Host "First3 bytes: $b3"
}
if ($bytes.Length -ge 4) {
    $b4 = ($bytes[0..3] | ForEach-Object { '{0:X2}' -f $_ }) -join ' '
    Write-Host "First4 bytes: $b4"
} else { Write-Host "File shorter than 4 bytes" }
