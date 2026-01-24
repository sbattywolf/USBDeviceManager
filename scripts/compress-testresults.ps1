param(
    [string]$SourceDir = "server/USBDeviceManager.Tests/TestResults/artifacts",
    [string]$OutDir = "artifacts/enriched",
    [string]$RunId = $Env:GITHUB_RUN_ID
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$src = Join-Path $scriptDir $SourceDir
if (-not (Test-Path $src)) {
    Write-Host "Source artifacts directory not found: $src. Nothing to compress.";
    exit 0
}

if ([string]::IsNullOrWhiteSpace($RunId)) {
    $RunId = (Get-Date).ToString('yyyyMMdd-HHmmss')
}

$destDir = Join-Path $scriptDir $OutDir
New-Item -ItemType Directory -Path $destDir -Force | Out-Null

$zipName = "testresults-$RunId.zip"
$zipPath = Join-Path $destDir $zipName

Write-Host "Compressing test artifacts from '$src' to '$zipPath'"

try {
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    Compress-Archive -Path (Join-Path $src '*') -DestinationPath $zipPath -Force
    Write-Host "Created: $zipPath"
    exit 0
} catch {
    Write-Error "Failed to compress artifacts: $_"
    exit 1
}
