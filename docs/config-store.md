**Config store** — `.continue/config.json`

Purpose
- Provide a repository-local JSON store for CI/interactive defaults and developer preferences.

Location
- File: `.continue/config.json`

Why
- Keep machine-independent defaults checked-in as examples.
- Allow developers to keep local overrides in their own copy (git-ignored) while sharing recommended defaults in the repo.

Example
- Example config file is `.continue/config.example.json` (copy it to `.continue/config.json` and edit as needed).

Keys (suggested)
- `processMenu`: object
  - `autoAdvanceDefault`: boolean
  - `inputTimeoutSeconds`: integer
  - `defaultAction`: integer
- `ci`: object
  - `markerPath`: string
  - `enableMock`: boolean

Install / Use
1. Copy the example config to the active config path:

```powershell
New-Item -ItemType Directory -Path .continue -Force
Copy-Item .continue/config.example.json .continue/config.json -Force
# Edit .continue/config.json to your liking
notepad .continue\config.json
```

2. `process-menu.ps1` will prefer `.continue/config.json` when present. To run with repo defaults, ensure `.continue/config.json` exists.

Overriding per-machine
- Keep `.continue/config.json` out of source control by adding `.continue/config.json` to `.gitignore` if you want machine-specific overrides.

CI
- CI runners can read `.continue/config.json` to derive default flags for mock-mode or timeouts.

Support
- If you want me to add code to `scripts/process-menu.ps1` to read `.continue/config.json` automatically, say so and I'll implement it.
