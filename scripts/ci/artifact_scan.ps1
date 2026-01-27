param(
  [string]$ArtifactsDir = "artifacts",
  [string[]]$Forbidden = @('LITTLE_BEAST','sbatt','sbattywolf','BRNMTHF','Sbatta'),
  [string]$OutputJson = "artifact-scan-report.json"
)

# Recursively scan files for forbidden tokens and produce JSON report
$foundMatches = @()
Get-ChildItem -Path $ArtifactsDir -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
  $path = $_.FullName
  try {
    $lines = Get-Content -LiteralPath $path -ErrorAction Stop
  } catch {
    return
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
