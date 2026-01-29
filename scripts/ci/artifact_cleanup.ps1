param(
  [string]$ArtifactsDir = "artifacts",
  [int]$Days = 30,
  [switch]$DryRun,
  [string]$Pattern = 'ci-run-*'
)

$cutoff = (Get-Date).AddDays(-$Days)
$candidates = Get-ChildItem -Path $ArtifactsDir -Directory -Filter $Pattern -ErrorAction SilentlyContinue | Where-Object { $_.CreationTime -lt $cutoff }

if ($candidates.Count -eq 0) { Write-Output "No candidate artifact runs older than $Days days."; exit 0 }

Write-Output "Found $($candidates.Count) candidate folders older than $Days days (cutoff: $cutoff):"
$candidates | ForEach-Object {
  $size = (Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
  $sizeMB = if ($size) { [math]::Round($size/1MB,2) } else { 0 }
  Write-Output "- $($_.FullName) | Created: $($_.CreationTime) | Size: ${sizeMB}MB"
}

if ($DryRun) { Write-Output "Dry-run mode; nothing deleted. Rerun with -DryRun:$false to actually remove these folders."; exit 0 }

# Confirm deletion
Write-Output "Deleting candidate folders..."
foreach ($f in $candidates) {
  try { Remove-Item -LiteralPath $f.FullName -Recurse -Force -ErrorAction Stop; Write-Output "Deleted: $($f.FullName)" } catch { Write-Warning "Failed to delete: $($f.FullName) - $_" }
}

Write-Output "Cleanup complete."
