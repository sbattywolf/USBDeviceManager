param(
    [string]$Model = 'codellama/7b-instruct',
    [string]$Runtime = 'ollama',
    [string]$StorePath = 'E:\llm-models',
    [int]$MaxModelSizeGB = 10,
    [object]$DryRun
)

# Normalize DryRun to a boolean. Support: SwitchParameter, bool, numeric, and string values.
function Normalize-DryRun($val) {
    if ($null -eq $val) { return $false }
    if ($val -is [System.Management.Automation.SwitchParameter]) { return $val.IsPresent }
    if ($val -is [bool]) { return [bool]$val }
    if ($val -is [int]) { return ($val -ne 0) }
    try {
        $s = [string]$val
        if ($s -match '^(true|t|1)$') { return $true }
        if ($s -match '^(false|f|0)$') { return $false }
    } catch { }
    return $false
}

$isDry = Normalize-DryRun $DryRun
Write-Host "quick-setup: model=$Model runtime=$Runtime store=$StorePath maxGB=$MaxModelSizeGB dryrun=$isDry"

$installScript = Join-Path -Path (Join-Path -Path (Get-Location) -ChildPath '.continue\tool') -ChildPath 'install-deps.ps1'
$pullScript = Join-Path -Path (Join-Path -Path (Get-Location) -ChildPath '.continue\tool') -ChildPath 'pull-model.ps1'

if ($isDry) {
    Write-Host "Dry-run: would run: `"& $installScript -DryRun`""
    Write-Host "Dry-run: would run: `"& $pullScript -Model '$Model' -Runtime '$Runtime' -StorePath '$StorePath' -MaxModelSizeGB $MaxModelSizeGB -DryRun`""
    exit 0
}

if (-not (Test-Path $installScript)) { Write-Error "Missing helper: $installScript"; exit 2 }
if (-not (Test-Path $pullScript)) { Write-Error "Missing helper: $pullScript"; exit 2 }

# Run installer (non-interactive consent when running quick-setup)
& $installScript -Yes
# Check for failure: prefer PowerShell success flag ($?) and fall back to $LASTEXITCODE when available.
if (-not $?) {
    $code = if ($LASTEXITCODE) { $LASTEXITCODE } else { 1 }
    Write-Error "install-deps failed (exit $code)"; exit $code
}

# Run pull-model with provided args (pass normalized DryRun)
& $pullScript -Model $Model -Runtime $Runtime -StorePath $StorePath -MaxModelSizeGB $MaxModelSizeGB -DryRun:$isDry
if (-not $?) {
    $code = if ($LASTEXITCODE) { $LASTEXITCODE } else { 2 }
    Write-Error "pull-model failed (exit $code)"; exit $code
}

Write-Host "quick-setup: completed successfully"
exit 0