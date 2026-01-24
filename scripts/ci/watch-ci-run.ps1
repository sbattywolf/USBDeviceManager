param(
    [int]$MaxMinutes = 30,
    [string]$Branch = 'chore/stabilize-tests'
)

$sha = (git rev-parse HEAD).Trim()
$end = (Get-Date).AddMinutes($MaxMinutes)
Write-Host "Watching CI runs for branch $Branch and commit $sha until $end"

while ((Get-Date) -lt $end) {
    # Query recent runs across branches (branch filter sometimes returns empty); include createdAt so we can pick the most recent CI workflow run for the branch
    $runsJson = gh run list --limit 50 --json id,workflow,status,conclusion,headSha,headBranch,createdAt 2>$null
    if (-not $runsJson) {
        Write-Host 'gh run list returned nothing; sleeping...'
        Start-Sleep -Seconds 10
        continue
    }
    $runs = $runsJson | ConvertFrom-Json
    # Prefer matching HEAD commit on our branch, but fall back to the most recent CI run on the branch
    $match = $runs | Where-Object { $_.headSha -eq $sha -and $_.headBranch -eq $Branch -and $_.workflow -eq 'CI' } | Select-Object -First 1
    if (-not $match) {
        $match = $runs | Where-Object { $_.headBranch -eq $Branch -and $_.workflow -eq 'CI' } | Sort-Object {[datetime]$_.createdAt} -Descending | Select-Object -First 1
    }
    if ($match) {
        $id = $match.id
        $status = $match.status
        $conclusion = $match.conclusion
        Write-Host "Found run $id status=$status conclusion=$conclusion"
        if ($status -eq 'in_progress' -or $status -eq 'queued') {
            Start-Sleep -Seconds 10
            continue
        }
        if ($status -eq 'completed') {
            Write-Host "Downloading artifacts for run $id..."
            gh run download $id --dir artifacts/ci-latest/$id
            exit 0
        }
        Write-Host "Run status: $status; sleeping..."
        Start-Sleep -Seconds 10
    } else {
        Write-Host "No matching CI run for commit $sha yet; sleeping..."
        Start-Sleep -Seconds 10
    }
}

Write-Error "Timeout waiting for run for commit $sha"
exit 2
