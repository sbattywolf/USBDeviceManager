param(
  [string]$ArtifactsDir = "artifacts",
  [string[]]$Forbidden = @('LITTLE_BEAST','sbatt','sbattywolf','BRNMTHF','Sbatta'),
  [string]$OutputJson = "artifact-scan-report-filtered.json",
  [string]$ExcludeRegex = '\\enriched\\|enriched-errors|e2e-enriched|\\.trx$'
)

$foundMatches = @()

# Collect files but explicitly skip .trx files and any path segments named 'trx' or known enriched folders
$files = Get-ChildItem -Path $ArtifactsDir -Recurse -File -ErrorAction SilentlyContinue

foreach ($file in $files) {
  # skip binary or huge files heuristically by extension
  if ($file.Extension -ieq '.trx') { continue }
  $full = $file.FullName
  if ($full -match '\\trx\\' -or $full -match 'enriched-errors' -or $full -match '\\enriched\\' -or $full -match 'e2e-enriched') { continue }

  $path = $full
  try {
    $lines = Get-Content -LiteralPath $path -ErrorAction Stop
  } catch {
    continue
  }
  for ($i=0; $i -lt $lines.Count; $i++) {
    foreach ($tok in $Forbidden) {
      if ($lines[$i] -match [regex]::Escape($tok)) {
        $foundMatches += [pscustomobject]@{ path = $path; line = $i+1; token = $tok; text = $lines[$i].Trim() }
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
