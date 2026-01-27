<#
Fetch and download artifacts for a GitHub Actions run using the REST API.
This avoids relying on the local `gh` CLI formatting and jq issues.

Usage:
  $env:GITHUB_TOKEN = '<PAT or GH token with repo scope>'
  pwsh .\scripts\ci\fetch-and-download-run.ps1 -RunId 21336180956 -OutDir '.\artifacts-ci-run-21336180956'
#>
param(
    [Parameter(Mandatory=$true)][int]$RunId,
    [string]$Owner = 'Sbatta',
    [string]$Repo = 'USBDeviceManager',
    [string]$OutDir = "artifacts-ci-run-$RunId",
    [int]$PollIntervalSec = 15,
    [int]$TimeoutSec = 1800
)

if (-not $env:GITHUB_TOKEN -and -not $env:GH_TOKEN) {
    Write-Error "Missing token. Set environment variable GITHUB_TOKEN or GH_TOKEN with a PAT that can read actions and artifacts."
    exit 2
}
$token = $env:GITHUB_TOKEN
if (-not $token) { $token = $env:GH_TOKEN }

$base = "https://api.github.com/repos/$Owner/$Repo/actions/runs/$RunId"
$hdr = @{ Authorization = "Bearer $token"; Accept = 'application/vnd.github+json'; 'User-Agent' = 'fetch-and-download-run-script' }

# poll run status
$start = Get-Date
while ($true) {
    try {
        $run = Invoke-RestMethod -Uri $base -Headers $hdr -UseBasicParsing -ErrorAction Stop
    } catch {
        Write-Host "API error: $($_.Exception.Message) --- retrying in $PollIntervalSec sec"
        Start-Sleep -Seconds $PollIntervalSec
        continue
    }
    $status = $run.status
    <#
    Fetch and download artifacts for a GitHub Actions run using the REST API.
    This avoids relying on the local `gh` CLI formatting and jq issues.

    Usage:
      $env:GITHUB_TOKEN = '<PAT or GH token with repo scope>'
      pwsh .\scripts\ci\fetch-and-download-run.ps1 -RunId 21336180956 -OutDir '.\artifacts-ci-run-21336180956'
    #>
    param(
        [Parameter(Mandatory=$true)][int]$RunId,
    [string]$Owner = 'Sbatta',
    [string]$Repo = 'USBDeviceManager',
    [string]$OutDir = "artifacts-ci-run-$RunId",
        [int]$PollIntervalSec = 15,
        [int]$TimeoutSec = 1800
    )

    if (-not $env:GITHUB_TOKEN -and -not $env:GH_TOKEN) {
        Write-Error "Missing token. Set environment variable GITHUB_TOKEN or GH_TOKEN with a PAT that can read actions and artifacts."
        exit 2
    }
    $token = $env:GITHUB_TOKEN
    if (-not $token) { $token = $env:GH_TOKEN }

    $base = "https://api.github.com/repos/$Owner/$Repo/actions/runs/$RunId"
    $hdr = @{ Authorization = "Bearer $token"; Accept = 'application/vnd.github+json'; 'User-Agent' = 'fetch-and-download-run-script' }

    # poll run status
    $start = Get-Date
    while ($true) {
        try {
            $run = Invoke-RestMethod -Uri $base -Headers $hdr -UseBasicParsing -ErrorAction Stop
        } catch {
            Write-Host "API error: $($_.Exception.Message) --- retrying in $PollIntervalSec sec"
            Start-Sleep -Seconds $PollIntervalSec
            continue
        }
        $status = $run.status
        $conclusion = $run.conclusion
        Write-Host "Run $RunId status=$status conclusion=$conclusion"
        if ($status -ne 'in_progress') { break }
        if ((Get-Date) -gt $start.AddSeconds($TimeoutSec)) { Write-Error "Timeout waiting for run to finish"; exit 3 }
        Start-Sleep -Seconds $PollIntervalSec
    }

    if ($status -eq 'completed' -and $conclusion -eq 'success') { Write-Host "Run completed successfully." } else { Write-Host "Run finished: $status / $conclusion" }

    # List and download artifacts
    $artUrl = "$base/artifacts"
    try {
        $arts = Invoke-RestMethod -Uri $artUrl -Headers $hdr -UseBasicParsing -ErrorAction Stop
    } catch { Write-Error "Failed to list artifacts: $($_.Exception.Message)"; exit 4 }

    if (-not $arts.artifacts -or $arts.total_count -eq 0) { Write-Host "No artifacts found for run $RunId"; exit 0 }

    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

    foreach ($a in $arts.artifacts) {
        $name = $a.name
        $size = $a.size
        $download = $a.archive_download_url
        $zipPath = Join-Path -Path $OutDir -ChildPath ($name + '.zip')
        Write-Host "Downloading artifact '$name' ($size bytes) -> $zipPath"
        try {
            Invoke-RestMethod -Uri $download -Headers $hdr -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
        } catch { Write-Error "Failed to download $name: $($_.Exception.Message)"; continue }
        # extract
        $extractDir = Join-Path -Path $OutDir -ChildPath $name
        try {
            Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force
        } catch {
            Write-Host "Failed to extract $zipPath: $($_.Exception.Message)"
        }
    }

    Write-Host "Artifacts downloaded and extracted to: $OutDir"
    exit 0

