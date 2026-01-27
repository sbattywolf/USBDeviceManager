# Poll GitHub Actions runs for branch chore/restore-retry and report build-and-test job status
$max = 60
$repo = 'Sbatta/USBDeviceManager'
$branch = 'chore/restore-retry'
for ($i = 0; $i -lt $max; $i++) {
    Write-Host ('Poll {0}/{1}: {2}' -f ($i+1), $max, (Get-Date -Format 'o'))
    try {
        $runsJson = gh run list --repo $repo --branch $branch --limit 20 --json databaseId,workflowName,status,conclusion,url 2>$null
        if (-not $runsJson) { Write-Host 'No runs yet'; Start-Sleep -Seconds 10; continue }
        $runs = $runsJson | ConvertFrom-Json
    } catch {
        Write-Host ("Error listing runs: {0}" -f $_); Start-Sleep -Seconds 8; continue
    }

    foreach ($r in $runs) {
        $id = $r.databaseId
        try {
            $viewJson = gh run view $id --repo $repo --json status,conclusion,jobs,url 2>$null
            if (-not $viewJson) { continue }
            $view = $viewJson | ConvertFrom-Json
        } catch {
            Write-Host ("Error viewing run {0}: {1}" -f $id, $_); continue
        }

        if ($view.jobs) {
            foreach ($j in $view.jobs) {
                if ($j.name -eq 'build-and-test') {
                    Write-Host "Run $id"
                    Write-Host "  url: $($view.url)"
                    Write-Host ("  job: {0} status={1} conclusion={2}" -f $j.name, $j.status, $j.conclusion)
                    if ($j.status -eq 'completed') { exit 0 }
                }
            }
        }
    }
    Start-Sleep -Seconds 10
}
Write-Host 'Timed out waiting for build-and-test to complete'
exit 2
