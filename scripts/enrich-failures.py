import json
import os
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT_BASE = ROOT / 'artifacts' / 'enriched' / 'failures'
OUT_BASE.mkdir(parents=True, exist_ok=True)

with open(ROOT / 'tests-summary.json', 'r', encoding='utf-8') as fh:
    summary = json.load(fh)

failures = summary.get('failures', [])
pattern = re.compile(r'Exception|ERROR|Timeout|Not Found|404|Assertion', re.IGNORECASE)

for f in failures:
    name = f.get('name') or 'unknown'
    safe = re.sub(r'[^A-Za-z0-9._-]', '_', name)[:200]
    outdir = OUT_BASE / safe
    outdir.mkdir(parents=True, exist_ok=True)
    details_path = outdir / 'details.txt'
    with open(details_path, 'w', encoding='utf-8') as d:
        d.write(f"Name: {name}\n")
        d.write(f"Outcome: {f.get('outcome')}\n")
        d.write(f"Message:\n{f.get('message')}\n")
        d.write(f"Source file: {f.get('file')}\n")

    # copy the failing TRX if present
    src = ROOT / f.get('file') if f.get('file') else None
    if src and src.exists():
        try:
            shutil.copy(src, outdir / src.name)
        except Exception:
            pass

    # search workspace for matching log lines (limit 200)
    matches = []
    for dirpath, dirnames, filenames in os.walk(ROOT):
        # skip artifacts/enriched to avoid recursion
        if str(OUT_BASE) in dirpath:
            continue
        for fname in filenames:
            if len(matches) >= 200:
                break
            path = Path(dirpath) / fname
            # only scan text-like files
            try:
                with open(path, 'r', errors='ignore', encoding='utf-8') as rf:
                    for i, line in enumerate(rf):
                        if pattern.search(line):
                            rel = path.relative_to(ROOT)
                            matches.append(f"{rel}:{i+1}: {line.strip()}")
                            if len(matches) >= 200:
                                break
            except Exception:
                continue
        if len(matches) >= 200:
            break

    with open(outdir / 'log-excerpts.txt', 'w', encoding='utf-8') as le:
        if matches:
            le.write('\n'.join(matches[:200]))
        else:
            le.write('No log excerpts found matching patterns.')

print(f'WROTE {len(failures)} failure folders to: {OUT_BASE}')
