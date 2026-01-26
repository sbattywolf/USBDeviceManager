#!/usr/bin/env python3
"""
Parse TRX files and console logs to extract skipped tests, parse errors and produce a small JSON artifact.
Usage: parse_test_logs.py --results <dir> --out <file>
"""
import argparse
import json
import os
import xml.etree.ElementTree as ET

def parse_trx(trx_path):
    out = {"file": os.path.basename(trx_path), "counters": {}, "skipped": []}
    try:
        tree = ET.parse(trx_path)
        root = tree.getroot()
        # namespaces can vary; look for ResultSummary/Counters
        for counters in root.findall('.//Counters'):
            for attr, val in counters.attrib.items():
                out['counters'][attr] = int(val) if val.isdigit() else val
        # find UnitTestResult elements
        for utr in root.findall('.//UnitTestResult'):
            outcome = utr.attrib.get('outcome')
            test_name = utr.attrib.get('testName') or utr.attrib.get('testId')
            if outcome and outcome.lower() == 'skipped':
                out['skipped'].append(test_name)
    except Exception as e:
        out['error'] = str(e)
    return out


def parse_console_log(log_path):
    errors = []
    try:
        with open(log_path, 'r', encoding='utf-8', errors='ignore') as f:
            for i, line in enumerate(f, start=1):
                l = line.strip()
                if not l:
                    continue
                # naive heuristics for parse errors / exceptions
                if 'error parsing' in l.lower() or 'exception' in l.lower() or 'failed to parse' in l.lower():
                    errors.append({'line': i, 'text': l})
    except Exception as e:
        errors.append({'file_read_error': str(e)})
    return errors


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--results', required=True)
    p.add_argument('--out', required=True)
    args = p.parse_args()

    results_dir = args.results
    out = {'trx': [], 'console_errors': [], 'summary': {'total_skipped': 0, 'total_failed': 0, 'total_passed': 0}}

    if not os.path.isdir(results_dir):
        print(f"Results dir not found: {results_dir}")
        with open(args.out, 'w') as f:
            json.dump({'error': 'results_dir_not_found', 'path': results_dir}, f)
        raise SystemExit(2)

    for root, _, files in os.walk(results_dir):
        for name in files:
            path = os.path.join(root, name)
            if name.lower().endswith('.trx'):
                trx_info = parse_trx(path)
                out['trx'].append(trx_info)
                c = trx_info.get('counters', {})
                out['summary']['total_skipped'] += int(c.get('skipped', 0) or c.get('aborted', 0) or 0)
                out['summary']['total_failed'] += int(c.get('failed', 0) or 0)
                out['summary']['total_passed'] += int(c.get('passed', 0) or 0)
            elif name.lower().endswith('.log') or 'console' in name.lower():
                errs = parse_console_log(path)
                out['console_errors'].extend(errs)

    # dedupe skipped names
    skipped = []
    for t in out['trx']:
        for s in t.get('skipped', []):
            if s and s not in skipped:
                skipped.append(s)
    out['summary']['skipped_tests'] = skipped

    with open(args.out, 'w', encoding='utf-8') as f:
        json.dump(out, f, indent=2)
    print(f"WROTE {args.out}")

if __name__ == '__main__':
    main()
