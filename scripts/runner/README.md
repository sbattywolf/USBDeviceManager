# Runner re-registration helper

This document explains how to use `register-runner-from-bitwarden.ps1` to fetch a GitHub PAT from Bitwarden and register a self-hosted Windows runner.

Prerequisites
- Bitwarden CLI installed and unlocked on the runner host (`bw` available on PATH).
- A Bitwarden item containing a GitHub PAT and an `notes`/field with the name of the repo/org.
- PowerShell (Windows) and network access to `api.github.com`.

Usage (example)
1. Unlock Bitwarden (interactive or using environment):
```
bw login --raw > bw_token.txt
export BW_SESSION=$(cat bw_token.txt)
```
2. Run the helper script (from the repository root):
```
pwsh .\scripts\runner\register-runner-from-bitwarden.ps1 -BitwardenItemId <item-id> -RepositoryOwner <owner> -RepositoryName <repo>
```

Notes
- The script requests a short-lived registration token from GitHub using the PAT it retrieves and then runs `config.cmd` in the self-hosted runner folder. Review the script before running on production hosts.
- After registration, rename the runner in the GitHub UI or the script can be extended to call the API to update the runner name.
