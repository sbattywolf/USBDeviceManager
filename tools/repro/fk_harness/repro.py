"""
Deterministic FK-race repro harness

Usage:
  python repro.py --url http://127.0.0.1:5010/api/logs --concurrency 100 --requests 200 --dry-run

This script sends concurrent POST requests to the target endpoint with deterministic payloads
and saves response/error summaries to `artifacts/repro/<timestamp>/`.

Designed to be run locally or in CI against a running instance of the server.
"""
from __future__ import annotations
import argparse
import concurrent.futures
import json
import os
import sys
import time
import uuid
from datetime import datetime
from typing import Dict

try:
    import requests
except Exception:
    print("Missing dependency: requests. Install with `pip install requests`.")
    sys.exit(2)


def make_payload(i: int) -> Dict:
    # Deterministic payload based on index
    return {
        "clientId": f"repro-client-{i % 20}",
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "sequence": i,
        "data": {"value": i}
    }


def worker(session: requests.Session, url: str, idx: int, timeout: float = 5.0):
    payload = make_payload(idx)
    try:
        r = session.post(url, json=payload, timeout=timeout)
        return idx, r.status_code, r.text[:200]
    except Exception as ex:
        return idx, None, str(ex)


def run(url: str, concurrency: int, total: int, outdir: str, dry_run: bool = False):
    os.makedirs(outdir, exist_ok=True)
    summary = {
        "url": url,
        "concurrency": concurrency,
        "total": total,
        "start": datetime.utcnow().isoformat() + "Z",
        "results": []
    }

    if dry_run:
        print(f"Dry-run OK: would run {total} requests @ concurrency {concurrency} to {url}")
        return 0

    session = requests.Session()
    session.headers.update({"User-Agent": "repro-harness/1.0"})

    with concurrent.futures.ThreadPoolExecutor(max_workers=concurrency) as ex:
        futures = [ex.submit(worker, session, url, i) for i in range(total)]
        for f in concurrent.futures.as_completed(futures):
            idx, status, text = f.result()
            summary["results"].append({"i": idx, "status": status, "excerpt": text})

    summary["end"] = datetime.utcnow().isoformat() + "Z"
    summary_file = os.path.join(outdir, "summary.json")
    with open(summary_file, "w", encoding="utf8") as fh:
        json.dump(summary, fh, indent=2)
    print(f"Wrote summary to {summary_file}")
    return 0


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--url", required=True, help="Target POST URL (e.g. http://127.0.0.1:5010/api/logs)")
    p.add_argument("--concurrency", type=int, default=50)
    p.add_argument("--requests", type=int, default=200)
    p.add_argument("--outdir", default=None)
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    ts = datetime.utcnow().strftime("%Y%m%d-%H%M%S")
    outdir = args.outdir or os.path.join("artifacts", "repro", f"run-{ts}")
    rc = run(args.url, args.concurrency, args.requests, outdir, dry_run=args.dry_run)
    sys.exit(rc)
