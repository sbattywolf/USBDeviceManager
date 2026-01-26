Write-Output "Building solution and generating analyzer report..."
dotnet build USBDeviceManager.sln -c Release 2>&1 | Tee-Object artifacts\build_full3.log

if (Test-Path artifacts\analyzer-raw.txt) { Remove-Item artifacts\analyzer-raw.txt -Force }

# Extract matches of analyzer codes (e.g., SA1117, CS8602, IDE0060) and include the full line
Select-String -Path artifacts\build_full3.log -Pattern '([A-Z]{2,}\d{3,})' -AllMatches | ForEach-Object {
    foreach ($m in $_.Matches) {
        "$($m.Value)|$($_.Line)" | Out-File artifacts\analyzer-raw.txt -Append
    }
}

if (-not (Test-Path artifacts\analyzer-raw.txt)) {
    Write-Output "No analyzer warnings found."
    exit 0
}

$content = Get-Content artifacts\analyzer-raw.txt | ForEach-Object { $parts = $_ -split '\\|',2; [PSCustomObject]@{Code=$parts[0];Line=$parts[1].Trim()} }
$grouped = $content | Group-Object Code | Sort-Object Name

"# Analyzer Report" | Out-File artifacts\analyzer-report.md -Encoding utf8

foreach ($g in $grouped) {
    ('## ' + $g.Name + ' (' + $g.Count + ')') | Out-File artifacts\analyzer-report.md -Append
    foreach ($i in $g.Group) { $i.Line | Out-File artifacts\analyzer-report.md -Append }
    '' | Out-File artifacts\analyzer-report.md -Append
}

Write-Output "Analyzer report written to artifacts/analyzer-report.md"