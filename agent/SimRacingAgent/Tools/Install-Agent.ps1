#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Windows Agent Installer
.DESCRIPTION
    Interactive installer for Windows Agent with validation and configuration
.NOTES
    Version: 1.0.0
    Requires: PowerShell 5.1 or higher, Administrator privileges
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$InstallPath = "$env:ProgramFiles\SimRacingAgent",
    
    [Parameter(Mandatory=$false)]
    [switch]$Silent = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$Upgrade = $false
)

# Set strict mode
Set-StrictMode -Version Latest

# Global variables
$Global:InstallerVersion = "1.0.0"
$Global:AgentSourcePath = Split-Path -Parent $PSScriptRoot
$Global:LogFile = "$env:TEMP\SimRacingAgent_Install_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-InstallerLog {
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

function Test-Prerequisites {
    <#
    .SYNOPSIS
        Check installation prerequisites
    #>
    
    Write-InstallerLog "Checking prerequisites..." -Level Info
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-InstallerLog "PowerShell 5.1 or higher is required. Current version: $($PSVersionTable.PSVersion)" -Level Error
        return $false
    }
    
    # Check administrator privileges
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$currentUser
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-InstallerLog "Administrator privileges are required for installation" -Level Error
        return $false
    }
    
    # Check Windows version (Windows 10/11)
    $windowsVersion = [System.Environment]::OSVersion.Version
    if ($windowsVersion.Major -lt 10) {
        Write-InstallerLog "Windows 10 or higher is required. Current version: $($windowsVersion)" -Level Warning
    }
    
    # Check available disk space (minimum 100MB)
    $installDrive = Split-Path -Qualifier $InstallPath
    $driveInfo = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DeviceID -eq $installDrive }
    $freeSpaceMB = [math]::Round($driveInfo.FreeSpace / 1MB, 2)
    
    if ($freeSpaceMB -lt 100) {
        Write-InstallerLog "Insufficient disk space. Required: 100MB, Available: ${freeSpaceMB}MB" -Level Error
        return $false
    }
    
    Write-InstallerLog "Prerequisites check passed" -Level Success
    return $true
}

function Test-ExistingInstallation {
    <#
    .SYNOPSIS
        Check for existing installation
    #>
    
    Write-InstallerLog "Checking for existing installation..." -Level Info
    
    $existingInstallation = @{
        Found = $false
        Version = ""
        Path = ""
        Running = $false
    }
    
    # Check install directory
    if (Test-Path $InstallPath) {
        $existingInstallation.Found = $true
        $existingInstallation.Path = $InstallPath
        
        # Check version
        $versionFile = Join-Path -Path $InstallPath -ChildPath "version.txt"
        if (Test-Path $versionFile) {
            $existingInstallation.Version = Get-Content $versionFile -Raw
        }
        
        # Check if agent is running
        $lockFile = "$env:TEMP\SimRacingAgent.lock"
        if (Test-Path $lockFile) {
            try {
                $lockContent = Get-Content $lockFile | ConvertFrom-Json
                $process = Get-Process -Id $lockContent.PID -ErrorAction SilentlyContinue
                if ($process) {
                    $existingInstallation.Running = $true
                }
            }
            catch {
                # Stale lock file
                Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
            }
        }
    }
    
    # Check registry
    $registryPath = "HKLM:\SOFTWARE\SimRacingAgent"
    if (Test-Path $registryPath) {
        $regInfo = Get-ItemProperty -Path $registryPath
        if ($regInfo.InstallPath -and (Test-Path $regInfo.InstallPath)) {
            $existingInstallation.Found = $true
            if (-not $existingInstallation.Path) {
                $existingInstallation.Path = $regInfo.InstallPath
            }
            if (-not $existingInstallation.Version) {
                $existingInstallation.Version = $regInfo.Version
            }
        }
    }
    
    return $existingInstallation
}

function Stop-ExistingAgent {
    <#
    .SYNOPSIS
        Stop existing agent instance
    #>
    
    Write-InstallerLog "Stopping existing Windows Agent..." -Level Info
    
    try {
        # Try to stop gracefully via API
        try {
            $response = Invoke-RestMethod -Uri "http://localhost:8080/status" -Method GET -TimeoutSec 5
            if ($response) {
                Write-InstallerLog "Sending shutdown signal to agent..." -Level Info
                # Note: We don't have a shutdown endpoint yet, so we'll kill the process
            }
        }
        catch {
            # Agent not responding via API
        }
        
        # Find and stop agent processes
        $agentProcesses = Get-Process | Where-Object { 
            $_.ProcessName -like "*powershell*" -and 
            $_.MainModule.FileName -like "*SimRacingAgent*" 
        }
        
        foreach ($process in $agentProcesses) {
            Write-InstallerLog "Stopping agent process PID: $($process.Id)" -Level Info
            $process.Kill()
        }
        
        # Clean up lock file
        $lockFile = "$env:TEMP\SimRacingAgent.lock"
        if (Test-Path $lockFile) {
            Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
        }
        
        # Wait a moment for cleanup
        Start-Sleep -Seconds 2
        
        Write-InstallerLog "Existing agent stopped" -Level Success
        return $true
    }
    catch {
        Write-InstallerLog "Failed to stop existing agent: $_" -Level Warning
        return $false
    }
}

function Install-Agent {
    <#
    .SYNOPSIS
        Install Windows Agent files
    #>
    
    Write-InstallerLog "Installing Windows Agent to: $InstallPath" -Level Info
    
    try {
        # Create installation directory
        if (-not (Test-Path $InstallPath)) {
            New-Item -Path $InstallPath -ItemType Directory -Force | Out-Null
        }
        
        # Copy agent files
        $sourceFiles = @(
            "SimRacingAgent.ps1",
            "src"
        )
        
        foreach ($file in $sourceFiles) {
            $sourcePath = Join-Path -Path $Global:AgentSourcePath -ChildPath $file
            $destPath = Join-Path -Path $InstallPath -ChildPath $file
            
            if (Test-Path $sourcePath) {
                if (Test-Path $destPath) {
                    Remove-Item $destPath -Recurse -Force
                }
                Copy-Item -Path $sourcePath -Destination $destPath -Recurse -Force
                Write-InstallerLog "Copied: $file" -Level Info
            } else {
                Write-InstallerLog "Source file not found: $sourcePath" -Level Warning
            }
        }
        
        # Create version file
        $Global:InstallerVersion | Out-File -FilePath (Join-Path -Path $InstallPath -ChildPath "version.txt") -Encoding UTF8
        
        # Create data directory
        $dataPath = "$env:LOCALAPPDATA\SimRacingAgent"
        if (-not (Test-Path $dataPath)) {
            New-Item -Path $dataPath -ItemType Directory -Force | Out-Null
        }
        
        Write-InstallerLog "Agent files installed successfully" -Level Success
        return $true
    }
    catch {
        Write-InstallerLog "Failed to install agent files: $_" -Level Error
        return $false
    }
}

function Register-Agent {
    <#
    .SYNOPSIS
        Register agent in Windows registry
    #>
    
    Write-InstallerLog "Registering Windows Agent..." -Level Info
    
    try {
        # Create registry entries
        $registryPath = "HKLM:\SOFTWARE\SimRacingAgent"
        
        if (-not (Test-Path $registryPath)) {
            New-Item -Path $registryPath -Force | Out-Null
        }
        
        Set-ItemProperty -Path $registryPath -Name "InstallPath" -Value $InstallPath
        Set-ItemProperty -Path $registryPath -Name "Version" -Value $Global:InstallerVersion
        Set-ItemProperty -Path $registryPath -Name "InstallDate" -Value (Get-Date).ToString()
        Set-ItemProperty -Path $registryPath -Name "DataPath" -Value "$env:LOCALAPPDATA\SimRacingAgent"
        
        # Add to Windows Programs list
        $uninstallPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\SimRacingAgent"
        
        if (-not (Test-Path $uninstallPath)) {
            New-Item -Path $uninstallPath -Force | Out-Null
        }
        
        Set-ItemProperty -Path $uninstallPath -Name "DisplayName" -Value "SimRacing Agent"
        Set-ItemProperty -Path $uninstallPath -Name "DisplayVersion" -Value $Global:InstallerVersion
        Set-ItemProperty -Path $uninstallPath -Name "Publisher" -Value "SimRacing Agent"
        Set-ItemProperty -Path $uninstallPath -Name "InstallLocation" -Value $InstallPath
        Set-ItemProperty -Path $uninstallPath -Name "UninstallString" -Value "PowerShell.exe -ExecutionPolicy Bypass -File `"$InstallPath\installer\Uninstall-Agent.ps1`""
        Set-ItemProperty -Path $uninstallPath -Name "NoModify" -Value 1
        Set-ItemProperty -Path $uninstallPath -Name "NoRepair" -Value 1
        
        Write-InstallerLog "Agent registered successfully" -Level Success
        return $true
    }
    catch {
        Write-InstallerLog "Failed to register agent: $_" -Level Error
        return $false
    }
}

function Install-StartupScript {
    <#
    .SYNOPSIS
        Create startup scripts and shortcuts
    #>
    
    Write-InstallerLog "Creating startup scripts..." -Level Info
    
    try {
        # Create start script
        $startScriptPath = Join-Path -Path $InstallPath -ChildPath "Start-SimRacingAgent.ps1"
        $startScript = @"
#Requires -Version 5.1
# SimRacing Agent Start Script
Set-Location "$InstallPath"
.\SimRacingAgent.ps1 -Mode Terminal
"@
        $startScript | Out-File -FilePath $startScriptPath -Encoding UTF8
        
        # Create desktop shortcut
        if (-not $Silent) {
            $shell = New-Object -ComObject WScript.Shell
            $shortcut = $shell.CreateShortcut("$env:USERPROFILE\Desktop\Windows Agent.lnk")
            $shortcut.TargetPath = "PowerShell.exe"
            $shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$startScriptPath`""
            $shortcut.WorkingDirectory = $InstallPath
            $shortcut.Description = "Windows Agent - USB Monitor and Process Manager"
            $shortcut.Save()
            
            Write-InstallerLog "Desktop shortcut created" -Level Info
        }
        
        Write-InstallerLog "Startup scripts created" -Level Success
        return $true
    }
    catch {
        Write-InstallerLog "Failed to create startup scripts: $_" -Level Error
        return $false
    }
}

function Show-InstallationSummary {
    <#
    .SYNOPSIS
        Show installation summary
    #>
    
    Write-Host "`n" -NoNewline
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  SimRacing Agent Installation Complete  " -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Installation Details:" -ForegroundColor White
    Write-Host "  Version: $Global:InstallerVersion" -ForegroundColor Gray
    Write-Host "  Location: $InstallPath" -ForegroundColor Gray
    Write-Host "  Data: $env:LOCALAPPDATA\SimRacingAgent" -ForegroundColor Gray
    Write-Host "  Log: $Global:LogFile" -ForegroundColor Gray
    Write-Host ""
    Write-Host "To start the agent:" -ForegroundColor White
    Write-Host "  1. Double-click the 'SimRacing Agent' desktop shortcut" -ForegroundColor Gray
    Write-Host "  2. Or run: PowerShell -ExecutionPolicy Bypass -File `\"$InstallPath\SimRacingAgent.ps1`\"" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Features:" -ForegroundColor White
    Write-Host "  • USB device monitoring and control" -ForegroundColor Gray
    Write-Host "  • Process management and monitoring" -ForegroundColor Gray
    Write-Host "  • REST API on http://localhost:8080" -ForegroundColor Gray
    Write-Host "  • Configuration management" -ForegroundColor Gray
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
}

# Main installation flow
try {
    Write-Host "Windows Agent Installer v$Global:InstallerVersion" -ForegroundColor Cyan
    Write-Host "Log file: $Global:LogFile" -ForegroundColor Gray
    Write-Host ""
    
    # Check prerequisites
    if (-not (Test-Prerequisites)) {
        Write-InstallerLog "Prerequisites check failed. Installation aborted." -Level Error
        exit 1
    }
    
    # Check for existing installation
    $existingInstall = Test-ExistingInstallation
    
    if ($existingInstall.Found) {
        Write-InstallerLog "Existing installation found at: $($existingInstall.Path)" -Level Info
        Write-InstallerLog "Installed version: $($existingInstall.Version)" -Level Info
        
        if (-not $Silent -and -not $Upgrade) {
            $response = Read-Host "Do you want to upgrade the existing installation? [Y/N]"
            if ($response.ToUpper() -ne 'Y') {
                Write-InstallerLog "Installation cancelled by user" -Level Info
                exit 0
            }
        }
        
        # Stop existing agent
        if ($existingInstall.Running) {
            Stop-ExistingAgent
        }
    }
    
    # Install agent
    if (-not (Install-Agent)) {
        Write-InstallerLog "Agent installation failed" -Level Error
        exit 1
    }
    
    # Register agent
    if (-not (Register-Agent)) {
        Write-InstallerLog "Agent registration failed" -Level Error
        exit 1
    }
    
    # Create startup scripts
    if (-not (Install-StartupScript)) {
        Write-InstallerLog "Startup script creation failed" -Level Error
        exit 1
    }
    
    # Show summary
    Show-InstallationSummary
    
    if (-not $Silent) {
        $response = Read-Host "`nWould you like to start the agent now? [Y/N]"
        if ($response.ToUpper() -eq 'Y') {
            Write-Host "Starting SimRacing Agent..." -ForegroundColor Green
            Start-Process -FilePath "PowerShell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `\"$InstallPath\SimRacingAgent.ps1`\"" -WorkingDirectory $InstallPath
        }
    }
    
    Write-InstallerLog "Installation completed successfully" -Level Success
    exit 0
}
catch {
    Write-InstallerLog "Installation failed with error: $_" -Level Error
    Write-InstallerLog "Check the log file for details: $Global:LogFile" -Level Error
    exit 1
}