$ts = (Get-Date -Format yyyyMMddHHmmss)
Write-Host "timestamp: $ts"

# Determine if there are working-tree changes in a cross-shell-safe way
$changes = (git status --porcelain) -join "`n"
if ($null -ne $changes -and $changes.Trim().Length -gt 0) {
    Write-Host "Changes detected, committing..."
    git add -A
    git commit -m "ci: trigger Windows CI verification ($ts)"
} else {
    Write-Host 'No changes to commit'
}

$branch = "ci/windows-verify-$ts"
Write-Host "Creating branch $branch"
git checkout -b $branch

Write-Host "Pushing branch to origin"
git push -u origin $branch
if ($LASTEXITCODE -ne 0) {
    Write-Error "git push failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}

Write-Host "Pushed $branch"
