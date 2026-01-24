<#
Pipeline wrapper to download artifacts for a run and generate a compact analysis JSON.

Usage:
  .\scripts\ci_debug_pipeline.ps1 -RunId 21315105846

#>
param(
  [Parameter(Mandatory=$true)]
  [long] $RunId,

  [string] $OutBase = "artifacts/ci-runs",

  [string] $Token = $env:GITHUB_TOKEN
)

if (-not (Test-Path .\scripts\download_artifacts.py)) {
  Write-Error "scripts/download_artifacts.py not found"
  exit 2
}
if (-not (Test-Path .\scripts\parse_final_report.py)) {
  Write-Error "scripts/parse_final_report.py not found"
  exit 2
}

$dest = Join-Path $OutBase "ci-run-$RunId"
Write-Host "Downloading run $RunId -> $dest"
python .\scripts\download_artifacts.py --run-id $RunId --out $dest --token $Token
if ($LASTEXITCODE -ne 0) { Write-Warning "download_artifacts.py returned $LASTEXITCODE" }

Write-Host "Parsing downloaded artifacts"
python .\scripts\parse_final_report.py --src $dest --out (Join-Path $dest "ci-analysis.json")

Write-Host "Pipeline complete. See: $dest\ci-analysis.json"
