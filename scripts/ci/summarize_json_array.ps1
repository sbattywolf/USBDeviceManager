# Summarize artifact-scan JSON array (produced from NDJSON)
$jsonPath = 'E:\Workspaces\Git\SimRacing\USBDeviceManager\artifacts\artifact-scan-streamed-full.json'
if (-not (Test-Path $jsonPath)) { Write-Error "Missing $jsonPath"; exit 2 }
Write-Output "Loading JSON array: $jsonPath"
$s = Get-Content -Raw -Path $jsonPath
try { $arr = $s | ConvertFrom-Json -ErrorAction Stop } catch { Write-Error "ConvertFrom-Json failed: $($_.Exception.Message)"; exit 3 }
$tokenCounts = @{}
$pathCounts = @{}
$total = 0
$samples = @()
foreach ($obj in $arr) {
  $total++
  $t = $obj.token
  $p = $obj.path
  if ($t) { if (-not $tokenCounts.ContainsKey($t)) { $tokenCounts[$t]=0 }; $tokenCounts[$t]++ }
  if ($p) { if (-not $pathCounts.ContainsKey($p)) { $pathCounts[$p]=0 }; $pathCounts[$p]++ }
  if ($samples.Count -lt 15) { $samples += [pscustomobject]@{ token=$t; path=$p; text=$obj.text; line=$obj.line } }
}
Write-Output "\nSummary:\nTotal matches: $total\nDistinct tokens: $($tokenCounts.Keys.Count)\nDistinct files: $($pathCounts.Keys.Count)\n"
Write-Output "Top tokens (top 10):"
$tokenCounts.GetEnumerator() | Sort-Object -Property Value -Descending | Select-Object -First 10 | ForEach-Object { Write-Output ("{0,6}   {1}" -f $_.Value,$_.Name) }
Write-Output "\nTop files (top 10):"
$pathCounts.GetEnumerator() | Sort-Object -Property Value -Descending | Select-Object -First 10 | ForEach-Object { Write-Output ("{0,6}   {1}" -f $_.Value,$_.Name) }
Write-Output "\nSample entries (up to 15):"
foreach ($samp in $samples) {
  Write-Output "- Token: $($samp.token) | Line: $($samp.line)"
  Write-Output "  Path: $($samp.path)"
  $snippet = $samp.text -replace "\r|\n"," "
  if ($snippet.Length -gt 240) { $snippet = $snippet.Substring(0,240) + '...' }
  Write-Output "  Text snippet: $snippet\n"
}
# write compact summary file
$summaryPath = 'E:\Workspaces\Git\SimRacing\USBDeviceManager\artifacts\artifact-scan-summary-json.txt'
$out = @()
$out += "Total matches: $total"
$out += "Distinct tokens: $($tokenCounts.Keys.Count)"
$out += "Distinct files: $($pathCounts.Keys.Count)"
$out += "Top tokens:"
$tokenCounts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 20 | ForEach-Object { $out += ("{0} {1}" -f $_.Value,$_.Name) }
$out += "Top files:"
$pathCounts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 20 | ForEach-Object { $out += ("{0} {1}" -f $_.Value,$_.Name) }
$out | Set-Content -Path $summaryPath -Encoding UTF8
Write-Output "Wrote summary to: $summaryPath"
