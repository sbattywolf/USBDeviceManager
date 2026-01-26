#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Windows Agent Uninstaller
.DESCRIPTION
    Removes Windows Agent installation and cleans up registry entries
.NOTES
    Version: 1.0.0
    Requires: PowerShell 5.1 or higher, Administrator privileges
#>

param(
    [Parameter(Mandatory=$false)]
    [switch]$Silent = $false,

    [Parameter(Mandatory=$false)]
    [switch]$KeepData = $false
    ,
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf = $false
)

# Set strict mode
Set-StrictMode -Version Latest

# Prefer script-scoped variables
if (-not $Script:LogFile) { $Script:LogFile = "$env:TEMP\SimRacingAgent_Uninstall_$(Get-Date -Format 'yyyyMMdd_HHmmss').log" }

function Write-UninstallerLog {
    param(
        [string]$Message,
        [string]$Level = "Info"
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "[$timestamp] [$Level] $Message"

    # Portable output for CI/headless environments
    Write-Output $logEntry

    # Write to log file
    $logEntry | Out-File -FilePath $Script:LogFile -Append -Encoding UTF8
}

# Wrapper to support dry-run/what-if behavior and centralized error handling for uninstall
function Invoke-UninstallAction {
    param([string]$Description, [scriptblock]$Action)

    if ($WhatIf) {
        Write-UninstallerLog "WHATIF: $Description" -Level Info
        return $true
    }

    try {
        & $Action
        return $true
    }
    catch {
        Write-UninstallerLog "Action failed: $Description - $($_.Exception.Message)" -Level Warning
        return $false
    }
}

function Get-InstallationInfo {
    <#
    .SYNOPSIS
        Get installation information from registry
    #>

    $installInfo = @{
        Found = $false
        InstallPath = ""
        Version = ""
        DataPath = ""
    }

    try {
        $registryPath = "HKLM:\SOFTWARE\SimRacingAgent"
        if (Test-Path $registryPath) {
            $regInfo = Get-ItemProperty -Path $registryPath
            $installInfo.Found = $true
            $installInfo.InstallPath = $regInfo.InstallPath
            $installInfo.Version = $regInfo.Version
            $installInfo.DataPath = $regInfo.DataPath
        }
    }
    catch {
        Write-UninstallerLog "Failed to read registry information: $_" -Level Warning
    }

    return $installInfo
}

function Stop-Agent {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    <#
    .SYNOPSIS
        Stop running agent instances
    #>

    Write-UninstallerLog "Stopping Windows Agent..." -Level Info

    try {
        # Try to stop gracefully via API
        try {
            $response = Invoke-RestMethod -Uri "http://localhost:8080/status" -Method GET -TimeoutSec 5
            if ($response) {
                Write-UninstallerLog "Agent is responding via API" -Level Info
            }
        }
        catch {
            Write-UninstallerLog "Agent not responding via API: $($_.Exception.Message)" -Level Warning
        }

        # Find and stop agent processes
        $agentProcesses = Get-Process | Where-Object {
            $_.ProcessName -like "*powershell*"
        }

        foreach ($process in $agentProcesses) {
            try {
                $processPath = $process.MainModule.FileName
                if ($processPath -like "*SimRacingAgent*" -or $process.CommandLine -like "*SimRacingAgent*") {
                    $actionDesc = "Stop process PID $($process.Id)"
                    if ($PSCmdlet.ShouldProcess('AgentProcess', $actionDesc)) {
                        Write-UninstallerLog "Stopping agent process PID: $($process.Id)" -Level Info
                        $process.Kill()
                    }
                    else {
                        Write-UninstallerLog "Skipping stop of PID $($process.Id) due to ShouldProcess" -Level Warning
                    }
                }
            }
            catch {
                Write-UninstallerLog "Error inspecting/stopping process PID $($process.Id): $($_.Exception.Message)" -Level Warning
            }
        }

        # Clean up lock file
        $lockFile = Join-Path $env:TEMP 'SimRacingAgent.lock'
        if (Test-Path $lockFile) {
            Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
            Write-UninstallerLog "Removed lock file" -Level Info
        }

        # Wait for processes to terminate
        Start-Sleep -Seconds 3

        Write-UninstallerLog "Agent stopped" -Level Success
        return $true
    }
    catch {
        Write-UninstallerLog "Error stopping agent: $_" -Level Warning
        return $false
    }
}

function Remove-InstallationFiles {
    [CmdletBinding(SupportsShouldProcess=$true)]
    <#
    .SYNOPSIS
        Remove installation files
    #>
    param(
        [string]$InstallPath
    )

    if ([string]::IsNullOrWhiteSpace($InstallPath) -or -not (Test-Path $InstallPath)) {
        Write-UninstallerLog "Installation path not found or invalid: $InstallPath" -Level Warning
        return $false
    }

    Write-UninstallerLog "Removing installation files from: $InstallPath" -Level Info

    if (-not $PSCmdlet.ShouldProcess($InstallPath, 'Remove installation directory')) {
        Write-UninstallerLog "Removal of installation directory skipped by ShouldProcess" -Level Warning
        return $false
    }

    # Use centralized uninstall action wrapper to respect WhatIf
    if (Invoke-UninstallAction -Description "Remove installation directory $InstallPath" -Action { Remove-Item -Path $InstallPath -Recurse -Force -ErrorAction Stop }) {
        Write-UninstallerLog "Installation files removed successfully" -Level Success
        return $true
    }
    else {
        Write-UninstallerLog "Failed to remove installation files" -Level Error
        return $false
    }
}

function Remove-DataFiles {
    [CmdletBinding(SupportsShouldProcess=$true)]
    <#
    .SYNOPSIS
        Remove user data files
    #>
    param(
        [string]$DataPath
    )

    if ([string]::IsNullOrWhiteSpace($DataPath)) {
        $DataPath = "$env:LOCALAPPDATA\SimRacingAgent"
    }

    if (-not (Test-Path $DataPath)) {
        Write-UninstallerLog "Data path not found: $DataPath" -Level Info
        return $true
    }

    Write-UninstallerLog "Removing data files from: $DataPath" -Level Info

    if (-not $PSCmdlet.ShouldProcess($DataPath, 'Remove data directory')) {
        Write-UninstallerLog "Removal of data directory skipped by ShouldProcess" -Level Warning
        return $false
    }

    if (Invoke-UninstallAction -Description "Remove data directory $DataPath" -Action { Remove-Item -Path $DataPath -Recurse -Force -ErrorAction Stop }) {
        Write-UninstallerLog "Data files removed successfully" -Level Success
        return $true
    }
    else {
        Write-UninstallerLog "Failed to remove data files" -Level Error
        return $false
    }
}

function Remove-RegistryEntries {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    <#
    .SYNOPSIS
        Remove registry entries
    #>

    Write-UninstallerLog "Removing registry entries..." -Level Info

    try {
        # Remove main registry entry
        $registryPath = "HKLM:\SOFTWARE\SimRacingAgent"
        if (Test-Path $registryPath) {
            if ($PSCmdlet.ShouldProcess($registryPath, 'Remove registry key')) {
                Invoke-UninstallAction -Description "Remove registry key $registryPath" -Action { Remove-Item -Path $registryPath -Recurse -Force }
                Write-UninstallerLog "Removed registry entry: $registryPath" -Level Info
            }
            else { Write-UninstallerLog "Skipped removal of registry entry: $registryPath" -Level Warning }
        }

        # Remove uninstall entry
        $uninstallPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\SimRacingAgent"
        if (Test-Path $uninstallPath) {
            if ($PSCmdlet.ShouldProcess($uninstallPath, 'Remove uninstall registry key')) {
                Invoke-UninstallAction -Description "Remove registry key $uninstallPath" -Action { Remove-Item -Path $uninstallPath -Recurse -Force }
                Write-UninstallerLog "Removed uninstall entry: $uninstallPath" -Level Info
            }
            else { Write-UninstallerLog "Skipped removal of uninstall entry: $uninstallPath" -Level Warning }
        }

        Write-UninstallerLog "Registry entries removed successfully" -Level Success
        return $true
    }
    catch {
        Write-UninstallerLog "Failed to remove registry entries: $_" -Level Error
        return $false
    }
}

function Remove-Shortcuts {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    <#
    .SYNOPSIS
        Remove desktop shortcuts and start menu entries
    #>

    Write-UninstallerLog "Removing shortcuts..." -Level Info

    try {
        # Remove desktop shortcut
        $desktopShortcut = "$env:USERPROFILE\Desktop\Windows Agent.lnk"
        if (Test-Path $desktopShortcut) {
            if ($PSCmdlet.ShouldProcess($desktopShortcut, 'Remove desktop shortcut')) {
                Invoke-UninstallAction -Description "Remove desktop shortcut $desktopShortcut" -Action { Remove-Item -Path $desktopShortcut -Force }
                Write-UninstallerLog "Removed desktop shortcut" -Level Info
            }
            else { Write-UninstallerLog "Skipped removal of desktop shortcut" -Level Warning }
        }

        # Remove start menu entries (if any were created)
        $startMenuPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Windows Agent.lnk"
        if (Test-Path $startMenuPath) {
            if ($PSCmdlet.ShouldProcess($startMenuPath, 'Remove start menu shortcut')) {
                Invoke-UninstallAction -Description "Remove start menu shortcut $startMenuPath" -Action { Remove-Item -Path $startMenuPath -Force }
                Write-UninstallerLog "Removed start menu shortcut" -Level Info
            }
            else { Write-UninstallerLog "Skipped removal of start menu shortcut" -Level Warning }
        }

        Write-UninstallerLog "Shortcuts removed successfully" -Level Success
        return $true
    }
    catch {
        Write-UninstallerLog "Failed to remove shortcuts: $_" -Level Warning
        return $false
    }
}

function Show-UninstallSummary {
    <#
    .SYNOPSIS
        Show uninstallation summary
    #>
    param(
        [bool]$DataRemoved
    )

    if (-not $Silent) {
        Write-UninstallerLog "" -Level Info
        Write-UninstallerLog "========================================" -Level Info
        Write-UninstallerLog " Windows Agent Uninstallation Complete " -Level Info
        Write-UninstallerLog "========================================" -Level Info
        Write-UninstallerLog "" -Level Info
        Write-UninstallerLog "Removed components:" -Level Info
        Write-UninstallerLog "  • Installation files" -Level Info
        Write-UninstallerLog "  • Registry entries" -Level Info
        Write-UninstallerLog "  • Desktop shortcuts" -Level Info

        if ($DataRemoved) {
                Write-UninstallerLog "  • User data and configuration files" -Level Info
        } else {
            Write-UninstallerLog "  • User data preserved (use -KeepData to change)" -Level Warning
        }

        Write-UninstallerLog "" -Level Info
        Write-UninstallerLog "Log file: $Script:LogFile" -Level Info
        Write-UninstallerLog "" -Level Info
        Write-UninstallerLog "Thank you for using Windows Agent!" -Level Success
        Write-UninstallerLog "========================================" -Level Info
    }
}

# Main uninstallation flow
try {
    Write-UninstallerLog "Windows Agent Uninstaller" -Level Info
    Write-UninstallerLog "Log file: $Script:LogFile" -Level Info
    Write-UninstallerLog "" -Level Info

    # Check administrator privileges
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$currentUser
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-UninstallerLog "Administrator privileges are required for uninstallation" -Level Error
        exit 1
    }

    # Get installation information
    $installInfo = Get-InstallationInfo

    if (-not $installInfo.Found) {
        Write-UninstallerLog "Windows Agent installation not found" -Level Warning
        Write-UninstallerLog "The agent may have been manually removed or never installed" -Level Info
        exit 0
    }

    Write-UninstallerLog "Found installation: $($installInfo.InstallPath)" -Level Info
    Write-UninstallerLog "Version: $($installInfo.Version)" -Level Info

    # Confirm uninstallation
    if (-not $Silent) {
        Write-UninstallerLog "This will remove Windows Agent from your system." -Level Warning
        $response = Read-Host "Do you want to continue? [Y/N]"
        if ($response.ToUpper() -ne 'Y') {
            Write-UninstallerLog "Uninstallation cancelled by user" -Level Info
            exit 0
        }

        if (-not $KeepData) {
            Write-UninstallerLog "`nThis will also remove all configuration and log files." -Level Warning
            $response = Read-Host "Do you want to keep your data files? [Y/N]"
            if ($response.ToUpper() -eq 'Y') {
                $KeepData = $true
            }
        }
    }

    # Stop agent
    Stop-Agent

    # Remove installation files
    if (-not (Remove-InstallationFiles -InstallPath $installInfo.InstallPath)) {
        Write-UninstallerLog "Failed to remove installation files, but continuing..." -Level Warning
    }

    # Remove data files (if requested)
    $dataRemoved = $false
    if (-not $KeepData) {
        $dataRemoved = Remove-DataFiles -DataPath $installInfo.DataPath
    } else {
        Write-UninstallerLog "Keeping user data files as requested" -Level Info
    }

    # Remove registry entries
    if (-not (Remove-RegistryEntries)) {
        Write-UninstallerLog "Failed to remove registry entries, but continuing..." -Level Warning
    }

    # Remove shortcuts
    Remove-Shortcuts | Out-Null

    # Show summary
    Show-UninstallSummary -DataRemoved $dataRemoved

    Write-UninstallerLog "Uninstallation completed successfully" -Level Success
    exit 0
}
catch {
    Write-UninstallerLog "Uninstallation failed with error: $_" -Level Error
    Write-UninstallerLog "Check the log file for details: $Script:LogFile" -Level Error
    exit 1
}



