$js = Get-Content -Raw 'E:\Workspaces\Git\SimRacing\USBDeviceManager\.tools\psa-results.json' | ConvertFrom-Json
$summary = @()
foreach ($entry in $js) {
    if ($entry.Diagnostics) {
        $sev1 = $entry.Diagnostics | Where-Object { $_.Severity -ge 1 }
        if ($sev1.Count -gt 0) {
            $rules = ($sev1 | Group-Object RuleName | ForEach-Object { "$($_.Name):$($_.Count)" }) -join ', '
            $summary += [PSCustomObject]@{ File = $entry.File; Count = $sev1.Count; Rules = $rules }
        }
    }
}
$summary | Sort-Object -Property Count -Descending | Format-Table -AutoSize
$summary | ConvertTo-Json -Depth 5 | Out-File -LiteralPath 'E:\Workspaces\Git\SimRacing\USBDeviceManager\.tools\psa-summary.json' -Encoding utf8
Write-Host 'Wrote psa-summary.json'