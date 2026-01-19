```markdown
# Actionable TODOs (master list)

Date: 2026-01-19

This file centralizes concrete, actionable work items across the repository. Use it as the single source of truth for small-to-medium tasks that can be scheduled or assigned.

Format: - [Priority] Title — Short description (Owner / Estimate)

## Priority Legend
- P0: Blocker / must-have for next milestone
- P1: High priority (shippable features)
- P2: Medium priority (improvements / automation)
- P3: Low priority / research / long-term

---

## P0 — Immediate (ready before GUI work)
- [P0] CI: Package CI artifacts and keep one canonical artifacts folder — Ensure `ci/run-ci.ps1` outputs a single zip of artifacts per run (CI and local). (CI / 1d)
- [P0] Server: Implement USB device scanning core in `DevicesController` — Replace placeholder TODO with a real scanner or clearly stubbed interface. (Server / 2d)
- [P0] Server UI: Implement modal to add software and automation rules in `Home.razor` — minimal modal + server API call. (Frontend / 2d)

## P1 — High (enables Dashboard & Desktop GUI work)
- [P1] Blazor Dashboard: Real-time device monitoring panel — show connected devices, agent status, and simple controls. (Frontend / 3d)
- [P1] Desktop GUI (PyQt): Finish feature parity with reference GUI — device list, start/stop software, settings, status polling. (Desktop / 3d)
- [P1] Desktop GUI: Rename ambiguous `InputObject` fields to clearer names — update UI labels and data mappings, update API client if needed. (Desktop / 0.5d)
- [P1] Agent: Add a basic prerequisite-check script for agent runtime (PowerShell) — verify PS version, modules, connectivity. (Agent / 1d)

## P2 — Medium (stability & automation)
- [P2] Tests: Add CI job to regenerate `docs/TODOs-collected.md` and fail PRs with stray TODOs outside the centralized file. (CI / 0.5d)
- [P2] Tests: Add zipping of TRX/log artifacts and upload step (GitHub Actions). (CI / 0.5d)
- [P2] Agent: Improve agent install/distribution endpoint `/download/agent`. Add versioning metadata. (Server+Agent / 1d)
- [P2] Documentation: Create `docs/sessions/` canonical index and move session summaries there. Archive duplicates. (Docs / 0.5d)

## P3 — Long-term / Nice-to-have
- [P3] Authentication & Security: API keys, roles, audit logging. (Server / TBD)
- [P3] Mobile companion planning + remote access. (Product / TBD)

---

How to use this file
- Keep this file minimal and actionable. For multi-step items, link to an issue and keep the issue as the authoritative multi-step plan.
- When a TODO is complete, update this file and mark the line checked with `- [x]` and add a short note (date, PR link).

If you'd like, I can: create issues for each P0/P1 item, or start implementing the `InputObject` rename in the desktop GUI now.

```
