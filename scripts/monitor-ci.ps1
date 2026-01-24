param(
    [int]$IntervalSeconds = 30,
    [int]$MaxIterations = 0
)

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error "gh CLI not found. Install GitHub CLI (gh) to enable CI monitoring.";
    exit 1
}

$log = Join-Path $PSScriptRoot 'ci-monitor.log'
Write-Host "CI monitor starting. Writing log to: $log"
$i = 0
while ($MaxIterations -eq 0 -or $i -lt $MaxIterations) {
    $ts = (Get-Date).ToString('o')
    try {
        $runsJson = gh run list --branch chore/ci-perjob-analyzers --json runNumber,headBranch,headSha,conclusion,status,workflow --limit 10
        $runs = if ($runsJson) { ConvertFrom-Json $runsJson } else { @() }
        $entry = @{ timestamp = $ts; runs = $runs }
    }
    catch {
        $entry = @{ timestamp = $ts; error = $_.Exception.Message }
    }

    $entry | ConvertTo-Json -Depth 10 | Out-File -FilePath $log -Append -Encoding UTF8
    Write-Host "[$ts] Polled CI; found $($entry.runs.Count) runs (logged)."
    Start-Sleep -Seconds $IntervalSeconds
    $i++
}

Write-Host "CI monitor finished."
