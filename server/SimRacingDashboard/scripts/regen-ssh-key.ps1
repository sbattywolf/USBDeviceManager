Param(
    [string]$Email = "<USER_EMAIL>",
    [string]$KeyPath = "$env:USERPROFILE\.ssh\id_ed25519"
)

Write-Host "This script will overwrite the existing SSH key at: $KeyPath"
Write-Host "You will be prompted to enter a passphrase interactively."
Write-Host "If you do NOT want to overwrite, press Ctrl+C to cancel now.";
Write-Host ""

if (Test-Path $KeyPath) {
    Write-Host "Existing key found at $KeyPath. Backing up to ${KeyPath}.bak-$(Get-Date -Format yyyyMMddHHmmss)"
    Copy-Item -Path $KeyPath -Destination "${KeyPath}.bak-$(Get-Date -Format yyyyMMddHHmmss)" -Force
    Copy-Item -Path (${KeyPath} + '.pub') -Destination "${KeyPath}.pub.bak-$(Get-Date -Format yyyyMMddHHmmss)" -Force
}

Write-Host "Running ssh-keygen; follow prompts to enter a passphrase.";
ssh-keygen -t ed25519 -C $Email -f $KeyPath

Write-Host ""
Write-Host "New public key (copy to GitHub -> Settings -> SSH and GPG keys -> New SSH key):"
Get-Content ($KeyPath + '.pub')

Write-Host ""
Write-Host "Done. Backups kept alongside original files with .bak-<timestamp>."
