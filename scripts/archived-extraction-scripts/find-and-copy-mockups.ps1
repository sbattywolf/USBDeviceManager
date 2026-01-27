# Archived copy of scripts/find-and-copy-mockups.ps1
# Original: scripts/find-and-copy-mockups.ps1

# Find image files excluding common large dirs and copy to artifacts/mockups
 $dest = Join-Path $PSScriptRoot '..\artifacts\mockups'
 New-Item -ItemType Directory -Path $dest -Force | Out-Null
$patterns = @('*.png','*.jpg','*.jpeg','*.svg','*.gif','*.webp')
$excludeRegex = '\\.git\\|\\bartifacts\\b|\\.worktrees\\|\\.venv\\|\\bnode_modules\\b'
$found = Get-ChildItem -Path $PSScriptRoot\.. -Recurse -File -Include $patterns -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch $excludeRegex }

Write-Host "Found count: $($found.Count)"
if ($found.Count -eq 0) { Write-Host 'No matching image files found (excluding .git/artifacts/.worktrees/.venv/node_modules).'; exit 0 }

foreach ($f in $found) {
    $target = Join-Path $dest $f.Name
    Copy-Item -Path $f.FullName -Destination $target -Force
    Write-Host "COPIED: $($f.FullName) -> $target"
}

Write-Host "\n-- Copied files in $dest --"
Get-ChildItem -Path $dest -File | Select-Object FullName,Length | Format-Table -AutoSize

# Produce a simple folder size summary for top-level directories
Write-Host "\n--- Folder size summary (top 20) ---"
$roots = Get-ChildItem -Path $PSScriptRoot\.. -Directory -Force -ErrorAction SilentlyContinue
$summary = foreach ($r in $roots) {
    $size = (Get-ChildItem $r.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    [PSCustomObject]@{ Path = $r.FullName; SizeBytes = $size }
}
$summary | Sort-Object -Property SizeBytes -Descending | Select-Object -First 20 | Format-Table -AutoSize
