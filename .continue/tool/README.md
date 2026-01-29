AI tools in this repo (.continue/tool)

Purpose
- Small per-workspace helpers to start/stop local AI runtimes and fetch models.

Files
- Start-AI-Orchestrator.ps1 — starts ollama, VS Code, and an optional telemetry loop. Supports `-DryRun`, `-TimeoutSeconds`, and `-NoTelemetry`. Writes `.continue/tool/ai_env.pid` and appends events to `.continue/tool/ai_env.marker`.
- Start-Local-AI.ps1 — lightweight start of ollama and VS Code. Supports `-DryRun` and optional monitor duration. Writes PID/marker.
- Setup-AI-Models.ps1 — pulls models via `ollama pull`. Supports `-DryRun` and `-Yes` to skip confirmation. Checks free disk space before downloading.
- Stop-AI-Env.ps1 — stops models and cleans PID/marker. Supports `-DryRun`.

Prerequisites
- `ollama` in PATH
- `nvidia-smi` in PATH for GPU telemetry
- (optional) `mosquitto_pub` if you want to publish telemetry to Home Assistant

Safety
- The orchestrator can run indefinitely; use `-TimeoutSeconds` or run via a scheduled task.
 - The orchestrator can run indefinitely; use `-TimeoutSeconds` or run via a scheduled task.
 - Auto-disable telemetry: start the orchestrator with `-AutoDisableOnHighLoad` and optional thresholds `-VramThresholdMB` and `-TempThresholdC`. If the measured GPU VRAM usage or GPU temperature exceeds the thresholds, the orchestrator will stop publishing telemetry and append a `TELEMETRY_DISABLED` entry to `.continue/tool/ai_env.marker`.
- Model downloads are large; the setup script warns if free disk is below 20GB.
- Scripts write `.continue/tool/ai_env.pid` to track the environment. Use `Stop-AI-Env.ps1` to clean up.

Centralization vs per-repo
- Keep project-specific wrappers in `.continue/tool` and extract common primitives (start/stop/monitor/pull) to a central tools repo if you need reuse across projects.

Recommended next changes
- Add `-LogPath` support to save telemetry output.
- Add Windows service or scheduled task examples to run the orchestrator persistently.

