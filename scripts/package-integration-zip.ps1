# Package existing artifact and tmp files into artifacts/integration-report-full.zip
$paths = @()
if (Test-Path -Path 'artifacts') {
    $paths += 'artifacts\*'
} else {
    Write-Error 'artifacts not found'
    exit 1
}
if (Test-Path -Path 'scripts\tmp') {
    $paths += 'scripts\tmp\*'
}
if (Test-Path -Path 'integration_artifacts') {
    $paths += 'integration_artifacts\*'
}
$dest = 'artifacts/integration-report-full.zip'
if (Test-Path -Path $dest) { Remove-Item -Path $dest -Force }
Compress-Archive -Path $paths -DestinationPath $dest -Force
if (Test-Path -Path $dest) {
    Write-Host "Created: $(Resolve-Path $dest)"
} else {
    Write-Error 'Zip not created'
}
