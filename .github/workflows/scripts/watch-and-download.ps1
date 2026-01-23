param(
    [Parameter(Mandatory=$true)]
    [long]$RunId
)
$timeoutMinutes = 30
$start = Get-Date
Write-Host "Watching run $RunId (timeout ${timeoutMinutes}m)..."
while ($true) {
    try {
        $s = gh run view $RunId --json status,conclusion | ConvertFrom-Json
    } catch {
        Write-Host "gh run view failed: $($_.Exception.Message); retrying in 5s..."
        Start-Sleep -Seconds 5
        continue
    }
    Write-Host "Status=$($s.status) Conclusion=$($s.conclusion)"
    if ($s.status -eq 'completed') { break }
    if ((Get-Date) - $start -gt ([TimeSpan]::FromMinutes($timeoutMinutes))) { throw "Timeout waiting for run to complete" }
    Start-Sleep -Seconds 10
}
$dir = "artifacts/ci-run-$RunId"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
try { gh run download $RunId -D $dir } catch { Write-Host "No artifacts to download or download failed: $($_.Exception.Message)" }
gh run view $RunId --log | Out-File -FilePath "$dir/run-$RunId.log" -Encoding utf8
Write-Host "Saved log and artifacts (if any) to: $dir"
