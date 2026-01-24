<#
Run the full CI debug pipeline locally.

Usage:
  .\scripts\run_full_debug.ps1 -RunId 21315105846

This will attempt to download artifacts (using `gh` if available), fall back to the
Python downloader using `GITHUB_TOKEN` if set, parse artifacts into `ci-analysis.json`,
and run the focused ShellRunner unit tests locally. Logs and outputs are saved under
`artifacts/ci-run-<id>/`.
#>

param(
  [Parameter(Mandatory=$true)]
  [long] $RunId,
  [string] $Token = $env:GITHUB_TOKEN
)

Set-StrictMode -Version Latest

$base = Join-Path -Path "${PWD}" -ChildPath "artifacts/ci-run-$RunId"
New-Item -ItemType Directory -Path $base -Force | Out-Null

$downloadLog = Join-Path $base "download.log"
$parseLog = Join-Path $base "parse.log"
$testLog = Join-Path $base "test.log"

Write-Host "Starting full debug pipeline for run $RunId -> $base"

function Run-Command($cmd, $outFile) {
  Write-Host "-> Running: $cmd"
  try {
    # Use Invoke-Expression to run the command string in the current shell
    # This avoids nested PowerShell quoting issues when the command contains
    # complex quoting (e.g. dotnet test filters/loggers).
    Invoke-Expression $cmd 2>&1 | Tee-Object -FilePath $outFile
    return $LASTEXITCODE
  } catch {
    $_ | Out-String | Tee-Object -FilePath $outFile
    return 1
  }
}

# 1) Try gh run download
$ghCmd = "gh run download $RunId --dir '$base'"
$rc = Run-Command $ghCmd $downloadLog
if ($rc -ne 0) {
  Write-Warning "gh failed or unauthenticated (see $downloadLog). Falling back to Python downloader."
  # 2) Fallback to python downloader script
  $pyCmd = "python .\scripts\download_artifacts.py --run-id $RunId --out $base"
  if ($Token) { $pyCmd += " --token $Token" }
  $rc2 = Run-Command $pyCmd $downloadLog
  if ($rc2 -ne 0) {
    Write-Warning "Python downloader failed (see $downloadLog). You may need to set GITHUB_TOKEN or make the repo public."
  }
}

# 3) Parse downloaded artifacts
$parseCmd = "python .\scripts\parse_final_report.py --src $base --out $base\ci-analysis.json"
Run-Command $parseCmd $parseLog | Out-Null

# 4) Run focused ShellRunner tests locally to try to reproduce
Write-Host "Running ShellRunner unit tests (may take a moment)"
$testProject = 'server/USBDeviceManager.Tests/USBDeviceManager.Tests.csproj'
$testCmd = "dotnet test $testProject --configuration Debug --filter \"FullyQualifiedName~ShellRunnerTests\" --logger \"trx;LogFileName=shellrunner-local-run.trx\""
Run-Command $testCmd $testLog | Out-Null

# 5) Summarize results
Write-Host "\n=== Summary ==="
Write-Host "Artifacts and logs placed in: $base"
Get-ChildItem -Path $base -Recurse -File | Select-Object FullName, Length | Format-Table

if (Test-Path (Join-Path $base 'ci-analysis.json')) {
  Write-Host "ci-analysis.json present -> showing 200 lines"
  Get-Content (Join-Path $base 'ci-analysis.json') -TotalCount 200 | Select-Object -First 200
} else {
  Write-Warning "ci-analysis.json not found in $base"
}

Write-Host "Showing first 200 lines of test log (if present):"
if (Test-Path $testLog) { Get-Content $testLog -TotalCount 200 } else { Write-Host "No test log found at $testLog" }

Write-Host "\nFull debug pipeline finished. Provide the contents of $base (or attach ci-analysis.json and test log) and I'll continue." 
