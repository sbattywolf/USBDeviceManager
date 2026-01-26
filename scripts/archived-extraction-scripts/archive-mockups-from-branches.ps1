#!/usr/bin/env pwsh
Set-StrictMode -Version Latest

# Archived copy of the temporary extractor used to produce artifacts/mockups
# Original location: scripts/archive-mockups-from-branches.ps1

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $scriptDir\..

if (-not (Test-Path .git)) {
    Write-Error 'This script must be run from the repository root.'
    exit 2
}

$outRoot = Join-Path (Get-Location) 'artifacts\mockups'
New-Item -ItemType Directory -Path $outRoot -Force | Out-Null

# Get candidate lines from the branch listing script
$lines = & .\scripts\find-images-in-branches.ps1 | Where-Object { $_ -match ':' }
if (-not $lines) { Write-Host 'No branch image entries found.'; Pop-Location; exit 0 }

$count = 0
foreach ($line in $lines) {
    $parts = $line -split ':',2
    if ($parts.Count -ne 2) { continue }
    $branch = $parts[0].Trim()
    $path = $parts[1].Trim()
    if (-not ($path -match '^(design/mockups|logs/screenshots)')) { continue }

    $branchSafe = $branch -replace '[\\/:]', '_' -replace '\s','_'
    $destDir = Join-Path $outRoot $branchSafe
    $relDir = Split-Path $path -Parent
    if ($relDir -ne '') { $destDir = Join-Path $destDir $relDir }
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null

    $leaf = Split-Path $path -Leaf
    $destFile = Join-Path $destDir $leaf

    $cmd = 'git show "' + $branch + ':' + $path + '" > "' + $destFile + '"'
    cmd.exe /c $cmd

    if (Test-Path $destFile) {
        $size = (Get-Item $destFile).Length
        if ($size -gt 0) {
            Write-Host ("Saved: {0}:{1} -> {2} ({3} bytes)" -f $branch, $path, $destFile, $size)
            $count++
        } else {
            Remove-Item $destFile -Force -ErrorAction SilentlyContinue
            Write-Host ("Skipped empty: {0}:{1}" -f $branch, $path)
        }
    } else {
        Write-Host ("Failed to extract: {0}:{1}" -f $branch, $path)
    }
}

Write-Host ("Finished. Files saved: {0}" -f $count)
Pop-Location
