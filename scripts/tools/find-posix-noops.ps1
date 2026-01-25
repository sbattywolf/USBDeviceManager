<#
Scans the repository for POSIX no-op patterns (`; true;`, `|| true`) and
classifies matches by file extension so we can decide safe fixes.

Usage:
  pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/tools/find-posix-noops.ps1
#>

Param()

$patterns = @('; true;','|| true')
$root = Get-Location

Write-Output "Scanning repository for POSIX no-op patterns..."

$matches = @()
foreach ($p in $patterns) {
    $found = git grep -n --line-number --break -- "${p}" -- . 2>$null | ForEach-Object {
        $_
    }
    if ($found) { $matches += $found }
}

if (-not $matches) {
    Write-Output "No matches found."
    exit 0
}

$groups = @{}
foreach ($m in $matches) {
    $parts = $m -split ':',3
    if ($parts.Count -lt 3) { continue }
    $path = $parts[0]
    $lineno = $parts[1]
    $line = $parts[2]
    $ext = [IO.Path]::GetExtension($path)
    if (-not $groups.ContainsKey($ext)) { $groups[$ext] = @() }
    $groups[$ext] += [PSCustomObject]@{ Path = $path; Line = $lineno; Text = $line }
}

Write-Output "Found matches grouped by file extension:`n"
foreach ($k in $groups.Keys | Sort-Object) {
    $count = $groups[$k].Count
    Write-Output "- $k : $count match(es)"
}

Write-Output "`nSample hits (first 200 lines):`n"
$printed = 0
foreach ($k in $groups.Keys | Sort-Object) {
    Write-Output "Extension: $k"
    foreach ($item in $groups[$k]) {
        Write-Output "  $($item.Path):$($item.Line) -> $($item.Text.Trim())"
        $printed += 1
        if ($printed -ge 200) { break }
    }
    if ($printed -ge 200) { break }
}

Write-Output "`nSuggested next steps:`n"
Write-Output "- Review matches for `.ps1` files (PowerShell) and remove/replace POSIX constructs."
Write-Output "- For `.sh` or other shell scripts, keep `|| true` if intended; consider invoking under bash explicitly from PowerShell."
Write-Output "- For logs or generated files, ignore changes."
Write-Output "- After deciding on a small safe set, create focused patches and run parse-checks / CI dry runs."

exit 0

# CI trigger marker: small non-doc change to cause full CI to run on push
