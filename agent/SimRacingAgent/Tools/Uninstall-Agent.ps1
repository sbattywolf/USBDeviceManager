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
)

# Set strict mode
Set-StrictMode -Version Latest

# Global variables
$Global:LogFile = "$env:TEMP\SimRacingAgent_Uninstall_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-UninstallerLog {
    param(
        [string]$Message,
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Write to console
    switch ($Level) {
        'Info'    { Write-Host $logEntry -ForegroundColor White }
        'Warning' { Write-Host $logEntry -ForegroundColor Yellow }
        'Error'   { Write-Host $logEntry -ForegroundColor Red }
        'Success' { Write-Host $logEntry -ForegroundColor Green }
    }
    
    # Write to log file
    $logEntry | Out-File -FilePath $Global:LogFile -Append -Encoding UTF8
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
            Write-UninstallerLog "Agent not responding via API" -Level Info
        }
        
        # Find and stop agent processes
        $agentProcesses = Get-Process | Where-Object { 
            $_.ProcessName -like "*powershell*"
        }
        
        foreach ($process in $agentProcesses) {
            try {
                $processPath = $process.MainModule.FileName
                if ($processPath -like "*SimRacingAgent*" -or $process.CommandLine -like "*SimRacingAgent*") {
                    Write-UninstallerLog "Stopping agent process PID: $($process.Id)" -Level Info
                    $process.Kill()
                }
            }
            catch {
                # Process might not have MainModule accessible
            }
        }
        
        # Clean up lock file
        $lockFile = "$env:TEMP\SimRacingAgent.lock"
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
    
    try {
        # Remove installation directory
        Remove-Item -Path $InstallPath -Recurse -Force -ErrorAction Stop
        Write-UninstallerLog "Installation files removed successfully" -Level Success
        return $true
    }
    catch {
        Write-UninstallerLog "Failed to remove installation files: $_" -Level Error
        return $false
    }
}

function Remove-DataFiles {
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
    
    try {
        # Remove data directory
        Remove-Item -Path $DataPath -Recurse -Force -ErrorAction Stop
        Write-UninstallerLog "Data files removed successfully" -Level Success
        return $true
    }
    catch {
        Write-UninstallerLog "Failed to remove data files: $_" -Level Error
        return $false
    }
}

function Remove-RegistryEntries {
    <#
    .SYNOPSIS
        Remove registry entries
    #>
    
    Write-UninstallerLog "Removing registry entries..." -Level Info
    
    try {
        # Remove main registry entry
        $registryPath = "HKLM:\SOFTWARE\SimRacingAgent"
        if (Test-Path $registryPath) {
            Remove-Item -Path $registryPath -Recurse -Force
            Write-UninstallerLog "Removed registry entry: $registryPath" -Level Info
        }
        
        # Remove uninstall entry
        $uninstallPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\SimRacingAgent"
        if (Test-Path $uninstallPath) {
            Remove-Item -Path $uninstallPath -Recurse -Force
            Write-UninstallerLog "Removed uninstall entry: $uninstallPath" -Level Info
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
    <#
    .SYNOPSIS
        Remove desktop shortcuts and start menu entries
    #>
    
    Write-UninstallerLog "Removing shortcuts..." -Level Info
    
    try {
        # Remove desktop shortcut
        $desktopShortcut = "$env:USERPROFILE\Desktop\Windows Agent.lnk"
        if (Test-Path $desktopShortcut) {
            Remove-Item -Path $desktopShortcut -Force
            Write-UninstallerLog "Removed desktop shortcut" -Level Info
        }
        
        # Remove start menu entries (if any were created)
        $startMenuPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Windows Agent.lnk"
        if (Test-Path $startMenuPath) {
            Remove-Item -Path $startMenuPath -Force
            Write-UninstallerLog "Removed start menu shortcut" -Level Info
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
    
    Write-Host "`n" -NoNewline
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " Windows Agent Uninstallation Complete " -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Removed components:" -ForegroundColor White
    Write-Host "  • Installation files" -ForegroundColor Gray
    Write-Host "  • Registry entries" -ForegroundColor Gray
    Write-Host "  • Desktop shortcuts" -ForegroundColor Gray
    
    if ($DataRemoved) {
        Write-Host "  • User data and configuration files" -ForegroundColor Gray
    } else {
        Write-Host "  • User data preserved (use -KeepData to change)" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "Log file: $Global:LogFile" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Thank you for using Windows Agent!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
}

# Main uninstallation flow
try {
    Write-Host "Windows Agent Uninstaller" -ForegroundColor Cyan
    Write-Host "Log file: $Global:LogFile" -ForegroundColor Gray
    Write-Host ""
    
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
        Write-Host "This will remove Windows Agent from your system." -ForegroundColor Yellow
        $response = Read-Host "Do you want to continue? [Y/N]"
        if ($response.ToUpper() -ne 'Y') {
            Write-UninstallerLog "Uninstallation cancelled by user" -Level Info
            exit 0
        }
        
        if (-not $KeepData) {
            Write-Host "`nThis will also remove all configuration and log files." -ForegroundColor Yellow
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
    Write-UninstallerLog "Check the log file for details: $Global:LogFile" -Level Error
    exit 1
}