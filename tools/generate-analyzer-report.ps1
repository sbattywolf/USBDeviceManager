param(
    [string]$Configuration = 'Release',
    [string]$Solution = 'USBDeviceManager.sln'
)

$artifactsDir = Join-Path (Resolve-Path .).Path 'artifacts'
if (-not (Test-Path $artifactsDir)) { New-Item -ItemType Directory -Path $artifactsDir | Out-Null }

Write-Host "Building solution $Solution (configuration: $Configuration) and collecting analyzer warnings..."

$buildCmd = "dotnet build `"$Solution`" -c $Configuration"
Write-Host "Running: $buildCmd"

$procInfo = New-Object System.Diagnostics.ProcessStartInfo
$procInfo.FileName = 'dotnet'
$procInfo.Arguments = "build `"$Solution`" -c $Configuration"
$procInfo.RedirectStandardOutput = $true
$procInfo.RedirectStandardError = $true
$procInfo.UseShellExecute = $false
$procInfo.CreateNoWindow = $true

$proc = New-Object System.Diagnostics.Process
$proc.StartInfo = $procInfo

$stdoutList = New-Object System.Collections.Generic.List[System.String]
$stderrList = New-Object System.Collections.Generic.List[System.String]

$proc.Start() | Out-Null

$outSub = Register-ObjectEvent -InputObject $proc -EventName 'OutputDataReceived' -Action { if ($EventArgs.Data) { [void]$stdoutList.Add($EventArgs.Data) } }
$errSub = Register-ObjectEvent -InputObject $proc -EventName 'ErrorDataReceived' -Action { if ($EventArgs.Data) { [void]$stderrList.Add($EventArgs.Data) } }

$proc.BeginOutputReadLine()
$proc.BeginErrorReadLine()

$proc.WaitForExit()
Start-Sleep -Milliseconds 50

$stdout = if ($stdoutList.Count -gt 0) { $stdoutList -join "`n" } else { "" }
$stderr = if ($stderrList.Count -gt 0) { $stderrList -join "`n" } else { "" }

try { Unregister-Event -SubscriptionId $outSub.Id -ErrorAction SilentlyContinue } catch { }
try { Unregister-Event -SubscriptionId $errSub.Id -ErrorAction SilentlyContinue } catch { }

$logPath = Join-Path $artifactsDir 'build_full_analyzer_output.log'
Set-Content -Path $logPath -Value ($stdout + "`r`n" + $stderr)
Write-Host "Build output written to $logPath"

# Parse warnings: lines like '...File.cs(17,2): warning SA1518: Message [project]' or 'CSC : warning SA1516: ... [project]'
$lines = ($stdout + "`r`n" + $stderr) -split "\r?\n"
$warningPattern = '^(?<file>.*?):\s*warning\s+(?<code>[A-Z]+\d+):\s*(?<msg>.*)'
$altPattern = '^\s*[^:]+:\s*warning\s+(?<code>[A-Z]+\d+):\s*(?<msg>.*)\s*\[.*\]$'

$groups = @{}
foreach ($line in $lines) {
    $m = [regex]::Match($line, $warningPattern)
    if (-not $m.Success) { $m = [regex]::Match($line, $altPattern) }
    if ($m.Success) {
        $code = $m.Groups['code'].Value
        $file = $m.Groups['file'].Value
        $msg = $m.Groups['msg'].Value.Trim()
        if (-not $groups.ContainsKey($code)) { $groups[$code] = @() }
        $groups[$code] += @{ file = $file; message = $msg; raw = $line }
    }
}

# Write grouped report
$reportPath = Join-Path $artifactsDir 'analyzer-report.md'
$report = @()
$report += "# Analyzer Report"
$report += "Generated: $(Get-Date -Format u)"
$report += ""
$totalWarnings = ($groups.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum
$report += "Total analyzer warnings found: $totalWarnings"
$report += ""
$report += "## Warnings by rule"
$report += ""
$sorted = $groups.Keys | Sort-Object { -$groups[$_].Count }
foreach ($code in $sorted) {
    $count = $groups[$code].Count
    $report += "- **$code**: $count occurrences"
}
$report += ""
$report += "---"
$report += ""

foreach ($code in $sorted) {
    $report += "## $code - $($groups[$code].Count) occurrences"
    $samples = $groups[$code] | Select-Object -First 8
    foreach ($s in $samples) {
        $report += "- $($s.file) : $($s.message)"
    }
    $report += ""
}

Set-Content -Path $reportPath -Value ($report -join "`r`n") -Encoding UTF8
Write-Host "Analyzer report written to $reportPath"

# Also write a simple grouped-warnings.txt
$groupedTxt = Join-Path $artifactsDir 'grouped-warnings.txt'
$out = @()
foreach ($code in $sorted) { $out += "$code,$($groups[$code].Count)" }
Set-Content -Path $groupedTxt -Value ($out -join "`r`n") -Encoding UTF8
Write-Host "Grouped warnings summary written to $groupedTxt"

Write-Host "Done."
