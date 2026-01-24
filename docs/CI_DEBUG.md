**CI Debug: Downloading Actions Artifacts**

- **Purpose**: quick reference for fetching GitHub Actions run artifacts to investigate CI failures locally.

- **Primary tool**: `scripts/download_artifacts.py` — a Python helper that uses `gh` if available or the GitHub REST API with `GITHUB_TOKEN`.

- **Quick examples**:

  - Using `gh` (preferred if authenticated):

    gh run download 21315105846 --dir artifacts/ci-run-21315105846

  - Using the Python helper (requires Python 3):

    python scripts/download_artifacts.py --run-id 21315105846 --out artifacts/ci-run-21315105846

    # set GITHUB_TOKEN if repo is private or rate-limited
    setx GITHUB_TOKEN "<your_token>";

  - Run multiple downloads (PowerShell wrapper):

    .\scripts\ci_debug_loop.ps1 -RunIds 21315105846,21315105847 -OutDir artifacts/ci-runs

- **Notes**:
  - If `gh` is present the Python helper will call it and preserve original artifact folder layout.
  - Without `gh` the script will use the REST API and requires `GITHUB_TOKEN` for private repos.
  - Downloaded artifacts are unzipped under the output directory.

Pipeline helper
----------------

We also provide a small pipeline wrapper that downloads artifacts for a run
and produces a compact `ci-analysis.json` with matches for common failure
keywords.

  PowerShell:

    .\scripts\ci_debug_pipeline.ps1 -RunId 21315105846

  This will create `artifacts/ci-runs/ci-run-21315105846/ci-analysis.json`.

Using Ollama (local LLM)
------------------------

If you run Ollama locally and want an LLM to help triage the downloaded
artifacts without ever sending secrets out of your machine, you can:

  1. Run the pipeline locally (it uses your `gh` auth or `GITHUB_TOKEN` only
     on your machine):

     ```powershell
     .\scripts\ci_debug_pipeline.ps1 -RunId 21315105846
     ```

  2. Start an Ollama session and ask it to inspect `ci-analysis.json` or the
     files under `artifacts/ci-runs/ci-run-21315105846/`.

     Example CLI usage (assuming `ollama` is configured):

     ```powershell
     # feed JSON to the model interactively (example)
     type .\artifacts\ci-runs\ci-run-21315105846\ci-analysis.json | ollama run llama2 --verbose
     ```

  3. Ask Ollama to propose concrete code changes or tests to reproduce the
     issue locally. You can then apply changes here in the repo and run CI or
     local tests.

This keeps tokens and artifacts local while leveraging a helpful assistant.

If you want, I can also add integration into the CI workflow to automatically copy the final report into a known artifact name for easier downloads.
