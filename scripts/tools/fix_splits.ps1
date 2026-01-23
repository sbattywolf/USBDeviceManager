param(
    [string]$File = "agent/SimRacingAgent.Tests/TestRunner.ps1"
)

$lines = Get-Content -LiteralPath $File -Raw -ErrorAction Stop -Encoding UTF8 -ReadCount 0
$lines = $lines -split "\r?\n"
$out = New-Object System.Collections.Generic.List[string]

for ($i=0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    $nextIndex = $i + 1
    if ($nextIndex -lt $lines.Count) {
        $next = $lines[$nextIndex]
    } else {
        $next = $null
    }

    if ($next -ne $null) {
        $nt = $next.TrimStart()
        if ($nt -match '^-(ForegroundColor|Encoding|ErrorAction|ReportPath|IncludePerformance|StopOnFirstFailure|Path|Depth|Format|TestCategories)\b') {
            $merged = $line.TrimEnd() + ' ' + $nt
            $out.Add($merged) | Out-Null
            $i++
            continue
        }
        # also merge cases where next line is a quoted continuation like '  $($var)" on next line
        if ($nt -match '^["\(]') {
            # if next line starts with opening quote or paren and current line ends with colon or text, merge
            if ($line.TrimEnd().EndsWith(':') -or $line.TrimEnd().EndsWith('"') -or $line.TrimEnd().EndsWith(')')) {
                $merged = $line.TrimEnd() + ' ' + $nt
                $out.Add($merged) | Out-Null
                $i++
                continue
            }
        }
    }

    $out.Add($line) | Out-Null
}

# Write back
Set-Content -LiteralPath $File -Value ($out -join "`r`n") -Encoding UTF8
Write-Host "Fixed splits in $File" -ForegroundColor Green
