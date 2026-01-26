#!/usr/bin/env python3
"""enrich-summary.py

Create an enriched report + per-failure folders from a tests-summary.json file.
Usage: python3 scripts/enrich-summary.py --src tests-summary.json --out-dir artifacts/enriched/tests --report tests-enriched-report.txt
"""
import argparse
import json
import os
import shutil

parser = argparse.ArgumentParser(description='Enrich test summary into per-failure folders')
parser.add_argument('--src', default='tests-summary.json')
parser.add_argument('--out-dir', required=True)
parser.add_argument('--report', required=True)
args = parser.parse_args()

if not os.path.exists(args.src):
    print('Source summary not found:', args.src)
    raise SystemExit(0)

with open(args.src, 'r', encoding='utf-8') as fh:
    s = json.load(fh)

failed = int(s.get('failed', 0))
errors = any((f.get('outcome','') == 'Error') for f in s.get('failures', []))

if failed == 0 and not errors:
    print('No failures or parse errors; skipping enrichment')
    raise SystemExit(0)

os.makedirs(args.out_dir, exist_ok=True)
# Write report file
with open(args.report, 'w', encoding='utf-8') as fh:
    fh.write('=== Enriched Report ===\n')
    fh.write('See tests-summary.json for full summary.\n\n')
    txtpath = os.path.join(os.path.dirname(args.src), 'tests-summary.txt')
    if os.path.exists('tests-summary.txt'):
        with open('tests-summary.txt','r',encoding='utf-8') as tf:
            fh.write(tf.read())

# Create per-failure folders
for f in s.get('failures', []):
    name = f.get('name','unnamed') or 'unnamed'
    safe = ''.join(c if (c.isalnum() or c in '._-') else '_' for c in name)[:200]
    outdir = os.path.join(args.out_dir, safe)
    os.makedirs(outdir, exist_ok=True)
    with open(os.path.join(outdir, 'details.txt'), 'w', encoding='utf-8') as df:
        df.write(f"Name: {name}\n")
        df.write(f"Outcome: {f.get('outcome')}\n")
        df.write('Message:\n')
        df.write(f"{f.get('message')}\n")
        df.write(f"Source file: {f.get('file')}\n")
    # copy source TRX if present
    fileloc = f.get('file')
    if fileloc and os.path.exists(fileloc):
        try:
            shutil.copy(fileloc, outdir)
        except Exception:
            pass

print('Wrote', args.report, 'and per-failure folders under', args.out_dir)
