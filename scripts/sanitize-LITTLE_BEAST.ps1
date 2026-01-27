param(
    [switch]$Run = $false,
    [string]$Branch = 'ci/sanitize-personal-info',
    [string]$BackupDir = '.sanitize-backup'
)

function Log { Write-Host "[sanitize]" -ForegroundColor Cyan $_ }

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "git not found in PATH. Install git or run from a git-enabled shell."
    exit 2
}

$pattern = 'LITTLE_BEAST'
$replacement = 'BRNMTHF'

if (-not (Test-Path $BackupDir)) { New-Item -ItemType Directory -Path $BackupDir | Out-Null }

$globs = @('*.trx','*.xml','*.json','*.txt','*.ps1','*.md')

$files = git ls-files --full-name | Where-Object { $_ -and (Test-Path $_) }

$candidates = @()
foreach ($g in $globs) {
    $candidates += $files | Where-Object { $_ -like "*$g" }
}

$candidates = $candidates | Sort-Object -Unique

if (-not $candidates) {
    Write-Host "No candidate files found."
    exit 0
}

$changes = @()
foreach ($f in $candidates) {
    try {
        $content = Get-Content -Raw -ErrorAction Stop $f
    } catch {
        continue
    }
    if ($content -match $pattern) {
        $changes += $f
    }
}

Write-Host "Found $($changes.Count) files containing '$pattern'."

if (-not $changes) { exit 0 }

if (-not $Run) {
    Write-Host "Dry run: files that would be changed:" -ForegroundColor Yellow
    $changes | ForEach-Object { Write-Host " - $_" }
    Write-Host "Run the script with -Run to apply changes, create a backup, commit and push to branch '$Branch'."
    exit 0
}

$currentBranch = (git rev-parse --abbrev-ref HEAD).Trim()
if ($currentBranch -ne $Branch) {
    Write-Host "Checking out branch '$Branch' (creating if needed)."
    if (-not (git show-ref --verify --quiet refs/heads/$Branch)) {
        git checkout -b $Branch
    } else {
        git checkout $Branch
    }
}

foreach ($f in $changes) {
    $dest = Join-Path $BackupDir ($f -replace '[\\/:]','_')
    $dir = Split-Path $dest -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Copy-Item -Path $f -Destination $dest -Force
    $content = Get-Content -Raw -ErrorAction Stop $f
    $new = $content -replace $pattern, $replacement
    Set-Content -Path $f -Value $new -Force
    Write-Host "Patched: $f"
}

git add --all
git diff --staged --quiet
if ($LASTEXITCODE -ne 0) {
    git commit -m "ci(sanitize): replace $pattern -> $replacement" 2>$null
    if ($LASTEXITCODE -eq 0) {
        git push -u origin $Branch
    } else {
        Write-Host "Commit failed or no changes to commit."
    }
} else {
    Write-Host "No staged changes to commit."
}

Write-Host "Sanitization complete. Backups saved under $BackupDir"
