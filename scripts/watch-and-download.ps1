Param(
    [int]$Run = 115,
    [int]$MaxChecks = 120,
    [int]$SleepSeconds = 15
)
$outDir = "artifacts/gh-run-$Run"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
for ($i=0; $i -lt $MaxChecks; $i++) {
    $rjson = gh run view $Run --json number,status,conclusion,headSha,headBranch,url,jobs --jq '.' 2>$null
    if (-not $rjson) {
        Write-Output "gh returned nothing; sleeping $SleepSeconds s"
        Start-Sleep -Seconds $SleepSeconds
        continue
    }
    $r = $rjson | ConvertFrom-Json
    Write-Output ("[{0}] status={1} conclusion={2} updatedAt={3}" -f $r.number,$r.status,$r.conclusion,(Get-Date).ToString('o'))
    if ($r.status -eq 'completed') {
        $r | ConvertTo-Json -Depth 6 > (Join-Path $outDir 'run-summary.json')
        break
    }
    Start-Sleep -Seconds $SleepSeconds
}
if (-not (Test-Path (Join-Path $outDir 'run-summary.json'))) {
    Write-Output "Timed out waiting for run to complete."
    exit 2
}
Write-Output "Run completed; downloading artifacts and saving logs to $outDir"
# Download all artifacts for the run
gh run download $Run --dir $outDir 2>&1 | Tee-Object -FilePath (Join-Path $outDir 'artifact-download.log')
# Save the consolidated run logs
gh run view $Run --log > (Join-Path $outDir 'run-logs.txt') 2>&1
# Record failed jobs
$r = Get-Content (Join-Path $outDir 'run-summary.json') | ConvertFrom-Json
$failedJobs = @()
foreach ($job in $r.jobs) {
    if ($job.conclusion -ne 'success') { $failedJobs += $job }
}
$failedJobs | ConvertTo-Json -Depth 6 > (Join-Path $outDir 'failed-jobs.json')
Write-Output "Done. Artifacts/logs in $outDir"
