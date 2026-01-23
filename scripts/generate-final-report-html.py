#!/usr/bin/env python3
"""Generate a simple HTML final report from tests-summary.json files.

Usage: python3 scripts/generate-final-report-html.py [--src DIR] [--out FILE]
Defaults: --src=./artifacts/summaries  --out=final-report.html
Looks recursively for files named tests-summary.json and builds a summary
and failure listing.
"""
import argparse
import json
import os
from pathlib import Path


TEMPLATE = """
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8"/>
    <meta name="viewport" content="width=device-width,initial-scale=1" />
    <title>CI Final Test Summary</title>
    <style>
        body{{font-family:Arial,Helvetica,sans-serif;padding:18px;color:#222}}
        h1{{font-size:20px}}
        table{{border-collapse:collapse;width:100%;margin:12px 0}}
        th,td{{border:1px solid #ddd;padding:8px;text-align:left}}
        th{{background:#f4f4f4}}
        .failed{{color:#b00;font-weight:700}}
        pre{{background:#f8f8f8;border:1px solid #eee;padding:8px;overflow:auto}}
    </style>
</head>
<body>
    <h1>CI Final Test Summary</h1>
    <p>Generated: {utc}</p>
    <h2>Summaries</h2>
    <table>
        <thead><tr><th>Type</th><th>Total</th><th>Passed</th><th>Failed</th></tr></thead>
        <tbody>
        {rows}
        </tbody>
    </table>

    {fail_section}
</body>
</html>
"""


def find_summary_files(src_dir: Path):
    for p in src_dir.rglob('tests-summary.json'):
        yield p


def load_summaries(src_dir: Path):
    summaries = {}
    for jf in find_summary_files(src_dir):
        try:
            data = json.loads(jf.read_text(encoding='utf-8'))
        except Exception as e:
            data = {'total': 0, 'passed': 0, 'failed': 0, 'files': [], 'failures': [{'file': str(jf), 'name': '<parse error>', 'message': str(e)}]}
        key = jf.parent.name or str(jf.parent)
        # if multiple files in same folder, merge
        if key in summaries:
            s = summaries[key]
            s['total'] += int(data.get('total', 0) or 0)
            s['passed'] += int(data.get('passed', 0) or 0)
            s['failed'] += int(data.get('failed', 0) or 0)
            s['failures'].extend(data.get('failures', []) or [])
        else:
            summaries[key] = {
                'total': int(data.get('total', 0) or 0),
                'passed': int(data.get('passed', 0) or 0),
                'failed': int(data.get('failed', 0) or 0),
                'files': data.get('files', []),
                'failures': data.get('failures', []) or []
            }
    return summaries


def build_rows(summaries):
    rows = []
    for k, v in sorted(summaries.items()):
        cls = 'failed' if v['failed'] > 0 else ''
        rows.append(f"<tr><td>{k}</td><td>{v['total']}</td><td>{v['passed']}</td><td class=\"{cls}\">{v['failed']}</td></tr>")
    return '\n'.join(rows)


def build_failure_section(summaries):
    parts = []
    for k, v in sorted(summaries.items()):
        if not v['failures']:
            continue
        parts.append(f"<h3>{k} — Failures ({len(v['failures'])})</h3>")
        for f in v['failures']:
            name = f.get('name') or ''
            msg = f.get('message') or ''
            fileloc = f.get('file') or ''
            parts.append('<div style="margin-bottom:8px"><strong>{}</strong> <em>{}</em><pre>{}</pre><small>File: {}</small></div>'.format(name, f.get('outcome',''), msg, fileloc))
    if not parts:
        return '<p>No failures detected.</p>'
    return '\n'.join(parts)


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--src', default='artifacts/summaries', help='Directory to search for tests-summary.json')
    p.add_argument('--out', default='final-report.html', help='Output HTML filename')
    args = p.parse_args()

    src = Path(args.src)
    if not src.exists():
        # fallback to current workspace (use recursive search)
        src = Path('.')

    summaries = load_summaries(src)
    rows = build_rows(summaries)
    fail_section = build_failure_section(summaries)

    html = TEMPLATE.format(utc=__import__('datetime').datetime.utcnow().isoformat() + 'Z', rows=rows, fail_section=fail_section)
    Path(args.out).write_text(html, encoding='utf-8')
    print('WROTE', args.out)


if __name__ == '__main__':
    main()
