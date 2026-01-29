$clean = '.\artifacts\artifact-scan-streamed-full-clean.json'
$tokenCsv = '.\artifacts\token_counts.csv'
$pathCsv = '.\artifacts\path_counts.csv'
$samplesJson = '.\artifacts\artifact-scan-samples.json'
$samplesCsv = '.\artifacts\artifact-scan-samples.csv'

if (-not (Test-Path $clean)) {
    Write-Error "Clean JSON not found: $clean"
    exit 1
}

$items = Get-Content -Raw -LiteralPath $clean | ConvertFrom-Json

$items | Group-Object -Property token | Select-Object @{Name='token';Expression={$_.Name}},@{Name='count';Expression={$_.Count}} | Export-Csv -NoTypeInformation -Path $tokenCsv
$items | Group-Object -Property path  | Select-Object @{Name='path';Expression={$_.Name}},@{Name='count';Expression={$_.Count}} | Export-Csv -NoTypeInformation -Path $pathCsv

if (Test-Path $samplesJson) {
    Get-Content -Raw -LiteralPath $samplesJson | ConvertFrom-Json | Select-Object token,path,line,text | Export-Csv -NoTypeInformation -Path $samplesCsv
}

Write-Host "WROTE CSVs: $tokenCsv, $pathCsv, $samplesCsv"