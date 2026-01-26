$p = (Join-Path $PSScriptRoot 'TestRunner.ps1')
$b = [IO.File]::ReadAllBytes($p)
if ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF) {
    Write-Output 'BOM present; no change'
}
else {
    $s = [System.Text.Encoding]::UTF8.GetString($b)
    [IO.File]::WriteAllBytes($p, ([System.Text.Encoding]::UTF8.GetPreamble()) + [System.Text.Encoding]::UTF8.GetBytes($s))
    Write-Output 'Wrote UTF8 BOM'
}
