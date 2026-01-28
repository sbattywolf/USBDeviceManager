param(
  [string]$ArtifactsDir = "artifacts",
  [string[]]$Forbidden = @('LITTLE_BEAST','sbatt','sbattywolf','BRNMTHF','Sbatta'),
  [string]$OutputJson = "artifact-scan-report.json",
  [string]$ExcludeRegex = '\\.trx$|\\\\trx\\\\|enriched-errors|\\\\enriched\\\\|e2e-enriched',
  [string]$IgnoreFile = ''
)

# Read ignore patterns from file if provided
$ignorePatterns = @()
if ($IgnoreFile -and (Test-Path -LiteralPath $IgnoreFile)) {
  try {
    $ignorePatterns = Get-Content -LiteralPath $IgnoreFile -ErrorAction Stop | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
  } catch {
    Write-Warning "Failed to read ignore file: $IgnoreFile"
    $ignorePatterns = @()
  }
}

# Recursively scan files for forbidden tokens and produce JSON report
$foundMatches = @()
$files = Get-ChildItem -Path $ArtifactsDir -Recurse -File -ErrorAction SilentlyContinue

foreach ($file in $files) {
  $full = $file.FullName

  # skip by built-in exclude regex
  if ($full -match $ExcludeRegex) { continue }

  # skip if any user-provided ignore pattern matches the full path
  $skip = $false
  foreach ($p in $ignorePatterns) {
    if ($full -match $p) { $skip = $true; break }
  }
  if ($skip) { continue }

  try {
    $lines = Get-Content -LiteralPath $full -ErrorAction Stop
  } catch {
    continue
  }

  for ($i=0; $i -lt $lines.Count; $i++) {
    foreach ($tok in $Forbidden) {
      if ($lines[$i] -match [regex]::Escape($tok)) {
        $foundMatches += [pscustomobject]@{ path = $full; line = $i+1; token = $tok; text = $lines[$i].Trim() }
      }
    }
  }
}

$result = [pscustomobject]@{
  found = ($foundMatches.Count -gt 0)
  count = $foundMatches.Count
  matches = $foundMatches
}

$result | ConvertTo-Json -Depth 5 | Out-File -FilePath $OutputJson -Encoding utf8
if ($result.found) { Write-Error "Forbidden tokens found: $($result.count)"; exit 1 } else { Write-Output "No forbidden tokens found."; exit 0 }
