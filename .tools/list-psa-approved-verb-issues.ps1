$js = Get-Content -Raw 'E:\Workspaces\Git\SimRacing\USBDeviceManager\.tools\psa-results.json' | ConvertFrom-Json
foreach ($entry in $js) {
    if ($entry.Diagnostics) {
        $issues = $entry.Diagnostics | Where-Object { $_.RuleName -eq 'PSUseApprovedVerbs' }
        if ($issues) {
            Write-Host $entry.File
            foreach ($i in $issues) { Write-Host '  -' $i.Message }
        }
    }
}
