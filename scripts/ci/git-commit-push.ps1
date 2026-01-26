param(
    [string[]]$Paths = @('.'),
    [string]$Message = 'chore: update',
    [string]$Remote = 'origin',
    [string]$Branch = 'HEAD'
)

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error 'git is not available in PATH'
    exit 2
}

Write-Host "Staging: $($Paths -join ', ')"
git add -- $Paths

$commit = git commit -m $Message 2>&1
if ($LASTEXITCODE -ne 0) {
    if ($commit -match 'nothing to commit') {
        Write-Host 'Nothing to commit.'
    } else {
        Write-Warning "git commit returned non-zero: $commit"
    }
} else {
    Write-Host 'Commit created.'
}

Write-Host "Pushing to $Remote $Branch"
git push $Remote $Branch
if ($LASTEXITCODE -ne 0) {
    Write-Warning 'git push failed; check credentials and network.'
    exit $LASTEXITCODE
}
Write-Host 'Push completed.'
