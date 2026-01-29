$nd = 'E:\Workspaces\Git\SimRacing\USBDeviceManager\artifacts\artifact-scan-streamed-full.ndjson'
$json = 'E:\Workspaces\Git\SimRacing\USBDeviceManager\artifacts\artifact-scan-streamed-full.json'
if (-not (Test-Path $nd)) { Write-Error "Missing $nd"; exit 2 }
$lines = Get-Content $nd | Where-Object { $_.Trim() -ne '' }
$body = $lines -join ",`n"
"Writing $json (entries: $($lines.Count))"
Set-Content -Path $json -Value ("[``n" + $body + "``n]") -Encoding UTF8
Write-Output "Wrote $json (entries: $($lines.Count))"
