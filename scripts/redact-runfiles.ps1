param(
    [switch]$Run
)

$files = @('run_details.json','run_artifacts.json')
$backupRoot = '.sanitize-backup'
$branch = 'ci/sanitize-personal-info'

Write-Host "Preparing to scan and redact: $($files -join ', ')"

$candidates = @()
foreach ($f in $files) {
    if (Test-Path $f) { $candidates += $f }
}

if ($candidates.Count -eq 0) {
    Write-Host "No target files found."
    exit 0
}

foreach ($f in $candidates) {
    Write-Host "Found: $f"
}

if (-not $Run) {
    Write-Host "Dry-run: no changes will be made. Rerun with -Run to apply redactions."
    exit 0
}

foreach ($f in $candidates) {
    $orig = Get-Content -Raw -LiteralPath $f
    $backupPath = Join-Path $backupRoot $f
    $backupDir = Split-Path $backupPath -Parent
    if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }
    Set-Content -LiteralPath $backupPath -Value $orig -Force

    # Redact owner names and usernames previously used
    $redacted = $orig -replace '(?i)\b(sbattywolf|Sbatta)\b','REDACTED'

    # Redact GitHub and API URLs
    $redacted = [regex]::Replace($redacted, 'https?://[^"\s,}]+','REDACTED_URL')

    Set-Content -LiteralPath $f -Value $redacted -Force
    Write-Host "Patched: $f -> backup saved to $backupPath"
}

Write-Host "Staging changes and committing on branch $branch"
& git checkout -B $branch
& git add -A
& git commit -m "ci(sanitize): redact run_details.json and run_artifacts.json" 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "No changes to commit or commit failed."; exit 0 }
Write-Host "Committed changes. Pushing..."
& git push origin $branch 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Push failed; attempting fetch/rebase and push."
    & git fetch origin
    & git pull --rebase origin $branch
    & git push origin $branch
    if ($LASTEXITCODE -ne 0) { Write-Host "Push still failed. Inspect branch."; exit 2 }
}
Write-Host "Push succeeded."
