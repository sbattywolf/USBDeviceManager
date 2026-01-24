param(
    [string]$Repo = 'sbattywolf/USBDeviceManager',
    [string]$Branch = 'chore/restore-retry',
    [int]$RequiredSuccesses = 3,
    [int]$MaxAttempts = 10,
    [int]$PollWaitSeconds = 60,
    [int]$NoNewRunWaitSeconds = 30
)

$successCount = 0
$seenRuns = @()

for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
    Write-Host "Attempt $($attempt)/$($MaxAttempts): checking latest CI run..."

    $runsJson = gh run list --repo $Repo --limit 20 --json databaseId,headBranch,workflowName,status,conclusion,createdAt
    if (-not $runsJson) { Write-Host 'gh returned nothing; waiting 30s'; Start-Sleep -Seconds 30; continue }
    $runs = $runsJson | ConvertFrom-Json

    $ci = $runs | Where-Object { $_.workflowName -eq 'CI' -and $_.headBranch -eq $Branch } | Sort-Object -Property createdAt -Descending | Select-Object -First 1
    if (-not $ci) { Write-Host "No CI run found; waiting $($NoNewRunWaitSeconds) s"; Start-Sleep -Seconds $NoNewRunWaitSeconds; continue }

    if ($seenRuns -contains $ci.databaseId) { Write-Host "No new run (still $($ci.databaseId)). Waiting $($NoNewRunWaitSeconds) s..."; Start-Sleep -Seconds $NoNewRunWaitSeconds; continue }
    $seenRuns += $ci.databaseId

    Write-Host "Found run $($ci.databaseId) status=$($ci.status) conclusion=$($ci.conclusion)"

    while ($true) {
        $rJson = gh run view $ci.databaseId --repo $Repo --json databaseId,status,conclusion,createdAt
        $r = $rJson | ConvertFrom-Json
        Write-Host "  waiting: status=$($r.status) conclusion=$($r.conclusion)"
        if ($r.status -eq 'completed') { break }
        Start-Sleep -Seconds 15
    }

    $runInfo = gh run view $ci.databaseId --repo $Repo --json databaseId,status,conclusion,createdAt | ConvertFrom-Json
    $runId = $runInfo.databaseId
    Write-Host "Run completed: id=$($runId) conclusion=$($runInfo.conclusion) createdAt=$($runInfo.createdAt)"

    $out = Join-Path -Path (Resolve-Path -Path '.') -ChildPath ("artifacts/run-$runId")
    New-Item -ItemType Directory -Path $out -Force | Out-Null

    # Download each artifact into its own subfolder, removing any previous extraction to avoid collisions on Windows.
    try {
        $artifactsObj = gh api repos/$Repo/actions/runs/$runId/artifacts 2>$null | ConvertFrom-Json
    } catch {
        $artifactsObj = $null
    }

    if ($artifactsObj -and $artifactsObj.artifacts -and $artifactsObj.artifacts.Count -gt 0) {
        foreach ($aobj in $artifactsObj.artifacts) {
            $a = $aobj.name
            $dest = Join-Path $out $a
            if (Test-Path $dest) { Remove-Item -Recurse -Force $dest -ErrorAction SilentlyContinue }
            New-Item -ItemType Directory -Path $dest -Force | Out-Null
            try {
                gh run download $runId --repo $Repo --name $a -D $dest
                Write-Host "Downloaded artifact '$a' to $dest"
            } catch {
                Write-Host "Warning: failed to download artifact '$a': $_" -ForegroundColor Yellow
            }
        }
    } else {
        # fallback to bulk download if artifact listing fails
        try {
            gh run download $runId --repo $Repo -D $out
            Write-Host "Artifacts downloaded to $out (bulk)"
        } catch {
            Write-Host "Error: bulk artifact download failed: $_" -ForegroundColor Red
        }
    }

    if ($runInfo.conclusion -eq 'success') {
        $successCount++
        Write-Host "Success count: $($successCount)/$($RequiredSuccesses)"
    } else {
        Write-Host "Run failed (conclusion=$($runInfo.conclusion))."
    }

    if ($successCount -ge $RequiredSuccesses) { Write-Host "Observed $($successCount) successful runs - stopping."; break }

    if ($attempt -lt $MaxAttempts) { Write-Host "Waiting $($PollWaitSeconds) s before next check..."; Start-Sleep -Seconds $PollWaitSeconds }
}

if ($successCount -lt $RequiredSuccesses) { Write-Host "Reached max attempts ($($MaxAttempts)) with $($successCount) successes." }
Write-Host 'Monitoring step complete.'
