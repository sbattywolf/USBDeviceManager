# Create venv in gui/.venv, install requirements, start server+agent, and launch GUI (uses Start-Process to open windows)
Set-StrictMode -Version Latest

# Create venv if missing
if (-not (Test-Path 'gui\.venv')) {
    Write-Output 'Creating virtual environment gui\.venv'
    python -m venv gui\.venv
} else {
    Write-Output 'Virtual environment already exists: gui\.venv'
}

# Activate venv for this session and install requirements
$venv_python = Join-Path (Resolve-Path 'gui\.venv').Path 'Scripts\python.exe'
$venv_pip = Join-Path (Resolve-Path 'gui\.venv').Path 'Scripts\pip.exe'
if (Test-Path $venv_pip) {
    Write-Output 'Installing requirements via venv pip'
    & $venv_pip install -r gui\requirements.txt
} else {
    Write-Output 'Warning: venv pip not found; attempting global pip install'
    pip install -r gui\requirements.txt
}

# Start server in new window
Write-Output 'Starting server in new window...'
Start-Process -FilePath 'dotnet' -ArgumentList @('run','--project','server/USBDeviceManager','--urls','http://localhost:5000') -WindowStyle Normal
Start-Sleep -Seconds 2

# Start agent in new window
Write-Output 'Starting agent in new window...'
Start-Process -FilePath 'powershell' -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','agent/SimRacingAgent/SimRacingAgent.ps1' -WindowStyle Normal
Start-Sleep -Seconds 1

# Launch GUI using venv python in new window
if (Test-Path $venv_python) {
    Write-Output 'Launching GUI (venv python) in new window...'
    Start-Process -FilePath $venv_python -ArgumentList 'gui/main.py','--api','http://localhost:5000' -WindowStyle Normal
} else {
    Write-Output 'Launching GUI (global python) in new window...'
    Start-Process -FilePath 'python' -ArgumentList 'gui/main.py','--api','http://localhost:5000' -WindowStyle Normal
}

Write-Output 'GUI setup and launch script complete.'
