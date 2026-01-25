Deterministic FK-race repro harness

Usage
-----

Run against a locally-running server instance (example assumes server on port 5010):

```bash
python repro.py --url http://127.0.0.1:5010/api/logs --concurrency 100 --requests 200
```

For CI dry-run validation (no requests):

```bash
python repro.py --url http://127.0.0.1:5010/api/logs --dry-run
```

Notes
-----
- The harness sends deterministic payloads so repeated runs are comparable.
- Results are written to `artifacts/repro/run-<timestamp>/summary.json`.
