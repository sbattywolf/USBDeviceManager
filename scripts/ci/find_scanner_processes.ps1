$out = '.\artifacts\scanner_processes.txt'
$patterns = @('artifact','scan','ndjson','artifact-scan','USBDeviceManager')

$result = Get-CimInstance Win32_Process | Where-Object {
    $cmd = $_.CommandLine
    if (-not $cmd) { return $false }
    foreach ($p in $patterns) { if ($cmd -match $p) { return $true } }
    return $false
} | Select-Object ProcessId, Name, CommandLine, ExecutablePath | Sort-Object ProcessId

if ($result) {
    $result | Format-Table -AutoSize | Out-String -Width 4096 | Set-Content -LiteralPath $out -Encoding utf8
    Write-Host "WROTE $out"
} else {
    "No matching processes found." | Set-Content -LiteralPath $out -Encoding utf8
    Write-Host "WROTE $out (no matches)"
}

# Also print brief summary to stdout
if ($result) { $result | Select-Object ProcessId, Name | Format-Table -AutoSize }
else { Write-Host 'No matching processes found.' }