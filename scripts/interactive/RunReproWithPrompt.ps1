<#
Example runner showing how to use PromptHelper to drive the repro test interactively.

This script does not assume CI execution — it's a local helper for developers.
#>

param(
    [switch]$RunTests,
    [string]$DbPath = '',
    [switch]$AutoConfirm
)

try {
    . "$PSScriptRoot\PromptHelper.ps1"
} catch {
    Write-Error "Failed to load PromptHelper.ps1: $_"
    exit 2
}

    try {
    # Ask for an optional DB path override (empty = let test factory choose)
    if ($DbPath) {
        $dbPath = $DbPath
    } else {
        $dbPath = Read-NonEmptyString -Prompt "Optional: enter DB path to use (leave empty to let factory choose)" -Default ""
    }

    # Confirm the user wants to proceed
    if ($AutoConfirm) {
        $confirm = 'yes'
    } else {
        $confirm = Read-NonEmptyString -Prompt "Proceed to run the repro test? Type 'yes' to proceed" -Default "no"
    }
    if ($confirm -ne 'yes') {
        Write-Host "Aborting per user input." -ForegroundColor Yellow
        exit 1
    }

    # Set environment variable for repro gating
    $env:RUN_DB_REPRO = '1'
    if ($dbPath) { $env:SIMRACING_DEBUG_DBPATH = $dbPath }

    if ($RunTests) {
        Write-Host "Running repro test..."
        dotnet test "E:\Workspaces\Git\SimRacing\USBDeviceManager\server\USBDeviceManager.Tests\USBDeviceManager.Tests.csproj" --filter FullyQualifiedName~DbDeleteReproTests -v minimal
        # After running tests, gather any runtime TestResults/artifacts into the repo-level artifacts
        try {
            Write-Host "Gathering runtime artifacts into repo TestResults/artifacts..."
            $root = Resolve-Path "$PSScriptRoot\..\.."
            $repoArtifacts = Join-Path $root 'server\USBDeviceManager.Tests\TestResults\artifacts'
            New-Item -ItemType Directory -Force -Path $repoArtifacts | Out-Null

            $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'

            $serverRoot = Join-Path $root 'server'
            $srcDirs = Get-ChildItem -Path $serverRoot -Recurse -Directory -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match '\\TestResults\\artifacts$' -or $_.FullName -match '\\bin\\.*\\TestResults\\artifacts$' }
            foreach ($d in $srcDirs) {
                try {
                    $relative = $d.FullName.Replace($root.Path, '').TrimStart('\') -replace '[\\:\/]','_'
                    $subdest = Join-Path $repoArtifacts ("$relative`_$stamp")
                    New-Item -ItemType Directory -Force -Path $subdest | Out-Null
                    Copy-Item -Path (Join-Path $d.FullName '*') -Destination $subdest -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Host "Copied artifacts from $($d.FullName) -> $subdest"
                } catch {
                    Write-Host "Failed to copy artifacts from $($d.FullName): $_"
                }
            }
        } catch {
            Write-Host "Artifact gather failed: $_"
        }
    } else {
        Write-Host "Ready to run repro. To execute tests, run this script with -RunTests or run the dotnet test command manually." -ForegroundColor Green
    }
}
catch {
    Write-Error "Interactive run aborted: $_"
    exit 3
}
