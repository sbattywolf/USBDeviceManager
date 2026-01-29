Process-Menu: Setup Owners — Iteration TODO

This checklist is a scenario-specific copy of the testing iteration template for the `Setup: Owning Terminals` feature.

- [ ] Parse-check `scripts/process-menu.ps1` (syntax ok)
- [ ] Ensure `PROCESS_MENU_TEST_MARKER` is set in the harness and add marker writes where mock/dry-run returns
- [ ] Create/verify `scripts/ci/test_process_menu_setup_owners.ps1` (inputs and assertions)
- [ ] Run isolated harness and capture artifacts:
  ```powershell
  $env:PROCESS_MENU_MOCK='1'; $env:PROCESS_MENU_TEST_MARKER='artifacts/pmm-setup.marker'; pwsh -NoProfile -File .\scripts\ci\test_process_menu_setup_owners.ps1
  ```
- [ ] Inspect marker and log outputs in `artifacts/` and fix issues
- [ ] Add the acceptance test to `scripts/ci/run_interactive_tests.ps1` (already done)
- [ ] Add/verify CI workflow runs mock acceptance (already added)
- [ ] If adding destructive actions, gate with `PROCESS_MENU_ALLOW_SIGNAL` and add docs/tests
- [ ] Close the iteration: run full `scripts/ci/run_interactive_tests.ps1` and confirm PASS

Notes
- Keep assertions focused on marker presence and non-destructive default behavior.
- Maintain the marker file name convention: `process-menu-<scenario>.marker` for consistency.

- Regression-test note: the `no-auto-advance` regression test was strengthened to avoid Read-Host capture flakiness — assert the menu header (preferred) or a stable menu line such as `0) Exit`, and verify the process remains running (do not rely solely on prompt text).

Owner: TBD
