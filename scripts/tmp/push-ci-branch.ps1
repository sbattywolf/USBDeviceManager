$ts = (Get-Date -Format yyyyMMddHHmmss)
Write-Host "timestamp: $ts"
$changes = git status --porcelain
if ($changes -and $changes.Trim().Length -gt 0) {
    git add -A
    git commit -m "ci: trigger Windows CI verification ($ts)"
} else {
    Write-Host 'No changes to commit'
}
$branch = "ci/windows-verify-$ts"
git checkout -b $branch
git push -u origin $branch
Write-Host "Pushed $branch"
