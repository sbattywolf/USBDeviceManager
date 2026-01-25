# Poll GitHub Actions runs for branch ci/restore-retry and report build-and-test job status
$max = 30
$repo = 'sbattywolf/USBDeviceManager'
$branch = 'ci/restore-retry'
for ($i = 0; $i -lt $max; $i++) {
    Write-Host "Poll $($i+1)/$($max): $(Get-Date -Format o)"
    try {
        $runsJson = gh run list --repo $repo --branch $branch --limit 20 --json databaseId,workflowName,status,conclusion,url 2>$null
        if (-not $runsJson) { Write-Host 'No runs yet'; Start-Sleep -Seconds 12; continue }
        $runs = $runsJson | ConvertFrom-Json
    } catch {
        Write-Host "Error listing runs: $_"; Start-Sleep -Seconds 12; continue
    }

    foreach ($r in $runs) {
        $id = $r.databaseId
        try {
            $viewJson = gh run view $id --repo $repo --json status,conclusion,jobs 2>$null
            if (-not $viewJson) { continue }
            $view = $viewJson | ConvertFrom-Json
        } catch {
            Write-Host "Error viewing run $id: $_"; continue
        }

        if ($view.jobs) {
            foreach ($j in $view.jobs) {
                if ($j.name -eq 'build-and-test') {
                    Write-Host "Run $id"
                    Write-Host "  url: $($r.url)"
                    Write-Host "  job: $($j.name) status=$($j.status) conclusion=$($j.conclusion)"
                    if ($j.status -eq 'completed') { exit 0 }
                }
            }
        }
    }
    Start-Sleep -Seconds 12
}
Write-Host 'Timed out waiting for build-and-test to complete'
exit 2
