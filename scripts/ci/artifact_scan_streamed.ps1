param(
  [string]$ArtifactsDir = "artifacts",
  [string[]]$Forbidden = @('LITTLE_BEAST','sbatt','sbattywolf','BRNMTHF','Sbatta'),
  [string]$OutputJson = "artifact-scan-streamed.json",
  [string]$ExcludeRegex = '\\.trx$|\\\\trx\\\\|enriched-errors|\\\\enriched\\\\|e2e-enriched',
  [string]$IgnoreFile = '',
  [int]$MaxFileMB = 50,
  [int]$ProgressInterval = 100
)

# Prepare ignore patterns
$ignorePatterns = @()
if ($IgnoreFile -and (Test-Path -LiteralPath $IgnoreFile)) {
  try { $ignorePatterns = Get-Content -LiteralPath $IgnoreFile -ErrorAction Stop | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' } } catch { Write-Warning "Failed to read ignore file: $IgnoreFile" }
}

$baseName = [IO.Path]::GetFileNameWithoutExtension($OutputJson)
$outDir = Split-Path $OutputJson -Parent
if ([string]::IsNullOrWhiteSpace($outDir)) { $outDir = (Get-Location).Path }
$ts = (Get-Date).ToString('yyyyMMdd_HHmmss')
$pid = $PID
$unique = "${baseName}-$ts-p$pid"
$ndjson = Join-Path $outDir ("$unique.ndjson")
if (Test-Path $ndjson) { Remove-Item $ndjson -Force }
$progressLog = Join-Path $outDir ("$unique-progress.log")
$finalJson = Join-Path $outDir ("$unique.json")

$files = Get-ChildItem -Path $ArtifactsDir -Recurse -File -ErrorAction SilentlyContinue
$total = $files.Count
$count=0
$matchCount=0

foreach ($file in $files) {
  $count++
  $full = $file.FullName

  if ($full -match $ExcludeRegex) { continue }
  $skip = $false
  foreach ($p in $ignorePatterns) { if ($full -match $p) { $skip = $true; break } }
  if ($skip) { continue }

  # skip large files
  if ($file.Length -gt ($MaxFileMB * 1MB)) { Add-Content $progressLog "$(Get-Date) Skipping large file: $full ($([math]::Round($file.Length/1MB,1)) MB)"; continue }

  # skip likely-binary by checking for NUL in first 4KB
  try {
    $stream = [IO.File]::OpenRead($full)
    $buffer = New-Object byte[] 4096
    $read = $stream.Read($buffer,0,$buffer.Length)
    $stream.Close()
    if ($buffer[0..($read-1)] -contains 0) { Add-Content $progressLog "$(Get-Date) Skipping binary file: $full"; continue }
  } catch { continue }

  # Search for tokens using Select-String per token (avoids building large regex)
  foreach ($tok in $Forbidden) {
    try {
      $matches = Select-String -Path $full -Pattern $tok -SimpleMatch -ErrorAction SilentlyContinue
    } catch { $matches = $null }
    if ($matches) {
      foreach ($m in $matches) {
        $obj = @{ path = $m.Path; line = $m.LineNumber; token = $tok; text = $m.Line.Trim() }
        $jsonLine = ($obj | ConvertTo-Json -Depth 3)
        Add-Content -Path $ndjson -Value $jsonLine
        $matchCount++
      }
    }
  }

  if (($count % $ProgressInterval) -eq 0) {
    Add-Content $progressLog "$(Get-Date) Scanned $count/$total files; matches so far: $matchCount; last: $full"
  }
}

# Convert NDJSON to final JSON array
$found = $false
$matches = @()
if (Test-Path $ndjson) {
  $lines = Get-Content -LiteralPath $ndjson -ErrorAction SilentlyContinue
  foreach ($l in $lines) {
    try { $matches += ($l | ConvertFrom-Json) } catch { }
  }
  $found = ($matches.Count -gt 0)
}

$result = [pscustomobject]@{
  found = $found
  count = ($matches.Count)
  matches = $matches
}

$result | ConvertTo-Json -Depth 5 | Out-File -FilePath $finalJson -Encoding utf8
if ($found) { Write-Error "Forbidden tokens found: $($matches.Count)"; exit 1 } else { Write-Output "No forbidden tokens found. Output: $finalJson"; exit 0 }
