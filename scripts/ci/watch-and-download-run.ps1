<#
Poll GitHub Actions for a workflow run on a branch and download its artifacts

Requirements:
- `gh` CLI installed and authenticated (https://cli.github.com/)
- Optional env var `GITHUB_TOKEN` or `GH_TOKEN` for authenticated API calls

Usage:
  powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\ci\watch-and-download-run.ps1 -Repo "sbattywolf/USBDeviceManager" -Branch "chore/stabilize-tests"

The script polls every `-PollSec` seconds until it finds the latest run for the branch in a completed state,
then downloads all artifacts into `artifacts/ci-latest/<run-id>`.
#>

param(
    [string]$Repo = 'sbattywolf/USBDeviceManager',
    [string]$Branch = 'chore/stabilize-tests',
    [int]$PollSec = 15,
    [int]$MaxAttempts = 480
)

function Ensure-Gh {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Error "gh CLI is not installed or not in PATH. Install from https://cli.github.com/ and authenticate (gh auth login)."
        exit 2
    }
}

Ensure-Gh

$attempt = 0
Write-Host "Watching GitHub Actions runs for $Repo@$Branch (poll every $PollSec sec)."
while ($true) {
    $attempt++
    if ($attempt -gt $MaxAttempts) {
        Write-Error "Max attempts reached ($MaxAttempts). Exiting."
        exit 3
    }

    try {
        $listJson = gh api "repos/$Repo/actions/runs?branch=$Branch&per_page=1" --silent | ConvertFrom-Json
    } catch {
        Write-Warning "gh api query failed: $_. Trying again in $PollSec seconds."
        Start-Sleep -Seconds $PollSec
        continue
    }

    if (-not $listJson.workflow_runs -or $listJson.workflow_runs.Count -eq 0) {
        Write-Host "No workflow runs found for branch '$Branch' yet. Attempt $attempt."
        Start-Sleep -Seconds $PollSec
        continue
    }

    $run = $listJson.workflow_runs[0]
    $runId = $run.id
    $runStatus = $run.status
    $runConclusion = $run.conclusion
    Write-Host "Found run id=$runId, status=$runStatus, conclusion=$runConclusion"

    if ($runStatus -eq 'completed') {
        $outdir = Join-Path -Path 'artifacts' -ChildPath "ci-latest/$runId"
        if (-not (Test-Path -Path $outdir)) { New-Item -ItemType Directory -Path $outdir -Force | Out-Null }

        Write-Host "Run completed. Downloading artifacts for run $runId to $outdir"
        try {
            gh run download $runId --repo $Repo --dir $outdir --silent
            Write-Host "Downloaded artifacts to $outdir"
            exit 0
        } catch {
            Write-Error "Failed to download artifacts: $_"
            exit 4
        }
    }

    Start-Sleep -Seconds $PollSec
}
