**Git Credential Manager (GCM) — install & verify**

Why
- If you see "git: 'credential-manager-core' is not a git command" when pushing, your Git configuration references a credential helper that's not installed. Installing Git Credential Manager (GCM) restores smooth authentication for HTTPS pushes.

Install (Windows)
1. Download and run the installer: https://aka.ms/gcm/latest
2. Alternatively install via Winget:
```powershell
winget install --id Git.GitCredentialManager -e --source winget
```

Install (macOS / Linux)
- Follow the platform instructions: https://github.com/GitCredentialManager/git-credential-manager

Configure
```powershell
# set as default helper
git config --global credential.helper manager-core

# verify
git config --list | Select-String credential.helper
```

Verify authentication
```powershell
# run a dry push (no changes) to ensure credential flow works
git remote -v
git fetch origin
# or try a small push on a test branch
```

If you cannot install GCM
- Use a personal access token (PAT) and the `git` credential cache or set credentials per-remote:
```powershell
git remote set-url origin https://<USERNAME>:<PAT>@github.com/<owner>/<repo>.git
```

Notes
- Prefer not to hardcode PATs in repos or scripts. Use OS credential helpers or environment-based tokens in CI.
