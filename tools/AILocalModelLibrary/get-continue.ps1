<#
Bootstrap stub: copy or clone the repo-local `.continue` tooling into another repository.
This is a minimal placeholder — adapt before publishing.
#>
param(
    [string]$TargetPath = '.'
)

Write-Output "Bootstrapping .continue to $TargetPath"
if (-Not (Test-Path -Path "$TargetPath\.continue")) {
    New-Item -ItemType Directory -Path "$TargetPath\.continue" | Out-Null
}

# Copy current pack files (this stub copies the local tools folder)
$source = Join-Path $PSScriptRoot '..\.continue\tool'
$dest = Join-Path $TargetPath '.continue\tool'
if (Test-Path $source) {
    Copy-Item -Path $source -Destination $dest -Recurse -Force
    Write-Output "Copied .continue\tool to $dest"
} else {
    Write-Warning "Local .continue\tool not found in repo."
}

Write-Output "Bootstrap complete. Review files and commit changes in the target repository."