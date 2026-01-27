param(
    [switch]$Run
)

$search = 'sbattywolf'
$replacement = 'Sbatta'
$backupRoot = '.sanitize-backup'
$branch = 'ci/sanitize-personal-info'

Write-Host "Scanning repository for matches to: $search"

$files = & git grep -Il --line-number -e $search 2>$null | ForEach-Object { ($_ -split ":",2)[0] } | Sort-Object -Unique

if (-not $files -or $files.Count -eq 0) {
    Write-Host 'No candidate files found.'
    exit 0
}

Write-Host "Found $($files.Count) files. (Dry-run by default)"

foreach ($f in $files) {
    $content = Get-Content -Raw -LiteralPath $f
    if ($content -match $search) {
        Write-Host "Would patch: $f"
    }
}

if (-not $Run) {
    Write-Host "Dry-run complete. Rerun with -Run to apply changes."
    exit 0
}

Write-Host "Applying replacements and creating backups..."

foreach ($f in $files) {
    $orig = Get-Content -Raw -LiteralPath $f
    $patched = $orig -replace $search, $replacement
    if ($orig -ne $patched) {
        $backupPath = Join-Path $backupRoot $f
        $backupDir = Split-Path $backupPath -Parent
        if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }
        Set-Content -LiteralPath $backupPath -Value $orig -Force
        Set-Content -LiteralPath $f -Value $patched -Force
        Write-Host "Patched: $f -> backup saved to $backupPath"
    }
}

Write-Host "Staging changes and committing on branch $branch"

& git checkout -B $branch
& git add -A
$commitMsg = "ci(sanitize): replace sbattywolf -> Sbatta"
& git commit -m $commitMsg 2>$null

if ($LASTEXITCODE -ne 0) {
    Write-Host "No changes to commit or commit failed."
} else {
    Write-Host "Committed changes. Attempting to push $branch to origin."
    & git push origin $branch 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Push rejected; attempting to fetch/rebase and push again."
        & git fetch origin
        & git pull --rebase origin $branch
        & git push origin $branch
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Push still failed. Please inspect local branch and remote."
            exit 2
        }
    }
    Write-Host "Push succeeded."
}
