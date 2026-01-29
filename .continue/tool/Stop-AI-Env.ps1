param(
    [switch]$DryRun
)

Write-Host "Chiusura in corso..." -ForegroundColor Yellow

if ($DryRun) { Write-Host 'Dry-run: would stop ollama models and terminate ollama process.' -ForegroundColor Yellow; return }

# Ferma tutti i modelli in VRAM
try { ollama stop --all } catch { }

# Chiude Ollama
try { Stop-Process -Name "ollama" -Force -ErrorAction SilentlyContinue } catch { }

# Clean PID/marker
$toolDir = Join-Path -Path (Get-Location) -ChildPath '.continue\tool'
try { Remove-Item -Path (Join-Path $toolDir 'ai_env.pid') -ErrorAction SilentlyContinue } catch { }
try { "$((Get-Date).ToString('o')) STOPPED" | Out-File -FilePath (Join-Path $toolDir 'ai_env.marker') -Encoding UTF8 -Append } catch { }

Write-Host "GPU Liberata. Sessione terminata." -ForegroundColor Green
param(
	[switch]$DryRun
)

Write-Host "Chiusura in corso..." -ForegroundColor Yellow

if ($DryRun) { Write-Host 'Dry-run: would stop ollama models and terminate ollama process.' -ForegroundColor Yellow; return }

# Ferma tutti i modelli in VRAM
try { ollama stop --all } catch { }

# Chiude Ollama
try { Stop-Process -Name "ollama" -Force -ErrorAction SilentlyContinue } catch { }

# Clean PID/marker
$toolDir = Join-Path -Path (Get-Location) -ChildPath '.continue\tool'
try { Remove-Item -Path (Join-Path $toolDir 'ai_env.pid') -ErrorAction SilentlyContinue } catch { }
try { "$((Get-Date).ToString('o')) STOPPED" | Out-File -FilePath (Join-Path $toolDir 'ai_env.marker') -Encoding UTF8 -Append } catch { }

Write-Host "GPU Liberata. Sessione terminata." -ForegroundColor Green
