<#
PromptHelper.ps1 - improved prompt helpers

This file provides two helper functions used by interactive scripts:

- Read-NonEmptyString: reads a value, supports defaults, regex validation, retry and fallback.
- Read-ValidatedPath: reads a filesystem path, supports defaults, optional must-exist, auto-create and retry/fallback.

Both functions throw a terminating error on explicit 'cancel' input.

Example usage:
. .\PromptHelper.ps1
$val = Read-NonEmptyString -Prompt "Enter value" -Default "mydefault" -ValidateRegex '^[a-zA-Z0-9._-]+$' -RetryCount 3 -FallbackToDefault
$path = Read-ValidatedPath -Prompt "Enter path to DB (press Enter to use default)" -Default "artifacts/db.sqlite" -CreateIfMissing -RetryCount 3
#>

function Read-NonEmptyString {
    param(
        [string]$Prompt = "Enter value:",
        [string]$Default = $null,
        [switch]$AllowEmpty,
        [switch]$AutoAcceptDefault,
        [string]$ValidateRegex = $null,
        [int]$RetryCount = 3,
        [switch]$FallbackToDefault
    )

    $autoMode = $false
    if ($env:CI -or $env:NONINTERACTIVE -or $env:SIMRACING_NONINTERACTIVE) { $autoMode = $true }

    $attempt = 0
    while ($true) {
        if ($autoMode -and $AutoAcceptDefault -and $Default -ne $null) {
            Write-Host "Auto-mode: using default value." -ForegroundColor Yellow
            return $Default
        }
        $val = Read-Host $Prompt
        if ($val -eq 'cancel') { throw "User cancelled input" }
        if ([string]::IsNullOrWhiteSpace($val)) {
            if ($Default -ne $null) {
                Write-Host "Using default value." -ForegroundColor Yellow
                return $Default
            }
            if ($AllowEmpty) { return $val }
            Write-Host "Input cannot be empty. Type 'cancel' to abort or enter a value." -ForegroundColor Yellow
            $attempt++
        }
        else {
            if ($ValidateRegex -and -not ([string]::IsNullOrWhiteSpace($ValidateRegex))) {
                if (-not ($val -match $ValidateRegex)) {
                    Write-Host "Input does not match required format." -ForegroundColor Red
                    $attempt++
                } else {
                    return $val
                }
            } else {
                return $val
            }
        }

        if ($attempt -ge $RetryCount) {
            if ($FallbackToDefault -and $Default -ne $null) {
                Write-Host "Maximum attempts reached - using default." -ForegroundColor Yellow
                return $Default
            }
            throw ("Input validation failed after {0} attempts" -f $RetryCount)
        }
    }
}

function Read-ValidatedPath {
    param(
        [string]$Prompt = "Enter file path:",
        [switch]$MustExist,
        [string]$Default = $null,
        [switch]$AutoAcceptDefault,
        [int]$RetryCount = 3,
        [string]$ValidateRegex = $null,
        [switch]$CreateIfMissing,
        [switch]$FallbackToDefault
    )

    $autoMode = $false
    if ($env:CI -or $env:NONINTERACTIVE -or $env:SIMRACING_NONINTERACTIVE) { $autoMode = $true }
    $attempt = 0
    while ($true) {
        if ($autoMode -and $AutoAcceptDefault -and $Default -ne $null) {
            Write-Host "Auto-mode: using default path: $Default" -ForegroundColor Yellow
            if ($MustExist -and -not (Test-Path $Default)) {
                $parent = Split-Path -Parent $Default
                if ($CreateIfMissing -and -not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
                if ($CreateIfMissing) { try { New-Item -Path $Default -ItemType File -Force | Out-Null } catch { } }
            }
            return $Default
        }

        $p = Read-Host $Prompt
        if ($p -eq 'cancel') { throw "User cancelled input" }
        if ([string]::IsNullOrWhiteSpace($p)) {
            if ($Default -ne $null) {
                Write-Host "Using default path." -ForegroundColor Yellow
                if ($MustExist -and -not (Test-Path $Default)) {
                    $parent = Split-Path -Parent $Default
                    if ($CreateIfMissing -and -not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
                    if ($CreateIfMissing) { try { New-Item -Path $Default -ItemType File -Force | Out-Null } catch { } }
                }
                return $Default
            }
            Write-Host "Path cannot be empty. Type 'cancel' to abort." -ForegroundColor Yellow
            $attempt++
        }
        else {
            if ($ValidateRegex -and -not ([string]::IsNullOrWhiteSpace($ValidateRegex))) {
                if (-not ($p -match $ValidateRegex)) {
                    Write-Host "Path does not match required pattern." -ForegroundColor Red
                    $attempt++
                    if ($attempt -ge $RetryCount) { break }
                    continue
                }
            }
            if ($MustExist -and -not (Test-Path $p)) {
                if ($CreateIfMissing) {
                    $parent = Split-Path -Parent $p
                    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
                    try { New-Item -Path $p -ItemType File -Force | Out-Null } catch { }
                } else {
                    Write-Host "Path does not exist: $p" -ForegroundColor Red
                    $attempt++
                    if ($attempt -ge $RetryCount) { break }
                    continue
                }
            }
            return $p
        }

        if ($attempt -ge $RetryCount) { break }
    }

    # If we reached here, attempts exhausted
    if ($FallbackToDefault -and $Default -ne $null) {
        Write-Host "Attempts exhausted; falling back to default: $Default" -ForegroundColor Yellow
        return $Default
    }
    throw ("Path validation failed after {0} attempts" -f $RetryCount)
}

# Export-ModuleMember is not used because we dot-source this file in scripts.
