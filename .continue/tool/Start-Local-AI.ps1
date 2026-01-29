param(
    [switch]$DryRun,
    [int]$MonitorSeconds = 0
)

Write-Host "Avvio Ambiente AI Locale..." -ForegroundColor Magenta

if ($DryRun) { Write-Host 'Dry-run: would start Ollama, VS Code and GPU monitor.' -ForegroundColor Yellow; return }

# Avvia Ollama se non è già in esecuzione
if (!(Get-Process "ollama" -ErrorAction SilentlyContinue)) {
    Start-Process -FilePath "ollama" -ArgumentList "app"
    Start-Sleep -Seconds 2
}

# Avvia VS Code
Start-Process -FilePath "code"

# record PID/marker
$toolDir = Join-Path -Path (Get-Location) -ChildPath '.continue\tool'
try { Set-Content -Path (Join-Path $toolDir 'ai_env.pid') -Value $PID -Encoding ASCII -Force } catch { }
try { "$((Get-Date).ToString('o')) STARTED Local" | Out-File -FilePath (Join-Path $toolDir 'ai_env.marker') -Encoding UTF8 -Append } catch { }

# Avvia monitoraggio GPU in una nuova finestra
if ($MonitorSeconds -gt 0) {
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "Write-Host 'Monitoraggio RTX 3090 (Ctrl+C per chiudere)' -ForegroundColor Yellow; nvidia-smi -l 5; Start-Sleep -Seconds $MonitorSeconds"
} else {
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "Write-Host 'Monitoraggio RTX 3090 (Ctrl+C per chiudere)' -ForegroundColor Yellow; nvidia-smi -l 5"
}

Write-Host "Ambiente pronto. Buon coding e buon apprendimento!" -ForegroundColor Green
