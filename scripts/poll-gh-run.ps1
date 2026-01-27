param(
    [string]$RunId = '21295514078',
    [int]$TimeoutMinutes = 30,
    [string]$Repo = 'Sbatta/USBDeviceManager'
)

$end = (Get-Date).AddMinutes($TimeoutMinutes)
Write-Host "Polling run $RunId in $Repo until completion (timeout ${TimeoutMinutes}m)..."
while((Get-Date) -lt $end) {
    try {
        $raw = & gh run view $RunId --repo $Repo --json status,conclusion 2>$null
    } catch {
        $raw = $null
    }
    if ($raw) {
        try { $r = $raw | ConvertFrom-Json } catch { $r = $null }
    } else { $r = $null }

    if (-not $r) {
        Write-Host "No run info yet; sleeping 10s..."
    } else {
        Write-Host ("status={0} conclusion={1}" -f $r.status, $r.conclusion)
        if ($r.status -eq 'completed') { break }
    }
    Start-Sleep -Seconds 10
}

if ((Get-Date) -ge $end) {
    Write-Host "Timeout waiting for run $RunId to complete."; exit 2
}

$logFile = "run-$RunId.log"
Write-Host "Fetching logs to $logFile"
& gh run view $RunId --repo $Repo --log > $logFile
Write-Host "Saved logs to $logFile"

Write-Host "Showing likely failure lines (context 2):"
Select-String -Path $logFile -Pattern "e2e-windows|build-and-test|ERROR|Exception|FAIL" -Context 2,2 | Out-Host
