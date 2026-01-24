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
        [switch]$AllowEmpty
    )

    while ($true) {
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
        [switch]$MustExist
    )

    while ($true) {
        $p = Read-Host $Prompt
        if ([string]::IsNullOrWhiteSpace($p)) {
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
