$new = 'test-results'
if (-not (Test-Path $new)) { New-Item -ItemType Directory -Path $new | Out-Null }

# Copy TRX and agent pester results
Get-ChildItem -Path . -Recurse -Include '*.trx','agent-pester-results.xml' -File -ErrorAction SilentlyContinue | ForEach-Object {
    try { Copy-Item -Path $_.FullName -Destination $new -Force -ErrorAction SilentlyContinue } catch { }
}

# Find and copy any 'logs' directories
$logDirs = Get-ChildItem -Path . -Recurse -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'logs' }
foreach ($d in $logDirs) {
    try {
        $rel = $d.FullName.Substring((Get-Location).Path.Length).TrimStart('\')
        $dest = Join-Path $new ($rel -replace '\\','_')
        if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest | Out-Null }
        Copy-Item -Path $d.FullName -Destination $dest -Recurse -Force -ErrorAction SilentlyContinue
    } catch { }
}

Write-Host "Artifacts copied to: " (Get-Item $new).FullName
