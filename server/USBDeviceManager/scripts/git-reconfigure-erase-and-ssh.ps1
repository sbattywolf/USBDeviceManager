Param(
    [string]$RepoPath = "<REPO_PATH>",
    [string]$Name = "<USER_NAME>",
    [string]$Email = "<USER_EMAIL>"
)

Write-Host "RepoPath: $RepoPath"
Write-Host "Using name: $Name  email: $Email"
Write-Host ""

Write-Host "1) Attempting to erase GitHub credentials via Git Credential Manager (if present)..."
$data = "protocol=https`nhost=github.com`n"

if (Get-Command git-credential-manager-core -ErrorAction SilentlyContinue) {
    $data | git-credential-manager-core erase
    Write-Host "Ran git-credential-manager-core erase"
}
elseif (Get-Command git-credential-manager -ErrorAction SilentlyContinue) {
    $data | git-credential-manager erase
    Write-Host "Ran git-credential-manager erase"
}
elseif (Get-Command git -ErrorAction SilentlyContinue) {
    try {
        $data | git credential-manager-core erase
        Write-Host "Ran 'git credential-manager-core erase'"
    }
    catch {
        try {
            $data | git credential-manager erase
            Write-Host "Ran 'git credential-manager erase'"
        }
        catch {
            Write-Host "No credential manager found or erase failed."
        }
    }
}
else {
    Write-Host "No git binary found in PATH."
}

Write-Host ""
Write-Host "2) Applying global git config: user.name, user.email, credential.helper manager-core"
git config --global user.name "$Name"
git config --global user.email "$Email"
git config --global credential.helper manager-core
Write-Host "Global git config set:" 
git config --global --list | Select-String 'user.name|user.email|credential.helper' | ForEach-Object { Write-Host $_ }

Write-Host ""
Write-Host "3) Ensure .ssh directory exists and generate or show public key"
$sshDir = Join-Path $env:USERPROFILE '.ssh'
if (-not (Test-Path $sshDir)) { New-Item -ItemType Directory -Path $sshDir | Out-Null; Write-Host "Created $sshDir" }
$keyPath = Join-Path $sshDir 'id_ed25519'
if (Test-Path $keyPath) {
    Write-Host "SSH key exists at $keyPath - not overwriting."
}
else {
    Write-Host "Generating new ed25519 SSH key at $keyPath (no passphrase)..."
    ssh-keygen -t ed25519 -C $Email -f $keyPath -N '' -q
}
Write-Host ""
Write-Host "Public key (copy this to GitHub -> Settings -> SSH and GPG keys -> New SSH key):"
Get-Content ($keyPath + '.pub')

Write-Host ""
Write-Host "Done. If you want me to overwrite existing keys or use a passphrase, tell me."
