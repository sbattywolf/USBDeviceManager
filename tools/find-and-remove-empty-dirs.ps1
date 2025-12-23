param(
    [string]$Root = ".",
    [string[]]$Exclude = @('.git','bin','obj','artifacts','node_modules')
)

$rootPath = Resolve-Path $Root
Write-Host "Scanning for empty directories under $rootPath"
$dirs = Get-ChildItem -Path $rootPath -Directory -Recurse -Force | Sort-Object FullName -Descending
$empty = @()
foreach ($d in $dirs) {
    $skip = $false
    foreach ($ex in $Exclude) {
        if ($d.FullName -like "*\\$ex*") { $skip = $true; break }
    }
    if ($skip) { continue }
    $items = Get-ChildItem -Path $d.FullName -Force
    if ($items.Count -eq 0) { $empty += $d.FullName }
}

if ($empty.Count -eq 0) {
    Write-Host "No empty directories found."
    exit 0
}

Write-Host "Empty directories found:`n"
$empty | ForEach-Object { Write-Host " - $_" }

Write-Host "Removing empty directories..."
foreach ($p in $empty) {
    try {
        Remove-Item -Path $p -Force -Recurse
        Write-Host "Deleted: $p"
    } catch {
        Write-Host "Failed to delete: $p - $_"
    }
}

Write-Host "Done."
