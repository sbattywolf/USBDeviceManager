param(
    [string]$TrxPath = 'artifacts/integration.trx',
    [string]$LauncherOut = 'scripts/tmp/launcher.out',
    [string]$LauncherErr = 'scripts/tmp/launcher.err',
    [string]$ArtifactDir = 'artifacts',
    [string]$OutReport = 'artifacts/integration-report.txt'
)

function Safe-ReadTail {
    param([string]$Path, [int]$Lines = 200)
    if (Test-Path $Path) { return (Get-Content $Path -Tail $Lines -ErrorAction SilentlyContinue) -join "`n" }
    return "(missing: $Path)"
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutReport) | Out-Null

$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine("Integration Report - $(Get-Date -Format o)")
[void]$sb.AppendLine('')
[void]$sb.AppendLine("Artifacts directory listing:")
if (Test-Path $ArtifactDir) {
    Get-ChildItem -Path $ArtifactDir -Recurse -File | ForEach-Object { [void]$sb.AppendLine(("  {0,-10} {1,10} {2}" -f $_.Extension, $_.Length, $_.FullName)) }
} else { [void]$sb.AppendLine("  (no artifacts dir found)") }
[void]$sb.AppendLine('')

[void]$sb.AppendLine("TRX summary: $TrxPath")
if (Test-Path $TrxPath) {
    $xml = [xml](Get-Content $TrxPath -Raw)
    $resultSummary = $xml.TestRun.Results.Count
    try {
        $counts = @{}
        $xml.TestRun.Results.UnitTestResult | Group-Object -Property outcome | ForEach-Object { $counts[$_.Name] = $_.Count }
        foreach ($k in $counts.Keys) { [void]$sb.AppendLine("  {0}: {1}" -f $k, $counts[$k]) }
    } catch { [void]$sb.AppendLine("  (could not parse TRX contents)") }
} else { [void]$sb.AppendLine("  (trx missing)") }
[void]$sb.AppendLine('')

[void]$sb.AppendLine("Launcher stdout tail ($LauncherOut):")
[void]$sb.AppendLine((Safe-ReadTail -Path $LauncherOut -Lines 200))
[void]$sb.AppendLine('')
[void]$sb.AppendLine("Launcher stderr tail ($LauncherErr):")
[void]$sb.AppendLine((Safe-ReadTail -Path $LauncherErr -Lines 200))
[void]$sb.AppendLine('')

[void]$sb.AppendLine("Server logs tail (scripts/tmp/server.log):")
[void]$sb.AppendLine((Safe-ReadTail -Path 'scripts/tmp/server.log' -Lines 500))
[void]$sb.AppendLine('')

[void]$sb.AppendLine("Server stderr tail (scripts/tmp/server.err.log):")
[void]$sb.AppendLine((Safe-ReadTail -Path 'scripts/tmp/server.err.log' -Lines 500))

$sb.ToString() | Out-File -FilePath $OutReport -Encoding UTF8 -Force

Write-Host "Integration report generated: $OutReport"

exit 0
