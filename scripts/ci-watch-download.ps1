param(
    [string]$RunId = '21318769550',
    [string]$Repo = 'Sbatta/USBDeviceManager',
    [int]$PollSeconds = 10,
    [int]$MaxMinutes = 120
)

Write-Host "Watching run $RunId in repo $Repo (poll every $PollSeconds s, timeout $MaxMinutes min)"
$start = Get-Date
while (((Get-Date) - $start).TotalMinutes -lt $MaxMinutes) {
    $status = gh run view $RunId -R $Repo --json status --jq '.status' 2>$null
    if ($null -eq $status) {
        Write-Host "Unable to query run $RunId; retrying in $PollSeconds s"
        Start-Sleep -Seconds $PollSeconds
        continue
    }
    $status = $status.Trim('"')
    Write-Host "CI status: $status"
    if ($status -ne 'in_progress') { break }
    Start-Sleep -Seconds $PollSeconds
}

$conclusion = gh run view $RunId -R $Repo --json conclusion --jq '.conclusion' 2>$null
$conclusion = $conclusion.Trim('"')
Write-Host "Run $RunId finished with conclusion: $conclusion"

$dir = Join-Path $PWD "artifacts\ci-downloads\$RunId"
New-Item -ItemType Directory -Force -Path $dir | Out-Null

Write-Host "Downloading artifacts for run $RunId to $dir"
if (-not (gh run download $RunId -R $Repo --dir $dir)) {
    Write-Warning "gh run download returned non-zero exit code or failed."
}

$html = Get-ChildItem -Path $dir -Recurse -Filter *.html -ErrorAction SilentlyContinue | Select-Object -First 1
if ($html) {
    Write-Host "Opening report: $($html.FullName)"
    Start-Process $html.FullName
} else {
    Write-Host 'No HTML file found in downloaded artifacts. Listing contents:'
    Get-ChildItem -Path $dir -Recurse | ForEach-Object { Write-Host $_.FullName }
}
