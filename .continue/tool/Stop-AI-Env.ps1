param(
    [switch]$DryRun
)

Write-Host "Chiusura in corso..." -ForegroundColor Yellow

if ($DryRun) { Write-Host 'Dry-run: would stop ollama models and terminate ollama process.' -ForegroundColor Yellow; return }

# Ferma tutti i modelli in VRAM
try { ollama stop --all } catch { }

param(
	[switch]$DryRun
)

Write-Host "Chiusura in corso..." -ForegroundColor Yellow

if ($DryRun) {
	Write-Host 'Dry-run: would stop ollama models and terminate ollama process.' -ForegroundColor Yellow
	return
}

# Ferma tutti i modelli in VRAM (se disponibile)
try {
	if (Get-Command -Name ollama -ErrorAction SilentlyContinue) {
		ollama stop --all 2>$null
	} else {
		Write-Host 'ollama not found; skipping model stop.' -ForegroundColor DarkYellow
	}
} catch {
	Write-Host "Warning: failed to stop models: $($_.ToString())" -ForegroundColor DarkYellow
}

# Chiude Ollama se in esecuzione
try {
	$proc = Get-Process -Name 'ollama' -ErrorAction SilentlyContinue
	if ($proc) {
		Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
		Write-Host 'Stopped ollama process.' -ForegroundColor Green
	} else {
		Write-Host 'ollama process not running.' -ForegroundColor DarkYellow
	}
} catch {
	Write-Host "Warning: failed to stop ollama: $($_.ToString())" -ForegroundColor DarkYellow
}

# Clean PID/marker using script location (reliable when invoked from tasks)
$toolDir = Join-Path -Path $PSScriptRoot -ChildPath '.continue\tool'
if (-not (Test-Path $toolDir)) {
	# Fallback to repository-relative path
	$toolDir = Join-Path -Path (Get-Location) -ChildPath '.continue\tool'
}

$pidFile = Join-Path $toolDir 'ai_env.pid'
if (Test-Path $pidFile) {
	try { Remove-Item -Path $pidFile -ErrorAction SilentlyContinue }
	catch { Write-Host "Warning: could not remove PID file: $($_.Exception.Message)" -ForegroundColor DarkYellow }
} else {
	Write-Host 'PID file not found; nothing to remove.' -ForegroundColor DarkYellow
}

try {
	$markerFile = Join-Path $toolDir 'ai_env.marker'
	"$((Get-Date).ToString('o')) STOPPED" | Out-File -FilePath $markerFile -Encoding UTF8 -Append
} catch {
	Write-Host "Warning: could not write marker file: $($_.Exception.Message)" -ForegroundColor DarkYellow
}

Write-Host "GPU Liberata. Sessione terminata." -ForegroundColor Green
