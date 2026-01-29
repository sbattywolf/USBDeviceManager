# Project Epics & Prioritized Backlog

This document collects epics across interactive, CI, GUI, testing, and performance work. Use it as the single place to prioritize and split into stories.

Priority key: P0 (highest), P1, P2

---

## Epic: Interactive Menu Improvements (P0)
- Owner: infra/dev
- Scope: finish idempotent start/stop, status refresh, mock-mode robustness, persisted defaults, timeouts.
- Status: in-progress
- Estimated effort: 8–12 days (end-to-end) — split into stories.
- Next actions:
  - Finish idempotency fixes + unit tests (1–2d)
  - Add JSON assertions for status (0.5d)
  - Harden timeouts and retry tests (0.5–1d)

## Epic: CI - Modular Self-Hosted Workflows (P0)
- Owner: infra
- Scope: `fulltest-ci.yml` modular jobs (unit, integration, interactive-mock, unhappy, gated acceptance), artifacts, summary JSON.
- Status: drafted (workflow added)
- Estimated effort: 2–4 days to refine and harden on self-hosted fleet.
- Next actions: add runner labels, secrets guidance, and platform matrix.

## Epic: Test Coverage & Unhappy Scenarios (P0)
- Owner: QA
- Scope: expand CI harness to exercise missing-runtime, locked-log, permission-denied, and other failures using mock-mode; add assertions and triage artifacts.
- Status: in-progress (mock harness present)
- Estimated effort: 3–5 days (create scenarios + CI jobs).
- Next actions: enumerate unhappy scenarios, implement mock injectors, add tests.

## Epic: GUI Implementation (P1)
- Owner: UX/FE
- Scope: produce a small GUI for local operators to view server/agent status, start/stop, tail logs, and surface owning-terminals. Candidate tech: Electron (cross-platform), WPF (Windows native), or minimal web UI served locally.
- Status: not-started
- Estimated effort: 5–10 days (MVP) + 1–2 days for test harness integration.
- Next actions:
  - Decide technology stack (pro/con matrix)
  - Scaffold minimal UI that talks to existing scripts via a small local API wrapper
  - Add mock-mode integration for CI UI smoke tests

## Epic: Performance Monitoring & Parallel Test Strategy (P1)
- Owner: infra/perf
- Scope: collect timings for test steps, enable running long sequences in background, orchestrate parallel test shards on self-hosted agents, and monitor resource usage.
- Status: not-started
- Estimated effort: 3–6 days for baseline; iterative improvements thereafter.
- Next actions: pick metrics (time, CPU, memory), add lightweight collector (PowerShell +PerfCounters), design shard model.

## Epic: Acceptance Real-Mode Gating & Docs (P1)
- Owner: QA/infra
- Scope: finalize guarded real-mode tests requiring explicit opt-in + elevation; ensure they cannot run on shared CI without permission.
- Status: partial
- Estimated effort: 1–2 days to finalize scripts and docs.
- Next actions: add explicit gating checks, template for elevated-run logs.

## Epic: Docs & Runbooks Consolidation (P2)
- Owner: docs
- Scope: centralize `TESTING.md`, `docs/interactive.md`, runbooks for CI integration, troubleshooting templates, and contributor guidance.
- Status: in-progress
- Estimated effort: 2–3 days
- Next actions: finalize runbook checklist and CI artifacts upload examples.

---

## How to use
- Break epics into issues/stories sized ~0.5–2 days each.
- Prioritize P0 work first: finish interactive reliability, CI job variants, and unhappy-scenario tests.
- For GUI and performance work, create spikes to evaluate technology choices before committing.


*Document created by CI/assistant on 2026-01-29.*
