<#
.continue/tool/start-model.ps1

Lightweight helper to start a local model runtime (ollama or docker) with safe options.
Creates PID and marker files when actually started. Defaults to dry-run to avoid accidental starts.

Usage examples:
  .\start-model.ps1 -DryRun -Runtime ollama -Model "qwen2.5-coder:1.5b"
  .\start-model.ps1 -Runtime ollama -Model mymodel -Detach
#>

param(
    [ValidateSet('ollama','docker','none')][string]$Runtime = 'ollama',
    [string]$Model = '',
    [switch]$Detach,
    [object]$DryRun = $true,
    [string]$PidFile = '.continue/model.pid',
    [string]$MarkerFile = '.continue/model.marker',
    [int]$StartTimeoutSeconds = 10
)

function Write-Marker($path,$text){
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $text = $text -replace "\r|\n"," "
    Set-Content -Path $path -Value $text -Encoding UTF8
}

function Normalize-Bool($v) {
    if ($v -is [System.Management.Automation.SwitchParameter]) { return [bool]$v.IsPresent }
    return [bool]$v
}

$DryRun = Normalize-Bool $DryRun

Write-Host "start-model: Runtime=$Runtime Model=$Model DryRun=$DryRun Detach=$Detach"

if ($DryRun) {
    Write-Host "Dry-run: would start runtime '$Runtime' for model '$Model'. PID/marker files: $PidFile, $MarkerFile"
    exit 0
}

# Non-dry run: start the process
if ($Runtime -eq 'none') {
    Write-Error "Runtime 'none' selected; nothing to start."; exit 3
}

if ($Runtime -eq 'ollama') {
    if (-not (Get-Command ollama -ErrorAction SilentlyContinue)) {
        Write-Error "ollama not found in PATH. Install or use -DryRun first."; exit 4
    }
    $args = @()
    if ($Model) { $args += 'serve'; $args += '--model'; $args += $Model } else { $args += 'serve' }

    if ($Detach) {
        $proc = Start-Process -FilePath 'ollama' -ArgumentList $args -NoNewWindow -PassThru
        $pid = $proc.Id
    } else {
        $proc = Start-Process -FilePath 'ollama' -ArgumentList $args -NoNewWindow -Wait -PassThru
        $pid = $proc.Id
    }
} elseif ($Runtime -eq 'docker') {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Error "docker not found in PATH. Install Docker Desktop or use native runtimes."; exit 6
    }
    # Placeholder: user-supplied docker run command
    $dockerArgs = @('run','--gpus','all','--rm','-d','--name','local-llm')
    if ($Model) { $dockerArgs += $Model }
    try {
        if ($Detach) {
            $proc = Start-Process -FilePath 'docker' -ArgumentList $dockerArgs -NoNewWindow -PassThru
            $pid = $proc.Id
        } else {
            $proc = Start-Process -FilePath 'docker' -ArgumentList $dockerArgs -NoNewWindow -Wait -PassThru
            $pid = $proc.Id
        }
    } catch {
        Write-Error "Failed to start docker runtime: $($_.Exception.Message)"; exit 7
    }
} else {
    Write-Error "Unsupported runtime: $Runtime"; exit 5
}

# Resolve repository-root-relative pid/marker paths and write them
try {
    $repoRootCandidate = Join-Path $PSScriptRoot '..\..'
    try { $RepoRoot = (Resolve-Path -Path $repoRootCandidate -ErrorAction SilentlyContinue).Path } catch { $RepoRoot = (Get-Location).Path }

    $PidFile = $PidFile -replace '/','\\'
    $MarkerFile = $MarkerFile -replace '/','\\'
    if (-not [System.IO.Path]::IsPathRooted($PidFile)) { $PidFile = Join-Path $RepoRoot $PidFile }
    if (-not [System.IO.Path]::IsPathRooted($MarkerFile)) { $MarkerFile = Join-Path $RepoRoot $MarkerFile }

    $absPid = [int]$pid
    $dir = Split-Path $PidFile -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Set-Content -Path $PidFile -Value $absPid -Encoding ASCII
    Write-Marker $MarkerFile "Started $Runtime $Model pid=$absPid at $(Get-Date -Format o)"
    Write-Host "Started $Runtime (pid=$absPid). Marker: $MarkerFile"
} catch {
    Write-Warning "Failed to write pid/marker: $($_.Exception.Message)"
}

exit 0
