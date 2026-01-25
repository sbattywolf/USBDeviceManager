param(
    [Parameter(Mandatory=$false)]
    [int]$RunId
)

function Download-ArtifactByName($runId, $name, $outDir) {
    Write-Host "Attempting to download artifact '$name' for run $runId to $outDir"
    gh run download $runId --name $name --dir $outDir 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Downloaded $name"
        return $true
    }
    return $false
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error "gh CLI not found. Install and authenticate 'gh' before running this script."
    exit 2
}

if (-not $RunId) {
    # pick latest CI run for current branch
    $sha = (git rev-parse HEAD).Trim()
    $runsJson = gh run list --limit 50 --json id,workflow,status,conclusion,headSha,headBranch,createdAt 2>$null
    if (-not $runsJson) { Write-Error 'No runs found'; exit 2 }
    $runs = $runsJson | ConvertFrom-Json
    $match = $runs | Where-Object { $_.headSha -eq $sha -and $_.workflow -eq 'CI' } | Select-Object -First 1
    if (-not $match) { $match = $runs | Where-Object { $_.workflow -eq 'CI' } | Sort-Object {[datetime]$_.createdAt} -Descending | Select-Object -First 1 }
    if (-not $match) { Write-Error 'No CI run found'; exit 2 }
    $RunId = $match.id
}

$outBase = "artifacts/ci-run-$RunId"
if (-not (Test-Path $outBase)) { New-Item -ItemType Directory -Path $outBase | Out-Null }

# list artifacts via GH API
$artifacts = gh api repos/$(git config --get remote.origin.url | sed -E 's#^https?://github.com/##; s/\.git$//')/actions/runs/$RunId/artifacts 2>$null | ConvertFrom-Json
if (-not $artifacts) {
    Write-Host "Falling back to full download for run $RunId"
    gh run download $RunId --dir $outBase
    exit 0
}

# choose artifact names likely to help triage integration startup
$wanted = @('integration','server','db-sample','pre-reset','test-results','TestResults','trx')
$foundAny = $false
foreach ($a in $artifacts.artifacts) {
    foreach ($w in $wanted) {
        if ($a.name -match $w) {
            Write-Host "Downloading artifact: $($a.name)"
            gh run download $RunId --name $a.name --dir $outBase
            $foundAny = $true
            break
        }
    }
}
if (-not $foundAny) {
    Write-Host "No integration-specific artifacts found; downloading all artifacts"
    gh run download $RunId --dir $outBase
}

Write-Host "Artifacts downloaded to $outBase"
exit 0
