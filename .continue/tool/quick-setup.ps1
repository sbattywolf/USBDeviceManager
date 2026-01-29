param(
    [string]$Model = 'codellama/7b-instruct',
    [string]$Runtime = 'ollama',
    [string]$StorePath = 'E:\llm-models',
    [int]$MaxModelSizeGB = 10,
    [switch]$DryRun
)

Write-Host "quick-setup: model=$Model runtime=$Runtime store=$StorePath maxGB=$MaxModelSizeGB dryrun=$($DryRun.IsPresent)"

$installScript = Join-Path -Path (Join-Path -Path (Get-Location) -ChildPath '.continue\tool') -ChildPath 'install-deps.ps1'
$pullScript = Join-Path -Path (Join-Path -Path (Get-Location) -ChildPath '.continue\tool') -ChildPath 'pull-model.ps1'

if ($DryRun) {
    Write-Host "Dry-run: would run: `"& $installScript -DryRun`""
    Write-Host "Dry-run: would run: `"& $pullScript -Model '$Model' -Runtime '$Runtime' -StorePath '$StorePath' -MaxModelSizeGB $MaxModelSizeGB -DryRun`""
    exit 0
}

if (-not (Test-Path $installScript)) { Write-Error "Missing helper: $installScript"; exit 2 }
if (-not (Test-Path $pullScript)) { Write-Error "Missing helper: $pullScript"; exit 2 }

# Run installer (non-interactive consent when running quick-setup)
& $installScript -Yes
if ($LASTEXITCODE -ne 0) { Write-Error "install-deps failed (exit $LASTEXITCODE)"; exit $LASTEXITCODE }

# Run pull-model with provided args
& $pullScript -Model $Model -Runtime $Runtime -StorePath $StorePath -MaxModelSizeGB $MaxModelSizeGB
if ($LASTEXITCODE -ne 0) { Write-Error "pull-model failed (exit $LASTEXITCODE)"; exit $LASTEXITCODE }

Write-Host "quick-setup: completed successfully"
exit 0