$module = 'PSScriptAnalyzer'
if (-not (Get-Module -ListAvailable -Name $module)) {
    Write-Warning "PSScriptAnalyzer not installed. Install with: Install-Module -Name PSScriptAnalyzer -Scope CurrentUser"
    exit 2
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Resolve-Path (Join-Path $scriptDir '..\agent\SimRacingAgent')
$files = Get-ChildItem -Path $root -Recurse -Include *.ps1,*.psm1 -File

foreach ($f in $files) {
    Write-Output "Analyzing: $($f.FullName)"
    try {
        $results = Invoke-ScriptAnalyzer -Path $f.FullName -Severity Warning -Recurse
        if ($results) {
            $results | Select-Object @{n='File';e={$f.FullName}},RuleName,Severity,Line,Message | Format-Table -AutoSize
        }
    }
    catch {
        Write-Warning "ScriptAnalyzer failed on $($f.FullName): $($_.Exception.Message)"
    }
}

exit 0
