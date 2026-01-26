param(
  [string]$WorkflowFile = 'ci.yml',
  [string]$Branch = 'ci/temp-with-workflows',
  [int]$TimeoutMinutes = 40,
  [int]$IntervalSeconds = 10,
  [string]$ArtifactsDir = 'artifacts',
  [string]$ActivityLog = 'docs/ci-activity-log.md',
  [bool]$RequireActiveRun = $true
)

function Log-Activity {
  param($Text)
  $ts = (Get-Date).ToString('u')
  $line = "- $ts - $Text"
  # Ensure docs folder exists
  $dir = Split-Path -Parent $ActivityLog
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  Add-Content -Path $ActivityLog -Value $line
  Write-Host $line
}

Log-Activity "Started poller for workflow='$WorkflowFile' branch='$Branch' timeout=${TimeoutMinutes}m interval=${IntervalSeconds}s requireActiveRun=${RequireActiveRun}"

# Initial fetch to decide whether we should poll at all (pre-check)
try {
  $initialRuns = gh run list --workflow=$WorkflowFile --branch=$Branch --limit 10 --json number,headBranch,status,conclusion,createdAt 2>$null | ConvertFrom-Json
} catch {
  Log-Activity "Initial gh CLI query failed: $($_.Exception.Message)"
  $initialRuns = @()
}

if ($RequireActiveRun) {
  $active = $initialRuns | Where-Object { $_.status -in @('in_progress','queued','requested') }
  if (-not $active) {
    Log-Activity "Pre-check: no active runs (queued/in_progress/requested) for workflow='$WorkflowFile' branch='$Branch' - exiting (no poll)."
    exit 0
  }
}

$deadline = (Get-Date).AddMinutes($TimeoutMinutes)
while ((Get-Date) -lt $deadline) {
  try {
    $runsJson = gh run list --workflow=$WorkflowFile --branch=$Branch --limit 5 --json number,headBranch,status,conclusion,createdAt 2>$null | ConvertFrom-Json
  } catch {
    Log-Activity "gh CLI query failed: $($_.Exception.Message)"
    Start-Sleep -Seconds 5
    continue
  }

  if (-not $runsJson) {
    Log-Activity "No runs found yet for workflow='$WorkflowFile' branch='$Branch'"
    Start-Sleep -Seconds $IntervalSeconds
    continue
  }

  $latest = $runsJson | Sort-Object {[datetime]$_.createdAt} -Descending | Select-Object -First 1
  $runNumber = $latest.number
  $status = $latest.status
  $conclusion = $latest.conclusion
  Log-Activity "Found run #$runNumber status=$status conclusion=$conclusion"

  if ($status -eq 'completed' -or $status -eq 'failure' -or $status -eq 'cancelled') {
    Log-Activity "Run #$runNumber finished with conclusion='$conclusion'. Downloading artifacts..."
    $outdir = Join-Path $ArtifactsDir "ci-run-$runNumber"
    if (-not (Test-Path $outdir)) { New-Item -ItemType Directory -Path $outdir -Force | Out-Null }
    try {
      gh run download $runNumber -D $outdir 2>&1 | ForEach-Object { Log-Activity $_ }
      Log-Activity "Artifacts downloaded to $outdir"
    } catch {
      Log-Activity "Artifact download failed: $($_.Exception.Message)"
    }
    # Also write a short summary file
    $summary = @{
      runNumber = $runNumber
      branch = $Branch
      workflow = $WorkflowFile
      status = $status
      conclusion = $conclusion
      downloadedTo = (Resolve-Path $outdir).Path
      timestamp = (Get-Date).ToString('o')
    }
    $summary | ConvertTo-Json -Depth 3 | Out-File -FilePath (Join-Path $outdir 'ci-run-summary.json') -Encoding utf8
    Log-Activity "Wrote summary to $outdir\ci-run-summary.json"
    exit 0
  }

  Start-Sleep -Seconds $IntervalSeconds
}

Log-Activity "Timeout waiting for workflow run (>$TimeoutMinutes minutes). Exiting."
exit 2
