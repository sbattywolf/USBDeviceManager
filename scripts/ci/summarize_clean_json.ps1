param(
    [string]$JsonPath = "E:\\Workspaces\\Git\\SimRacing\\USBDeviceManager\\artifacts\\artifact-scan-streamed-full-clean.json",
    [string]$OutSummary = "E:\\Workspaces\\Git\\SimRacing\\USBDeviceManager\\artifacts\\artifact-scan-summary-clean.txt",
    [int]$SampleLimit = 15
)
if (-not (Test-Path $JsonPath)) { Write-Error "Missing: $JsonPath"; exit 2 }
$s = Get-Content -Raw -LiteralPath $JsonPath
try { $items = $s | ConvertFrom-Json -ErrorAction Stop } catch { Write-Error "ConvertFrom-Json failed: $($_.Exception.Message)"; exit 3 }
$total = $items.Count
$tokenGroups = $items | Group-Object -Property token | Sort-Object Count -Descending
$pathGroups = $items | Group-Object -Property path | Sort-Object Count -Descending
$sb = New-Object System.Text.StringBuilder
$sb.AppendLine("Clean JSON summary for: $JsonPath") | Out-Null
$sb.AppendLine("Total objects: $total") | Out-Null
$sb.AppendLine("Distinct tokens: $($tokenGroups.Count)") | Out-Null
$sb.AppendLine("Distinct paths: $($pathGroups.Count)") | Out-Null
$sb.AppendLine("") | Out-Null
$sb.AppendLine("Top tokens:") | Out-Null
$tokenGroups | Select-Object -First 10 | ForEach-Object { $sb.AppendLine("$($_.Name) : $($_.Count)") | Out-Null }
$sb.AppendLine("") | Out-Null
$sb.AppendLine("Top paths:") | Out-Null
$pathGroups | Select-Object -First 10 | ForEach-Object { $sb.AppendLine("$($_.Name) : $($_.Count)") | Out-Null }
$sb.AppendLine("") | Out-Null
$sb.AppendLine("Samples (up to $SampleLimit):") | Out-Null
for ($i=0; $i -lt [Math]::Min($SampleLimit, $total); $i++) { $sb.AppendLine(($items[$i] | ConvertTo-Json -Depth 5 -Compress)) | Out-Null }
$sb.ToString() | Set-Content -LiteralPath $OutSummary -Encoding UTF8
Write-Host "Wrote summary: $OutSummary (total: $total)"
