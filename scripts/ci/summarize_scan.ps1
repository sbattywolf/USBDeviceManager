# Summarize artifact-scan NDJSON (streamed)
$nd = 'E:\Workspaces\Git\SimRacing\USBDeviceManager\artifacts\artifact-scan-streamed-full.ndjson'
if (-not (Test-Path $nd)) { Write-Error "Missing $nd"; exit 2 }
$tokenCounts = @{}
$pathCounts = @{}
$samples = @()
$total = 0
Write-Output "Reading NDJSON: $nd"
# The NDJSON file contains pretty-printed JSON objects separated by blank lines.
# Accumulate lines until a blank line, then parse the joined block as JSON.
$buf = @()
Get-Content -Path $nd | ForEach-Object {
  $line = $_
  if ($line -match '^[\s]*$') {
    if ($buf.Count -gt 0) {
      $jsonBlock = $buf -join "`n"
      try {
        $obj = $jsonBlock | ConvertFrom-Json -ErrorAction Stop
      } catch {
        $buf = @(); continue
      }
      $total++
      $t = $obj.token
      $p = $obj.path
      if ($t) { if (-not $tokenCounts.ContainsKey($t)) { $tokenCounts[$t] = 0 }; $tokenCounts[$t]++ }
      if ($p) { if (-not $pathCounts.ContainsKey($p)) { $pathCounts[$p] = 0 }; $pathCounts[$p]++ }
      if ($samples.Count -lt 15) { $samples += [pscustomobject]@{ token=$t; path=$p; text=$obj.text; line=$obj.line } }
      $buf = @()
    }
  } else {
    $buf += $line
  }
}
# If file does not end with a blank line, process remaining buffer
if ($buf.Count -gt 0) {
  $jsonBlock = $buf -join "`n"
  try { $obj = $jsonBlock | ConvertFrom-Json -ErrorAction Stop } catch { $obj = $null }
  if ($obj) {
    $total++
    $t = $obj.token; $p = $obj.path
    if ($t) { if (-not $tokenCounts.ContainsKey($t)) { $tokenCounts[$t] = 0 }; $tokenCounts[$t]++ }
    if ($p) { if (-not $pathCounts.ContainsKey($p)) { $pathCounts[$p] = 0 }; $pathCounts[$p]++ }
    if ($samples.Count -lt 15) { $samples += [pscustomobject]@{ token=$t; path=$p; text=$obj.text; line=$obj.line } }
  }
}
Write-Output "\nSummary:\nTotal matches: $total\nDistinct tokens: $($tokenCounts.Keys.Count)\nDistinct files: $($pathCounts.Keys.Count)\n"
Write-Output "Top tokens (top 10):"
$tokenCounts.GetEnumerator() | Sort-Object -Property Value -Descending | Select-Object -First 10 | ForEach-Object { Write-Output ("{0,6}   {1}" -f $_.Value,$_.Name) }
Write-Output "\nTop files (top 10):"
$pathCounts.GetEnumerator() | Sort-Object -Property Value -Descending | Select-Object -First 10 | ForEach-Object { Write-Output ("{0,6}   {1}" -f $_.Value,$_.Name) }
Write-Output "\nSample entries (up to 15):"
foreach ($s in $samples) {
  Write-Output "- Token: $($s.token) | Line: $($s.line)"
  Write-Output "  Path: $($s.path)"
  $snippet = $s.text -replace "\r|\n"," "
  if ($snippet.Length -gt 240) { $snippet = $snippet.Substring(0,240) + '...'}
  Write-Output "  Text snippet: $snippet\n"
}
# Also write a compact summary file
$summaryPath = 'E:\Workspaces\Git\SimRacing\USBDeviceManager\artifacts\artifact-scan-summary.txt'
$out = @()
$out += "Total matches: $total"
$out += "Distinct tokens: $($tokenCounts.Keys.Count)"
$out += "Distinct files: $($pathCounts.Keys.Count)"
$out += "Top tokens:"
$tokenCounts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 20 | ForEach-Object { $out += ("{0} {1}" -f $_.Value, $_.Name) }
$out += "Top files:"
$pathCounts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 20 | ForEach-Object { $out += ("{0} {1}" -f $_.Value, $_.Name) }
$out | Set-Content -Path $summaryPath -Encoding UTF8
Write-Output "Wrote summary to: $summaryPath"
