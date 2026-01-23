param([string]$Root='E:\Workspaces\Git\SimRacing\USBDeviceManager\agent')
$files = Get-ChildItem -Path $Root -Recurse -File -Include *.ps1,*.psm1 -ErrorAction SilentlyContinue
foreach ($f in $files) {
    $text = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
    $lines = $text -split "\r?\n"
    $new = $lines | ForEach-Object { $_.TrimEnd() }
    $out = ($new -join "`n") + "`n"
    if ($out -ne $text) {
        $out | Set-Content -LiteralPath $f.FullName -Encoding UTF8
        Write-Host "Trimmed: $($f.FullName)"
    }
}
Write-Host 'Trim complete'