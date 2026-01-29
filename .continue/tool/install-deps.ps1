<#
.continue/tool/install-deps.ps1

Detects and helps install local dependencies for running repo-local LLM agents.
Usage:
  .\install-deps.ps1 -Suggest      # print recommended install commands
  .\install-deps.ps1 -Yes          # run interactive checks and prompt to proceed

This script does not automatically download large model files. It detects
common runtimes (ollama), package managers (winget/choco), and tools (git, 7z).
#>

param(
    [switch]$Suggest,
    [switch]$Yes
)

function Check-Cmd($name) {
    return [bool](Get-Command $name -ErrorAction SilentlyContinue)
}

# Improved 7-Zip detection: checks PATH, common install locations, and uninstall registry entries.
function Check-7Zip {
    # PATH check
    if (Get-Command '7z' -ErrorAction SilentlyContinue) { return $true }

    # Common install locations
    $possible = @(
        "$env:ProgramFiles\7-Zip\7z.exe",
        "$env:ProgramFiles(x86)\7-Zip\7z.exe"
    )
    foreach ($p in $possible) { if (Test-Path $p) { return $true } }

    # Check uninstall registry entries (HKLM and Wow6432Node and current user)
    $regRoots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    foreach ($root in $regRoots) {
        try {
            $children = Get-ChildItem -Path $root -ErrorAction SilentlyContinue
            foreach ($c in $children) {
                $props = Get-ItemProperty -Path $c.PSPath -ErrorAction SilentlyContinue
                if ($props -and $props.DisplayName -and ($props.DisplayName -match '7-?Zip')) {
                    return $true
                }
            }
        } catch { }
    }

    return $false
}

Write-Host "Checking environment..."

$checks = @{}
$checks.ollama = Check-Cmd 'ollama'
$checks.git = Check-Cmd 'git'
$checks['7z'] = Check-7Zip
$checks.winget = Check-Cmd 'winget'
$checks.choco = Check-Cmd 'choco'
$checks.docker = Check-Cmd 'docker'

Write-Host "Results (OK = found, MISSING = not found):"
foreach ($k in $checks.Keys) {
    $status = if ($checks[$k]) { 'OK' } else { 'MISSING' }
    $note = switch ($k) {
        'docker' { ' (optional - only needed for container workflows)' }
        'choco'  { ' (package manager - optional; winget or manual installers work too)' }
        default  { '' }
    }
    Write-Host (" - {0,-8}: {1}{2}" -f $k, $status, $note)
}

if ($Suggest) {
    Write-Host "\nSuggested actions (copy-paste):"
    if (-not $checks.git) { Write-Host " - Install Git: https://git-scm.com/downloads" }
    if (-not $checks['7z']) { Write-Host " - Install 7-Zip (for some model packaging): https://www.7-zip.org/" }
    if (-not $checks.ollama) {
        Write-Host " - Install Ollama: see https://ollama.ai/docs for the Windows installer or use a package manager if available."
        if ($checks.winget) { Write-Host "   Example: winget install Ollama.Ollama" }
        if ($checks.choco)  { Write-Host "   Example (choco): choco install ollama -y" }
        Write-Host "   Note: choco is not required if you prefer winget or the manual installer on Windows."
    }
    if (-not $checks.docker) {
        Write-Host " - Docker not detected; Docker is optional unless you plan to run containerized workflows."
        Write-Host "   Alternatives: install Ollama via the Windows installer or winget, use Docker Desktop, or use WSL2 + docker for Linux containers."
    }

    Write-Host "\nNotes:"
    Write-Host " - I do not download models for you. After installing a runtime (e.g. ollama), follow its docs to pull models."
    Write-Host " - For machines with an RTX 3090, prefer GPU-enabled runtimes (ollama supports NVIDIA via proper driver/CUDA)."
    exit 0
}

if (-not $Yes) {
    Write-Host "Run with -Suggest to print commands, or -Yes to continue interactively." -ForegroundColor Yellow
    exit 2
}

# Interactive flow
if (-not $checks.git) {
    if ((Read-Host "Install Git now? (y/N)") -match '^[yY]') {
        Start-Process 'https://git-scm.com/downloads' -UseShellExecute
        Write-Host "Opened browser to Git download page."; Start-Sleep -Seconds 1
    }
}

if (-not $checks.ollama) {
    $choice = Read-Host "Install Ollama? (recommended) [y/N]"
    if ($choice -match '^[yY]') {
        if ($checks.winget) {
            Write-Host "Installing via winget..."
            winget install --id Ollama.Ollama -e --silent
        } elseif ($checks.choco) {
            Write-Host "Installing via choco..."
            choco install ollama -y
        } else {
            Write-Host "Please download and run the Windows installer from https://ollama.ai/docs" -ForegroundColor Cyan
            Start-Process 'https://ollama.ai/docs' -UseShellExecute
        }
    }
}

Write-Host "Done. Re-run with -Suggest to verify or inspect individual components." -ForegroundColor Green