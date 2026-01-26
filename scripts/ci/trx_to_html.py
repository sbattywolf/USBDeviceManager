#!/usr/bin/env python3
"""Convert TRX files under a folder into a small HTML summary.

Usage: python scripts/ci/trx_to_html.py --input-dir artifacts --out artifacts/trx-summary.html
"""
import argparse
import html
import os
import xml.etree.ElementTree as ET


def summarize_trx(path):
    try:
        tree = ET.parse(path)
        root = tree.getroot()
    except Exception as e:
        return {'file': path, 'error': str(e)}

    ns = {'': root.tag.split('}')[0].strip('{')} if '}' in root.tag else {}
    results = root.findall('.//UnitTestResult') if ns else root.findall('.//UnitTestResult')
    total = len(results)
    passed = sum(1 for r in results if r.get('outcome') == 'Passed')
    failed = sum(1 for r in results if r.get('outcome') == 'Failed')
    failures = []
    for r in results:
        if r.get('outcome') == 'Failed':
            name = r.get('testName') or r.get('testId') or ''
            msg = ''
            out = r.find('Output')
            if out is not None:
                err = out.find('ErrorInfo')
                if err is not None:
                    msg_el = err.find('Message')
                    if msg_el is not None:
                        msg = msg_el.text or ''
            failures.append({'name': name, 'message': msg})

    return {'file': path, 'total': total, 'passed': passed, 'failed': failed, 'failures': failures}


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--input-dir', required=True)
    p.add_argument('--out', required=True)
    args = p.parse_args()

    trx_files = []
    for root, _, files in os.walk(args.input_dir):
        for f in files:
            if f.lower().endswith('.trx'):
                trx_files.append(os.path.join(root, f))

    summaries = [summarize_trx(t) for t in sorted(trx_files)]

    with open(args.out, 'w', encoding='utf-8') as fh:
        fh.write('<html><head><meta charset="utf-8"><title>TRX Summary</title></head><body>')
        fh.write('<h1>TRX Summary</h1>')
        if not summaries:
            fh.write('<p>No TRX files found.</p>')
        for s in summaries:
            fh.write(f"<h2>{html.escape(s.get('file',''))}</h2>")
            if 'error' in s:
                fh.write(f"<pre>Error parsing TRX: {html.escape(s['error'])}</pre>")
                continue
            fh.write('<ul>')
            fh.write(f"<li>Total: {s['total']}</li>")
            fh.write(f"<li>Passed: {s['passed']}</li>")
            fh.write(f"<li>Failed: {s['failed']}</li>")
            fh.write('</ul>')
            if s['failures']:
                fh.write('<h3>Failures</h3><ul>')
                for f in s['failures']:
                    fh.write('<li>')
                    fh.write(f"<strong>{html.escape(f['name'])}</strong>: {html.escape(f['message'] or '')}")
                    fh.write('</li>')
                fh.write('</ul>')
        fh.write('</body></html>')


if __name__ == '__main__':
    main()
