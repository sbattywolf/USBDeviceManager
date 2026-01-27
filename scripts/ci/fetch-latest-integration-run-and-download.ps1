<#
Find the latest run for the integration-only workflow on a branch and download its artifacts.
Usage:
  $env:GITHUB_TOKEN = '<token>'
  pwsh .\scripts\ci\fetch-latest-integration-run-and-download.ps1 -Branch 'chore/ci-hardening-sentinel'
#>
param(
    [string]$Branch = 'chore/ci-hardening-sentinel',
    [string]$Owner = 'Sbatta',
    [string]$Repo = 'USBDeviceManager',
    [string]$WorkflowFile = 'integration-only.yml'
)

if (-not $env:GITHUB_TOKEN -and -not $env:GH_TOKEN) { Write-Error 'Missing GITHUB_TOKEN or GH_TOKEN'; exit 2 }
$token = $env:GITHUB_TOKEN; if (-not $token) { $token = $env:GH_TOKEN }

$hdr = @{ Authorization = "Bearer $token"; Accept = 'application/vnd.github+json'; 'User-Agent' = 'fetch-latest-run' }
$wfUrl = "https://api.github.com/repos/$Owner/$Repo/actions/workflows/$WorkflowFile"
try {
    $wf = Invoke-RestMethod -Uri $wfUrl -Headers $hdr -UseBasicParsing -ErrorAction Stop
} catch { Write-Error "Failed to read workflow metadata: $($_.Exception.Message)"; exit 3 }

$wfId = $wf.id
if (-not $wfId) { Write-Error 'Could not resolve workflow id'; exit 4 }

$runsUrl = "https://api.github.com/repos/$Owner/$Repo/actions/workflows/$wfId/runs?branch=$Branch&per_page=1"
try {
    $runs = Invoke-RestMethod -Uri $runsUrl -Headers $hdr -UseBasicParsing -ErrorAction Stop
} catch { Write-Error "Failed to list workflow runs: $($_.Exception.Message)"; exit 5 }

if (-not $runs.workflow_runs -or $runs.total_count -eq 0) { Write-Host 'No runs found'; exit 0 }

$run = $runs.workflow_runs[0]
$runId = $run.id
Write-Host "Latest run for $WorkflowFile on $Branch -> id: $runId status: $($run.status) conclusion: $($run.conclusion)"

# Call existing fixed downloader
$script = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) 'fetch-and-download-run-fixed.ps1'
if (-not (Test-Path $script)) { Write-Error "Downloader script missing: $script"; exit 6 }

powershell -NoProfile -ExecutionPolicy Bypass -File $script -RunId $runId -OutDir ("artifacts-ci-run-$runId")

exit 0
