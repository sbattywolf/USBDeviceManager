<#
PromptHelper.ps1

Reusable interactive helpers for scripts and local test runs.

Functions:
- Read-NonEmptyString  : Prompt until non-empty string (optional default)
- Read-ValidatedPath   : Prompt until a valid path (optionally must exist)

Usage:
. .\PromptHelper.ps1         # dot-source to import functions into session
$val = Read-NonEmptyString -Prompt "Enter value" -Default "mydefault"
$path = Read-ValidatedPath -Prompt "Enter DB path" -MustExist
# Throws a terminating error on explicit 'cancel' input so callers can catch it
#>

function Read-NonEmptyString {
    [CmdletBinding()]
    param(
        [Parameter(Position=0)]
        [string]$Prompt = "Enter value:",
        [Parameter()]
        [string]$Default = $null,
        [switch]$AllowEmpty,
        [switch]$AutoAcceptDefault
    )

    $autoMode = $false
    if ($env:CI -or $env:NONINTERACTIVE -or $env:SIMRACING_NONINTERACTIVE) { $autoMode = $true }

    while ($true) {
        if ($autoMode -and $AutoAcceptDefault -and $Default -ne $null) {
            Write-Host "Auto-mode: using default value." -ForegroundColor Yellow
            return $Default
        }
        $val = Read-Host $Prompt
        if ([string]::IsNullOrWhiteSpace($val)) {
            if ($Default -ne $null) {
                Write-Host "Using default value." -ForegroundColor Yellow
                return $Default
            }
            if ($AllowEmpty) { return $val }
            if ($val -eq 'cancel') { throw "User cancelled input" }
            Write-Host "Input cannot be empty. Type 'cancel' to abort or enter a value." -ForegroundColor Yellow
            continue
        }
        return $val
    }
}

function Read-ValidatedPath {
    [CmdletBinding()]
    param(
        [Parameter(Position=0)]
        [string]$Prompt = "Enter file path:",
        [switch]$MustExist,
        [string]$Default = $null,
        [switch]$AutoAcceptDefault
    )
    $autoMode = $false
    if ($env:CI -or $env:NONINTERACTIVE -or $env:SIMRACING_NONINTERACTIVE) { $autoMode = $true }

    while ($true) {
        if ($autoMode -and $AutoAcceptDefault -and $Default -ne $null) {
            Write-Host "Auto-mode: using default path: $Default" -ForegroundColor Yellow
            if ($MustExist -and -not (Test-Path $Default)) {
                # Try to create the file if parent exists
                $parent = Split-Path -Parent $Default
                if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
                try { New-Item -Path $Default -ItemType File -Force | Out-Null } catch { }
            }
            return $Default
        }

        $p = Read-Host $Prompt
        if ([string]::IsNullOrWhiteSpace($p)) {
            if ($Default -ne $null) {
                Write-Host "Using default path." -ForegroundColor Yellow
                if ($MustExist -and -not (Test-Path $Default)) {
                    $parent = Split-Path -Parent $Default
                    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
                    try { New-Item -Path $Default -ItemType File -Force | Out-Null } catch { }
                }
                return $Default
            }
            Write-Host "Path cannot be empty. Type 'cancel' to abort." -ForegroundColor Yellow
            continue
        }
        if ($p -eq 'cancel') { throw "User cancelled input" }
        if ($MustExist -and -not (Test-Path $p)) {
            Write-Host "Path does not exist: $p" -ForegroundColor Red
            continue
        }
        return $p
    }
}

# Export-ModuleMember is not used because we dot-source this file in scripts.
