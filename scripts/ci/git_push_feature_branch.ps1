$branch = 'feature/interactive-ci-mock'
Write-Host "Repo: $(Get-Location)"
$porcelain = git status --porcelain
$exists = $false
try { git rev-parse --verify $branch > $null; $exists = $true } catch { }
if ($exists) { git checkout $branch } else { git checkout -b $branch }
if ($porcelain) {
    git add -A
    git commit -m "Add process-menu mock-mode, CI harness, and docs"
}
try {
    git push -u origin $branch
} catch {
    Write-Warning "git push failed: $($_.Exception.Message)"
}
