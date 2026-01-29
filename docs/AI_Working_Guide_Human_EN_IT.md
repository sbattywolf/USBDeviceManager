 # AI Working Guide — Human Format (English / Italiano)

 Version: 2026-01-27
 Scope: Practical guide for working with AI across the project lifecycle, written from hands-on experience in this repository. Keep this local and do not commit sensitive secrets.

 Structure
 - Preface
 - Roles and responsibilities (global)
 - Chapter 1 — Debugging / Debugging (IT)
 - Chapter 2 — Testing / Testing (IT)
 - Chapter 3 — Tool Framework / Framework Strumenti (IT)
 - Chapter 4 — Code Strategy Implementation / Implementazione Strategia Codice (IT)
 - Chapter 5 — Testing Strategy Implementation / Implementazione Strategia Testing (IT)
 - Chapter 6 — Lifecycle Strategy Implementation / Implementazione Ciclo di Vita (IT)
 - Ways of working: top-down vs bottom-up
 - Documentation maintenance & update loops
 - Quick references to this repository (examples)
 - Friendly reminders and troubleshooting quick tips

 Preface
 -- EN
 This guide explains how to collaborate with AI tools (LLMs, agents, CLI helpers) when developing and maintaining code in this repository. It mixes prescriptive processes, short checklists and examples pulled from the repo (sanitization, runner re-registration script, CI troubleshooting) so you can run through the steps immediately.

 -- IT
 Questa guida spiega come collaborare con strumenti AI (LLM, agenti, helper CLI) durante lo sviluppo e la manutenzione del codice in questo repository. Contiene processi pratici, checklist e esempi tratti dal repo (sanitizzazione, script di registrazione runner, troubleshooting CI) per poter applicare subito i passaggi.

 Roles & Responsibilities (global)
 - Product/Project Owner: defines scope, risk appetite, and approves sensitive changes (history rewrite, runner renaming).
 - CI/DevOps Engineer: manages runners, secrets, CI workflow definitions, artifact policy.
 - Developer/AI Integrator: writes prompts, integrates tools, refactors code with AI assistance.
 - QA/Test Engineer: designs tests, validates TRX artifacts, verifies sanitization across artifacts.
 - Security/Compliance: reviews secret handling, validates redaction, approves vault usage.

 Chapter 1 — Debugging / Debugging (IT)
 Roles: Developer, CI/DevOps, QA
 Goal: Rapidly identify AI-assisted changes that cause failures and isolate root cause.

 Checklist
 - Reproduce: run failing workflow locally or in a disposable environment.
 - Gather artifacts: download TRX and job logs (use `gh run download <id>`).
 - Search tokens: run `Select-String` or ripgrep for personal tokens or suspicious strings.
 - Isolate: bisect commits if needed (git bisect) and try minimal repro.

 Patterns & Tips
 - When CI fails before tests (setup stage), check runner setup logs — they include runner name and machine lines. Example: "Machine name: 'LITTLE_BEAST'".
 - If artifact upload shows "No files were found" ensure test binary paths and artifact globs match actual outputs. Adjust build/publish steps to place binaries into expected paths.
 - Keep a small diagnostic artifact creation pattern in scripts so failing runs still upload at least one artifact (e.g., `test-results/missing-server.txt`).

 Italian summary
 Vedere i punti sopra: riprodurre, raccogliere artifact, cercare token, isolare la causa.

 Chapter 2 — Testing / Testing (IT)
 Roles: QA, Developer
 Goal: Ensure AI-assisted code changes are thoroughly tested and TRX artifacts are preserved.

 Checklist
 - Unit tests first: run `dotnet test` with `--logger:xunit`/TRX options locally.
 - Pester tests for PowerShell scripts: add to CI and ensure TRX upload per job.
 - Integration/E2E: use self-hosted runners with correct binaries present; pre-flight checks should fail early and upload diagnostics.

 Best practices
 - Add test artifact upload per job; keep per-job TRX for aggregation.
 - Write deterministic tests where possible; use snapshots with clear redaction rules for environment-specific values.

 Chapter 3 — Tool Framework / Framework Strumenti (IT)
 Roles: CI/DevOps, Developer
 Goal: Define and standardize the set of tools (CLI, Bitwarden, gh, bw, etc.) and their automation approaches.

 Core tools used in this repo (examples)
 - `gh` — GitHub CLI for run/dispatch/artefact download.
 - `bw` — Bitwarden CLI for vault-based secrets retrieval.
 - PowerShell scripts under `scripts/ci/` and `scripts/runner/`.

 Guidelines
 - Keep automation scripts in `scripts/` with README and usage examples. Example: `scripts/runner/register-runner-from-bitwarden.ps1`.
 - Use versioned tool invocation when possible (pin CLI versions or check `--version`).

 Chapter 4 — Code Strategy Implementation / Implementazione Strategia Codice (IT)
 Roles: Developer, AI Integrator
 Goal: Design how to use AI for code changes safely and reliably.

 Strategy
 - Prompt-first design: write explicit small prompts for each change (include test cases and expected outputs).
 - Small iterations: prefer many small, reviewed commits rather than large rewrites.
 - Keep deterministic transformations (sanitization) in scripts with dry-run and backup modes.

 Examples from repo
 - Sanitization scripts: `scripts/sanitize-*.ps1` with dry-run default, apply via `-Run`, backups under `.sanitize-backup/`.

 Chapter 5 — Testing Strategy Implementation / Implementazione Strategia Testing (IT)
 Roles: QA, Developer
 Goal: Ensure tests validate both functional behavior and that artifacts/logs contain no sensitive tokens.

 Approach
 - Add Pester tests for PS scripts.
 - Add TRX upload step for each test job.
 - Add post-run scanning job that aggregates TRX and searches for forbidden tokens.

 Chapter 6 — Lifecycle Strategy Implementation / Implementazione Ciclo di Vita (IT)
 Roles: Project Owner, DevOps
 Goal: Define lifecycle for AI-assisted features: design → prompt → implement → test → review → sanitize → release.

 Lifecycle example
 - Design: document desired change, risks, and tests.
 - Prompt + Implement: create minimal prompt that the AI will use to produce code.
 - Review: human review (PR), run tests.
 - Sanitize: run repository sanitization scripts if artifacts include sensitive info.
 - Release: merge and tag; ensure documentation updated.

 Ways of working: top-down vs bottom-up
 - Top-down: start from product/feature spec, decompose into tasks, create high-level prompts for AI to implement modules.
 - Bottom-up: let AI propose refactors or tests based on current code; accept small vetted changes and integrate upward.

 Documentation maintenance & update loops
 - Keep a short `docs/` local checklist for each repo change requiring doc updates.
 - Adopt edit-on-change: include a CI job that checks documentation changed in same PR for non-trivial changes.

 Repository-specific quick references
 - Runner registration helper: `scripts/runner/register-runner-from-bitwarden.ps1`
 - Troubleshooting doc: `docs/troubleshooting-runner.md`
 - Sanitization artifacts backup: `.sanitize-backup/`

 Friendly reminders
 - If this is getting complicated, pause and take a break: MAYBE YOU NEED TO TAKE A BREAK — step away 10–20 minutes and return with fresh eyes.
 - Keep prompts short, precise and include acceptance tests.

 Appendix: Screenshots & code snapshots
 - Where useful, capture the job setup log that contains the machine name (screenshot) and the failing step output. Save locally under `docs/screenshots/`.

 End — English / Fine — Italiano
