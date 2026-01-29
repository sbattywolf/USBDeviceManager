$marker='scripts/ci/process-menu-run.marker'
if (Test-Path $marker) {
    $raw = Get-Content $marker -Raw
    Write-Host '---Raw (escaped newlines)---'
    Write-Host ($raw -replace "`r", '\\r' -replace "`n", '\\n')
    Write-Host '---Bytes (hex)---'
    $bytes = [System.IO.File]::ReadAllBytes((Resolve-Path $marker))
    $hex = $bytes | ForEach-Object { ('{0:X2}' -f $_) }
    Write-Host ($hex -join ' ')
    Write-Host '---End---'
} else { Write-Host 'marker missing' }
