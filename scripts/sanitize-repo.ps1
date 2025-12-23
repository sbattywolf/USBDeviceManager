<##
    scripts/sanitize-repo.ps1

    Small helper to detect machine-specific files and optionally remove them or prepare git cleanup commands.
    Use with `-WhatIf` to preview, or `-Apply` to perform the suggested cleanup.
##>

param(
    [switch]$Apply,
    [switch]$VerboseOutput
)

function Write-Log($m) { if ($VerboseOutput) { Write-Host $m } }

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..'))
Write-Host "Repository root: $repoRoot"

# Patterns to report
$patterns = @(
    '**/obj/**',
    '**/bin/**',
    '.tmp_*.*',
    '**/*.TestLogger.*',
    '**/*.nuget.*',
    '**/*.csproj.nuget.*'
)

Write-Host "Scanning for candidate machine-specific or generated files..."
$found = @()
foreach ($p in $patterns) {
    $matches = Get-ChildItem -Path $repoRoot -Recurse -Force -ErrorAction SilentlyContinue -Filter $p | Select-Object -ExpandProperty FullName -ErrorAction SilentlyContinue
    if ($matches) { $found += $matches }
}

if (-not $found) {
    Write-Host "No candidate generated files found by patterns."
} else {
    Write-Host "Found $($found.Count) candidate paths:"; $found | ForEach-Object { Write-Host " - $_" }
}

# Detect files containing obvious local paths/usernames
Write-Host "Scanning text files for 'C:\\Users\\' and repo-root absolute paths..."
$textFiles = Get-ChildItem -Path $repoRoot -Recurse -Include *.ps1,*.md,*.json,*.props,*.cache,*.dgspec.json -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer }
$sensitiveMatches = @()
foreach ($f in $textFiles) {
    try {
        $c = Get-Content -LiteralPath $f.FullName -ErrorAction Stop -Encoding UTF8
        if ($c -match 'C:\\Users\\' -or $c -match [regex]::Escape($env:USERPROFILE) -or $c -match [regex]::Escape($PWD.ProviderPath)) {
            $sensitiveMatches += $f.FullName
        }
    } catch { Write-Log "Skipping $($f.FullName) - $($_.Exception.Message)" }
}

if ($sensitiveMatches.Count -gt 0) {
    Write-Host "Files containing user/local paths:"
    $sensitiveMatches | ForEach-Object { Write-Host " - $_" }
}

if (-not $Apply) {
    Write-Host "\nDry run only. To apply cleanup run:`n    .\scripts\sanitize-repo.ps1 -Apply"
    if ($found.Count -gt 0) { Write-Host "Suggested git command to untrack generated files: `n    git rm -r --cached **/bin **/obj" }
    if ($sensitiveMatches.Count -gt 0) { Write-Host "You may want to manually sanitize or remove the listed files. I can apply these changes if you run with -Apply." }
    exit 0
}

# Apply phase
Write-Host "Applying cleanup..."

if ($found.Count -gt 0) {
    Write-Host "Removing generated output from git index (git must be installed)..."
    & git rm -r --cached --ignore-unmatch **/bin **/obj 2>$null
    Write-Host "Removing found directories from filesystem (will skip errors)..."
    foreach ($p in $found) {
        try { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue; Write-Log "Removed $p" } catch { Write-Log "Failed remove $p" }
    }
}

if ($sensitiveMatches.Count -gt 0) {
    Write-Host "Making simple sanitization replacements in detected files (creates .sanitized backup)."
    foreach ($f in $sensitiveMatches) {
        try {
            $content = Get-Content -LiteralPath $f -Raw -ErrorAction Stop
            $new = $content -replace [regex]::Escape($env:USERPROFILE), '<USERPROFILE>'
            $new = $new -replace 'C:\\Users\\[^\\/\s]+' , 'C:\\Users\\<USER>'
            $backup = $f + '.sanitized'
            Copy-Item -LiteralPath $f -Destination $backup -Force
            Set-Content -LiteralPath $f -Value $new -Encoding UTF8
            Write-Host "Sanitized: $f (backup: $backup)"
        } catch { Write-Host "Failed to sanitize $f: $($_.Exception.Message)" }
    }
}

Write-Host "Cleanup applied. Commit the removals and sanitized files:"
Write-Host "    git add -A && git commit -m 'chore: remove generated outputs and sanitize machine-specific files'"
Write-Host "If you want me to commit these changes, tell me and I will run the commit."