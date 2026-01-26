$ErrorActionPreference = 'Stop'

function ConvertSvgs {
    $svgs = Get-ChildItem -Path 'design/mockups' -Filter '*.svg' -File -ErrorAction SilentlyContinue
    if ($null -eq $svgs -or $svgs.Count -eq 0) {
        Write-Host 'No SVGs found in design/mockups'
        return
    }
    foreach ($s in $svgs) {
        $out = [io.path]::ChangeExtension($s.FullName, 'png')
        Write-Host "Converting $($s.Name) -> $([io.path]::GetFileName($out))"
        & inkscape --export-type=png --export-filename="$out" "$($s.FullName)"
    }
}

if (-not (Get-Command inkscape -ErrorAction SilentlyContinue)) {
    Write-Host 'Inkscape not found; attempting winget install...'
    try {
        winget install --id Inkscape.Inkscape -e --accept-source-agreements --accept-package-agreements
    }
    catch {
        Write-Host "winget failed: $($_.Exception.Message)"
    }
}

Start-Sleep -Seconds 2

if (Get-Command inkscape -ErrorAction SilentlyContinue) {
    Write-Host 'Inkscape available'; ConvertSvgs; exit 0
}

Write-Host 'Attempting choco install...'
try {
    choco install inkscape -y
}
catch {
    Write-Host "choco failed: $($_.Exception.Message)"
}

Start-Sleep -Seconds 2

if (Get-Command inkscape -ErrorAction SilentlyContinue) {
    Write-Host 'Inkscape available'; ConvertSvgs; exit 0
}

Write-Host 'Could not install Inkscape automatically. Please install manually.'
exit 1
