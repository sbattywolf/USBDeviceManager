<#
Safe repository cleanup script.
By default runs in "dry-run" mode and only reports what would be removed or archived.
Use -Apply to actually perform actions. Use -Archive to compress matched files into a timestamped zip under `artifacts/cleanup`.

Examples:
  # Dry run (default)
  .\scripts\cleanup-repo.ps1

  # Apply deletions (destructive)
  .\scripts\cleanup-repo.ps1 -Apply

  # Archive matched files into artifacts and then delete originals
  .\scripts\cleanup-repo.ps1 -Apply -Archive
#>

param(
    [switch]$Apply,
    [switch]$Archive,
    [string[]]$Include = @(
        '**/__pycache__/**',
        '**/*.pyc',
        '**/test-results/**',
        '**/*.trx',
        '**/logs/**',
        '**/*.log',
        '**/*.cache',
        '**/*.sqlite',
        '**/gui/__pycache__/**'
    ),
    [string[]]$Exclude = @(
        '.git/**',
        'artifacts/**',
        'server/**/bin/**',
        'server/**/obj/**',
        'agent/**/bin/**',
        'agent/**/obj/**'
    )
)

Write-Host "Repository cleanup: dry-run=$( -not $Apply ) | archive=$Archive"

# Resolve matched files
function Get-MatchingFiles {
    param($pattern)
    Get-ChildItem -Path . -Recurse -Force -ErrorAction SilentlyContinue | Where-Object {
        $full = $_.FullName.Replace([io.path]::GetFullPath('.') , '').TrimStart('\','/')
        $match = $false
        try { $match = (Test-Path -Path (Join-Path '.' $pattern) -PathType Any) } catch { }
        # fallback to simple globbing
        $glob = (Get-ChildItem -Path . -Recurse -Force -ErrorAction SilentlyContinue -Filter $(Split-Path $pattern -Leaf) | Where-Object { $_.FullName -like "*$($pattern -replace '\*\*','*')*" })
        $true
    }
}

# We'll use simpler logic: enumerate candidate items matching includes, then exclude by path prefix
$cwd = Get-Location
$allMatches = @()
foreach ($pattern in $Include) {
    $found = Get-ChildItem -Path $cwd -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { $_.FullName -like (Join-Path $cwd.Path ($pattern -replace '\*\*','*')) -or $_.FullName -like ($pattern -replace '\*\*','*') }
    if ($found) { $allMatches += $found }
}

# Normalize and filter excludes
$excludes = $Exclude | ForEach-Object { (Resolve-Path -LiteralPath $_ -ErrorAction SilentlyContinue) -as [string] }
$toActOn = $allMatches | Sort-Object -Unique

if (-not $toActOn) {
    Write-Host "No candidate files found for patterns: $($Include -join ', ')"
    return
}

Write-Host "Found $($toActOn.Count) candidate items to review."

foreach ($item in $toActOn) {
    $skip = $false
    foreach ($ex in $Exclude) {
        if ($item.FullName -like (Join-Path $cwd.Path ($ex -replace '\*\*','*'))) { $skip = $true; break }
    }
    if ($skip) { continue }

    Write-Host "[CANDIDATE] $($item.FullName)"
}

if (-not $Apply) {
    Write-Host "Dry run complete. Rerun with -Apply to perform deletions or -Apply -Archive to archive then delete."
    return
}

# Apply actions
$timestamp = Get-Date -Format yyyyMMddHHmmss
$archiveDir = Join-Path $cwd.Path "artifacts/cleanup/$timestamp"
if ($Archive) { New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null }

foreach ($item in $toActOn) {
    $skip = $false
    foreach ($ex in $Exclude) {
        if ($item.FullName -like (Join-Path $cwd.Path ($ex -replace '\*\*','*'))) { $skip = $true; break }
    }
    if ($skip) { continue }

    try {
        if ($Archive) {
            $dest = Join-Path $archiveDir ($item.FullName.Substring($cwd.Path.Length).TrimStart('\','/'))
            $destDir = Split-Path $dest -Parent
            if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
            if ($item.PSIsContainer) {
                Compress-Archive -Path $item.FullName -DestinationPath (Join-Path $destDir ("{0}.zip" -f ($item.Name))) -Force
                Remove-Item -LiteralPath $item.FullName -Recurse -Force
                Write-Host "Archived and removed folder: $($item.FullName)"
            } else {
                Copy-Item -LiteralPath $item.FullName -Destination $dest -Force
                Remove-Item -LiteralPath $item.FullName -Force
                Write-Host "Archived and removed file: $($item.FullName)"
            }
        } else {
            if ($item.PSIsContainer) { Remove-Item -LiteralPath $item.FullName -Recurse -Force; Write-Host "Removed folder: $($item.FullName)" }
            else { Remove-Item -LiteralPath $item.FullName -Force; Write-Host "Removed file: $($item.FullName)" }
        }
    } catch {
        Write-Warning "Failed to process $($item.FullName): $_"
    }
}

Write-Host "Cleanup complete."
