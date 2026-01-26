<#
Simple PowerShell wrapper to iterate over run IDs and download artifacts using the Python helper.

Usage:
  .\scripts\ci_debug_loop.ps1 -RunIds 21315105846,21315105847 -OutDir artifacts/ci-runs

#>
param(
  [Parameter(Mandatory=$true)]
  [int[]] $RunIds,

  [string] $OutDir = "artifacts/ci-runs",

  [string] $Token = $env:GITHUB_TOKEN
)

if (-not (Test-Path .\scripts\download_artifacts.py)) {
  Write-Error "scripts/download_artifacts.py not found; please ensure the script exists"
  exit 2
}

foreach ($id in $RunIds) {
  $dest = Join-Path $OutDir "ci-run-$id"
  Write-Host "Downloading run $id to $dest"
  python .\scripts\download_artifacts.py --run-id $id --out $dest --token $Token
  if ($LASTEXITCODE -ne 0) {
    Write-Warning "download_artifacts.py returned exit code $LASTEXITCODE for run $id"
  }
}

Write-Host "Loop complete";
