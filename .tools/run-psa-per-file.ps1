param([string]$Root='E:\Workspaces\Git\SimRacing\USBDeviceManager\agent')
$results = @()
$files = Get-ChildItem -Path $Root -Recurse -File -Include *.ps1,*.psm1 -ErrorAction SilentlyContinue
foreach ($f in $files) {
    $item = [PSCustomObject]@{ File = $f.FullName; Diagnostics = @(); Error = $null }
    try {
        $diag = Invoke-ScriptAnalyzer -Path $f.FullName -ErrorAction Stop
        $item.Diagnostics = $diag | ForEach-Object {
            [PSCustomObject]@{
                RuleName = $_.RuleName
                Severity = $_.Severity
                Message = $_.Message
                Line = $_.Extent.StartLineNumber
                Column = $_.Extent.StartColumn
            }
        }
    } catch {
        $item.Error = $_.Exception.Message
    }
    $results += $item
}
$outPath = 'E:\Workspaces\Git\SimRacing\USBDeviceManager\.tools\psa-results.json'
$results | ConvertTo-Json -Depth 6 | Out-File -LiteralPath $outPath -Encoding utf8
Write-Host "Per-file analyzer run complete. Results at $outPath"