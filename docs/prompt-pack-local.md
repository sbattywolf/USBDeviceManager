# Prompt-Pack: Local-Friendly Variants

This file contains compact prompt examples and run snippets targeting local runtimes: Ollama, Llama (via llama.cpp), and GPT-5 mini (local). Use the variant that matches your environment.

1) Ollama (recommended for macOS/Linux with Ollama installed):

System: You are a precise code assistant. Follow instructions exactly and produce minimal diffs.

User: Given the JSON AI working guide at docs/AI_Working_Guide_AI.json, produce a step-by-step plan to implement the `artifact_scan` job in GitHub Actions. Output as a compact GitHub Action YAML snippet and a PowerShell script `scripts/ci/artifact_scan.ps1`.

Run example:
ollama run --model llama2 --input-file prompt.txt

2) llama.cpp / Llama family (local CPU):

System: You are a conservative assistant that keeps answers short.

User: Convert the AI guide to an actionable checklist and output the exact PowerShell and GitHub Actions YAML required to add a post-run artifact scanning job. Keep files under `scripts/ci/` and `ci/workflows/`.

Run example (llama.cpp):
./main -m models/llama2.bin -p "<prompt>"

3) GPT-5 mini (local):

System: You are GPT-5 mini. Provide concise code-first responses.

User: Create `scripts/ci/artifact_scan.ps1` which scans an artifacts folder for tokens and returns exit code 1 if matches found. Also create `ci/workflows/artifact-scan.yml` that runs after tests and uploads a JSON report.

Run example: gpt5-mini --prompt-file prompt.txt --model local-gpt5-mini
