# New parser: accumulate lines between matching top-level braces
param(
    [string]$NdjsonPath = "E:\\Workspaces\\Git\\SimRacing\\USBDeviceManager\\artifacts\\artifact-scan-streamed-full.ndjson",
    [string]$OutSummary = "E:\\Workspaces\\Git\\SimRacing\\USBDeviceManager\\artifacts\\artifact-scan-summary.txt",
    [string]$OutSamples = "E:\\Workspaces\\Git\\SimRacing\\USBDeviceManager\\artifacts\\artifact-scan-samples.json",
    [int]$SampleLimit = 15
)
if (-not (Test-Path $NdjsonPath)) { Write-Error "NDJSON not found: $NdjsonPath"; exit 2 }

$total = 0
$tokenCounts = @{}
$pathCounts = @{}
$samples = New-Object System.Collections.ArrayList

$inside = $false
$braceDepth = 0
$bufferLines = New-Object System.Collections.Generic.List[string]

# Process file line-by-line to handle pretty-printed objects without blank separators
Get-Content -LiteralPath $NdjsonPath | ForEach-Object {
    $line = $_
    $trim = $line.TrimStart()
    # detect start
    if (-not $inside -and $trim.StartsWith('{')) {
        $inside = $true
        $braceDepth = 0
        $bufferLines.Clear()
    }
    if ($inside) { $bufferLines.Add($line) }
    # count braces at top-level (ignore braces inside strings is complex; rely on common scan output not containing unescaped top-level braces)
    # increment depth for '{' and decrement for '}' found in the line
    $open = ([regex]::Matches($line, '\{')).Count
    $close = ([regex]::Matches($line, '\}')).Count
    $braceDepth += ($open - $close)
    if ($inside -and $braceDepth -le 0) {
        $inside = $false
        $jsonText = ($bufferLines -join "`n").Trim()
        try {
            $obj = $jsonText | ConvertFrom-Json -ErrorAction Stop
        } catch {
            # skip malformed block
            return
        }
        $total++
        if ($obj -and $obj.PSObject.Properties.Name) {
            if ($obj.PSObject.Properties.Name -contains 'token') {
                $t = [string]$obj.token
                if ($tokenCounts.ContainsKey($t)) { $tokenCounts[$t]++ } else { $tokenCounts[$t] = 1 }
            }
            if ($obj.PSObject.Properties.Name -contains 'path') {
                $p = [string]$obj.path
                if ($pathCounts.ContainsKey($p)) { $pathCounts[$p]++ } else { $pathCounts[$p] = 1 }
            }
        }
        if ($samples.Count -lt $SampleLimit) { $null = $samples.Add($obj) }
    }
}
# Prepare top lists
$topTokens = $tokenCounts.GetEnumerator() | Sort-Object -Property Value -Descending | Select-Object -First 10
$topPaths = $pathCounts.GetEnumerator() | Sort-Object -Property Value -Descending | Select-Object -First 10
# Write summary
$sb = New-Object System.Text.StringBuilder
$sb.AppendLine("NDJSON summary for: $NdjsonPath") | Out-Null
$sb.AppendLine("Total parsed objects: $total") | Out-Null
$sb.AppendLine("Distinct tokens: $($tokenCounts.Keys.Count)") | Out-Null
$sb.AppendLine("Distinct paths: $($pathCounts.Keys.Count)") | Out-Null
$sb.AppendLine("") | Out-Null
$sb.AppendLine("Top tokens:") | Out-Null
foreach ($e in $topTokens) { $sb.AppendLine("$($e.Name) : $($e.Value)") | Out-Null }
$sb.AppendLine("") | Out-Null
$sb.AppendLine("Top paths:") | Out-Null
foreach ($e in $topPaths) { $sb.AppendLine("$($e.Name) : $($e.Value)") | Out-Null }
$sb.AppendLine("") | Out-Null
$sb.AppendLine("Samples (up to $SampleLimit):") | Out-Null
for ($i=0; $i -lt $samples.Count; $i++) {
    $sobj = $samples[$i]
    $json = $sobj | ConvertTo-Json -Depth 5 -Compress
    $sb.AppendLine($json) | Out-Null
}
# Save files
$sb.ToString() | Set-Content -LiteralPath $OutSummary -Encoding UTF8
# Save samples as JSON array
$samples | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $OutSamples -Encoding UTF8
Write-Host "Wrote summary: $OutSummary (total: $total)"
Write-Host "Wrote samples: $OutSamples (samples: $($samples.Count))"
