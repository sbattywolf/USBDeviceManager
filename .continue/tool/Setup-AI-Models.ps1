param(
	[switch]$Yes,
	[switch]$DryRun
)

Write-Host "Scaricamento modelli ottimizzati per RTX 3090..." -ForegroundColor Cyan

# Check free disk space on repo drive
$root = (Get-Location).Path
$driveRoot = [System.IO.Path]::GetPathRoot($root).TrimEnd('\')
try {
	$drive = Get-PSDrive -Name $driveRoot -ErrorAction SilentlyContinue
	$freeBytes = $drive.Free
} catch {
	$freeBytes = 0
}
$minBytes = 20GB
if ($freeBytes -and ($freeBytes -lt $minBytes) -and -not $Yes) {
	Write-Host "Warning: free disk space on drive $driveRoot is low ($([math]::Round($freeBytes/1GB,1)) GB)." -ForegroundColor Yellow
	$response = Read-Host "Proceed with model download? (y/N)"
	if ($response -notin @('y','Y')) { Write-Host 'Aborted by user.' -ForegroundColor Yellow; return }
}

if ($DryRun) {
	Write-Host "Dry-run: would run ollama pull qwen2.5-coder:32b, deepseek-r1:14b, qwen2.5-coder:1.5b" -ForegroundColor Yellow
	return
}

ollama pull qwen2.5-coder:32b  # Modello di punta per precisione
ollama pull deepseek-r1:14b    # Modello Coach/Ragionamento
ollama pull qwen2.5-coder:1.5b # Modello ultra-veloce per Autocomplete
Write-Host "Modelli pronti." -ForegroundColor Green
