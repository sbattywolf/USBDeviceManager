param(
    [string]$RunId = '21331498334',
    [string]$Repo = 'sbattywolf/USBDeviceManager',
    [int]$MaxPolls = 12,
    [int]$PollSec = 10
)

New-Item -ItemType Directory -Force -Path "artifacts/ci-run-$RunId" | Out-Null

$i = 0
while ($i -lt $MaxPolls) {
    try {
        $status = gh run view $RunId --repo $Repo --json status --jq '.status' 2>$null
    } catch {
        $status = $null
    }
    Write-Host "Poll #$i status=$status"
    if ($status -eq 'completed') {
        Write-Host "Run completed - downloading logs and artifacts"
        gh run view $RunId --repo $Repo --log > "artifacts/ci-run-$RunId/log.txt"
        gh run download $RunId --repo $Repo --dir "artifacts/ci-run-$RunId"
        exit 0
    }
    Start-Sleep -Seconds $PollSec
    $i++
}

Write-Host "Timed out waiting for run $RunId to complete after $($MaxPolls * $PollSec) seconds"
exit 2
