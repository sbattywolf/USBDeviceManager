# Archived copy of scripts/find-images-in-branches.ps1
# Original: scripts/find-images-in-branches.ps1

# List image files tracked in all local and remote branches
$branches = git for-each-ref --format='%(refname:short)' refs/heads refs/remotes 2>$null
if (-not $branches) { Write-Host 'No branches found.'; exit 0 }
$foundMatches = @()
foreach ($b in $branches) {
    $files = git ls-tree -r --name-only $b 2>$null
    if ($files) {
        foreach ($f in $files) {
            if ($f -match '\.(png|jpg|jpeg|svg|gif|webp)$') {
                $foundMatches += "$($b):$f"
            }
        }
    }
}
if ($foundMatches.Count -eq 0) {
    Write-Host 'No image files found across branches.'
} else {
    Write-Host 'Image files found in branches:'
    $foundMatches | Sort-Object -Unique | ForEach-Object { Write-Host $_ }
}
