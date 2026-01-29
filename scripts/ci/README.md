Artifact scanner

This folder contains helper scripts used by CI to scan produced artifacts for forbidden tokens (hostnames, usernames, secrets).

artifact_scan.ps1
- Scans an artifacts directory recursively for tokens in the `-Forbidden` list.
- New optional parameters:
  - `-ExcludeRegex` : a regex string to skip files/paths (defaults to TRX/enriched patterns).
  - `-IgnoreFile` : path to a file containing per-line regex patterns; any matching path will be skipped.

Examples

Run a full scan (default behaviour):
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\ci\artifact_scan.ps1 -ArtifactsDir .\artifacts -OutputJson .\artifacts\artifact-scan-report.json
```

Run with explicit excludes (skip TRX/trx and enriched folders):
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\ci\artifact_scan.ps1 -ArtifactsDir .\artifacts -ExcludeRegex '\\.trx$|\\\\trx\\\\|enriched-errors|\\\\enriched\\\\|e2e-enriched' -OutputJson .\artifacts\artifact-scan-report.json
```

Using an ignore file

Create `scripts/ci/.artifact-scan-ignore` with one regex per line. Example contents:
```
# skip per-run TRX directories
\\\\ci-run-\d+
# skip any path that contains a prebuilt 'thirdparty' folder
thirdparty
```

Then run:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\ci\artifact_scan.ps1 -ArtifactsDir .\artifacts -IgnoreFile .\scripts\ci\.artifact-scan-ignore -OutputJson .\artifacts\artifact-scan-report.json
```

CI example

Use the provided GitHub Actions workflow `.github/workflows/artifact-scan.yml` to run the streamed scanner in CI. The workflow runs on Windows and uploads the JSON result as an artifact named `artifact-scan-json`.

If you prefer to add the job into an existing workflow, use the PowerShell step below:

```yaml
- name: Run artifact scanner (PowerShell)
  shell: pwsh
  run: |
    pwsh -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\ci\\artifact_scan_streamed.ps1 \
      -ArtifactsDir .\\artifacts \
      -OutputJson .\\artifacts\\artifact-scan-streamed-${{ github.run_id }}.json \
      -IgnoreFile .\\scripts\\ci\\.artifact-scan-ignore \
      -MaxFileMB 50 \
      -ProgressInterval 200
```
