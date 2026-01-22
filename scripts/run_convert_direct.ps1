$ErrorActionPreference = 'Stop'

# Find inkscape executable
$ink = Get-Command inkscape -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue
if (-not $ink) {
    $candidates = @("C:\\Program Files\\Inkscape\\bin\\inkscape.exe","C:\\Program Files\\Inkscape\\inkscape.exe","C:\\Program Files (x86)\\Inkscape\\inkscape.exe")
    foreach ($c in $candidates) { if (Test-Path $c) { $ink = $c; break } }
}

if (-not $ink) {
    Write-Host 'Inkscape not found on PATH or standard locations.'
    exit 2
}

Write-Host "Using inkscape at: $ink"

$svgs = Get-ChildItem -Path 'design/mockups' -Filter '*.svg' -File -ErrorAction SilentlyContinue
if (!$svgs -or $svgs.Count -eq 0) { Write-Host 'No SVGs found to convert.'; exit 0 }

foreach ($s in $svgs) {
    $out = [io.path]::ChangeExtension($s.FullName,'png')
    Write-Host "Converting $($s.Name) -> $([io.path]::GetFileName($out))"
    & "$ink" --export-type=png --export-filename="$out" "$($s.FullName)"
}

Write-Host 'Conversion complete.'
exit 0
