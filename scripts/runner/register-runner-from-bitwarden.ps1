<#
Registers a GitHub self-hosted runner using a PAT fetched from Bitwarden CLI (`bw`).
Prereqs:
 - Bitwarden CLI (`bw`) installed and logged in/unlocked (set $env:BW_SESSION or allow interactive unlock).
 - The PAT stored in Bitwarden as an item whose 'password' field is the PAT (item name or id provided to script).
 - PowerShell run from the runner installation folder (where `config.cmd` exists) or provide the runner folder path.

Usage example (run on the runner host):
.
  .\scripts\runner\register-runner-from-bitwarden.ps1 -Owner "sbattywolf" -Repo "USBDeviceManager" -BWItem "github-pat-for-runners" -RunnerName "SANITIZED-RUNNER" -RunnerFolder "C:\actions-runner"

Notes:
 - Registration tokens are short-lived; generate them and use immediately (this script requests a token via the GitHub API).
 - Do not store or paste secrets in public places. Keep the Bitwarden credentials and PAT protected.
#>

param(
  [Parameter(Mandatory=$true)][string]$Owner,
  [Parameter(Mandatory=$true)][string]$Repo,
  [Parameter(Mandatory=$true)][string]$BWItem,
  [Parameter(Mandatory=$true)][string]$RunnerName,
  [Parameter(Mandatory=$true)][string]$RunnerFolder
)

function Fail([string]$msg) {
  Write-Error $msg
  exit 1
}

# 1) check bw available
if (-not (Get-Command bw -ErrorAction SilentlyContinue)) {
  Fail "Bitwarden CLI 'bw' not found. Install it and login/unlock before running this script."
}

# 2) ensure bw session (try environment first)
if (-not $env:BW_SESSION) {
  Write-Output "No BW_SESSION env var found; attempting interactive unlock..."
  $unlock = bw unlock --raw 2>$null
  if ($LASTEXITCODE -ne 0 -or -not $unlock) { Fail "Failed to unlock Bitwarden CLI. Run 'bw login' and 'bw unlock' first." }
  $env:BW_SESSION = $unlock.Trim()
}

# 3) fetch PAT from Bitwarden (assumes PAT is stored as the password field)
Write-Output "Fetching PAT from Bitwarden item '$BWItem'..."
$pat = & bw get password "$BWItem" --raw 2>$null
if ($LASTEXITCODE -ne 0 -or -not $pat) { Fail "Failed to fetch password for item '$BWItem' from Bitwarden." }
$pat = $pat.Trim()
if ($pat.Length -lt 10) { Fail "Fetched PAT looks too short; aborting." }

# 4) request registration token from GitHub API
$apiUrl = "https://api.github.com/repos/$Owner/$Repo/actions/runners/registration-token"
Write-Output "Requesting registration token from GitHub API..."
$headers = @{ Authorization = "token $pat"; Accept = "application/vnd.github+json"; "User-Agent" = "runner-register-script" }
try {
  $resp = Invoke-RestMethod -Method Post -Uri $apiUrl -Headers $headers -ErrorAction Stop
} catch {
  Fail "GitHub API request failed: $($_.Exception.Message)"
}
if (-not $resp.registration_token) { Fail "No registration_token returned by GitHub API." }
$regToken = $resp.registration_token.Trim()
Write-Output "Received registration token (short-lived)."

# 5) run config.cmd in the runner folder
if (-not (Test-Path $RunnerFolder)) { Fail "Runner folder '$RunnerFolder' not found." }
Push-Location $RunnerFolder
try {
  Write-Output "Running config.cmd to register runner '$RunnerName'..."
  $p = Start-Process -FilePath ".\config.cmd" -ArgumentList "--url", "https://github.com/$Owner/$Repo", "--token", $regToken, "--name", $RunnerName, "--unattended" -NoNewWindow -Wait -PassThru
  if ($p.ExitCode -ne 0) { Fail "config.cmd exited with code $($p.ExitCode)." }
  Write-Output "Runner configured successfully."
} finally {
  Pop-Location
}

Write-Output "Done. If you want the runner to run as a service, run the service helper from the runner folder (in Git Bash): ./svc.sh install && ./svc.sh start"
