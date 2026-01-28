param(
    [string[]]
    $TestInputs,
    [switch]
    $AutoAccept
)

# Config persistence file for interactive defaults
$ConfigFile = Join-Path -Path $PSScriptRoot -ChildPath 'interactive_config.json'

function Load-InteractiveConfig {
    if (Test-Path $ConfigFile) {
        try { return Get-Content -Path $ConfigFile -Raw | ConvertFrom-Json -ErrorAction Stop } catch { return $null }
    }
    return $null
}

function Save-InteractiveConfig($obj) {
    try {
        $json = $obj | ConvertTo-Json -Depth 5
        $json | Out-File -FilePath $ConfigFile -Encoding UTF8 -Force
        return $true
    } catch { return $false }
}

function Show-Menu {
    Clear-Host
    Write-Host "Interactive Path Entry"
    Write-Host "----------------------"
    Write-Host "Enter one or more file paths separated by ';' (semicolon)."
    Write-Host "Example: E:\\Workspaces\\Git\\SimRacing\\USBDeviceManager\\artifacts\\artifact-scan-streamed-full.ndjson;E:\\other\\file.ndjson"
    Write-Host "Press Enter (blank) to refresh the menu. Type 'quit' to exit."
}

# Helper: validate paths array
function Test-PathsExist($paths) {
    $invalid = @()
    foreach ($p in $paths) {
        $t = $p.Trim()
        if ($t -eq '') { continue }
        if (-not (Test-Path $t)) { $invalid += $t }
    }
    return $invalid
}

# Test mode iterator
$testIndex = 0
if ($TestInputs -and $TestInputs.Count -gt 0) { Write-Host "Running in TEST mode with $($TestInputs.Count) inputs." }

while ($true) {
    Show-Menu
    if ($TestInputs -and $testIndex -lt $TestInputs.Count) {
        $userInput = $TestInputs[$testIndex]
        Write-Host "[TEST] Input: $userInput"
        $testIndex++
    } elseif ($AutoAccept) {
        Write-Host "AutoAccept enabled; exiting with no selection."; break
    } else {
        $userInput = Read-Host -Prompt "Enter paths"
    }

    if ($null -eq $userInput -or $userInput.Trim() -eq '') {
        # Propose a default path: prefer saved config, fallback to example
        $cfg = Load-InteractiveConfig
        $defaultExample = '.\artifacts\artifact-scan-streamed-full.ndjson'
        if ($cfg -and $cfg.defaultPath) { $defaultPath = $cfg.defaultPath }
        else { if (Test-Path $defaultExample) { $defaultPath = (Resolve-Path $defaultExample).Path } else { $defaultPath = $defaultExample } }
        Write-Host "No input detected. Proposed default: $defaultPath" -ForegroundColor Cyan

        # Confirmation prompt
        if ($TestInputs -and $testIndex -lt $TestInputs.Count) {
            $conf = $TestInputs[$testIndex]; Write-Host "[TEST] Confirmation: $conf"; $testIndex++
        } else {
            $conf = Read-Host -Prompt "Use default? (y=Yes / n=No / q=Quit)"
        }
        switch ($conf.Trim().ToLower()) {
            'y' {
                $result = @{ selected = @($defaultPath); timestamp = (Get-Date).ToString('o') }
                # Persist accepted default for future runs
                $saveObj = @{ defaultPath = $defaultPath; updated = (Get-Date).ToString('o') }
                if (Save-InteractiveConfig $saveObj) { Write-Host "Saved default to $ConfigFile" -ForegroundColor DarkCyan }
                $result | ConvertTo-Json -Depth 5; break }
            'n' { Write-Host "Not using default. Refreshing menu..." -ForegroundColor Yellow; Start-Sleep -Milliseconds 300; continue }
            'q' { Write-Host 'Exiting.'; break }
            default { Write-Host "Unrecognized option '$conf' - refreshing menu." -ForegroundColor Red; Start-Sleep -Milliseconds 300; continue }
        }
    }

    if ($userInput.Trim().ToLower() -eq 'quit') { Write-Host 'Exiting.'; break }

    # Split input by semicolon or comma
    $parts = $userInput -split '[;,]'
    $parts = $parts | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }

    $invalid = Test-PathsExist $parts
    if ($invalid.Count -gt 0) {
        Write-Host "Invalid paths:" -ForegroundColor Red
        $invalid | ForEach-Object { Write-Host " - $_" }
        Write-Host "Please correct the above and try again. Refreshing menu..." -ForegroundColor Yellow
        Start-Sleep -Milliseconds 500
        continue
    }

    # Success: output the validated paths as JSON to stdout
    $result = @{ selected = $parts; timestamp = (Get-Date).ToString('o') }
    $result | ConvertTo-Json -Depth 5
    break
}
