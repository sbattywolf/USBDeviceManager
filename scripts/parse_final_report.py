#!/usr/bin/env python3
"""
Scan downloaded CI artifacts for failure indicators and produce a compact JSON summary.

Usage:
  python scripts/parse_final_report.py --src artifacts/ci-run-21315105846 --out artifacts/ci-run-21315105846/ci-analysis.json

The script searches TRX, TXT, HTML, and LOG files for common failure keywords and
captures small contextual excerpts to help triage.
"""
from __future__ import annotations
import argparse
import json
import os
import re
from pathlib import Path

KEYWORDS = [
    r"TaskCanceledException",
    r"TaskCanceled",
    r"Assert\.Throws",
    r"Assertion",
    r"AssertionError",
    r"Assertion failed",
    r"404",
    r"Not Found",
    r"ERROR",
    r"Exception",
    r"Unhandled",
]


def scan_file(path: Path, patterns):
    results = []
    try:
        text = path.read_text(encoding='utf-8', errors='ignore')
    except Exception:
        return results
    lines = text.splitlines()
    for i, line in enumerate(lines):
        for p in patterns:
            if re.search(p, line, re.IGNORECASE):
                # capture context
                start = max(0, i - 3)
                end = min(len(lines), i + 3)
                excerpt = "\n".join(lines[start:end])
                results.append({"file": str(path), "lineno": i + 1, "pattern": p, "excerpt": excerpt})
    return results


def main(argv=None):
    p = argparse.ArgumentParser()
    p.add_argument("--src", required=True, help="Directory containing downloaded artifacts")
    p.add_argument("--out", default=None, help="Output JSON file (optional)")
    args = p.parse_args(argv)

    src = Path(args.src)
    if not src.exists():
        print(f"Source path {src} does not exist")
        return 2

    patterns = KEYWORDS
    matches = []
    for path in src.rglob("*"):
        if path.is_dir():
            continue
        if path.suffix.lower() in {".trx", ".txt", ".log", ".html", ".xml", ".json"}:
            m = scan_file(path, patterns)
            if m:
                matches.extend(m)

    out = {"source": str(src), "matches": matches}
    out_path = args.out or (src / "ci-analysis.json")
    with open(out_path, 'w', encoding='utf-8') as f:
        json.dump(out, f, indent=2, ensure_ascii=False)
    print(f"Wrote analysis to {out_path} (matches={len(matches)})")
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
