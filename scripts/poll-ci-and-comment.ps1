$pr = 27
$branch = 'ci/trx-upload-fix'
$max = 60
$i = 0
$runs = $null
while ($i -lt $max) {
    try {
        $json = gh run list --branch $branch --limit 50 --json name,status,conclusion,url 2>$null
    } catch {
        $json = $null
    }
    if (-not $json) {
        Write-Output 'No workflow runs found yet.'
        Start-Sleep -Seconds 10
        $i++
        continue
    }
    $runs = $json | ConvertFrom-Json
    foreach ($r in $runs) { Write-Output ("{0} | status:{1} | conclusion:{2} | {3}" -f $r.name, $r.status, $r.conclusion, $r.url) }
    $inprog = $runs | Where-Object { $_.status -ne 'completed' }
    if ($inprog) {
        Write-Output 'Some runs are still in-progress; sleeping 10s.'
        Start-Sleep -Seconds 10
        $i++
        continue
    }
    Write-Output 'All runs on branch completed.'
    break
}
if (-not $runs) { Write-Output 'Timed out or no runs discovered.'; exit 2 }

$failed = $runs | Where-Object { $_.conclusion -ne 'success' }
if ($failed) {
    $body = "CI runs for branch $branch completed with failures:`n`n"
    foreach ($f in $failed) { $body += "- $($f.name): $($f.conclusion) - $($f.url)`n" }
    gh pr comment $pr --body $body
    Write-Output 'Posted PR comment with failures.'
    exit 1
} else {
    gh pr comment $pr --body "CI runs for branch $branch completed: all success."
    Write-Output 'Posted PR comment: all success.'
    exit 0
}
