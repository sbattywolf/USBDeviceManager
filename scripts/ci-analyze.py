#!/usr/bin/env python3
"""
ci-analyze.py

Parse TRX test result files under the current directory and write
`tests-summary.json` and `tests-summary.txt`.

Usage: python3 scripts/ci-analyze.py
"""
import xml.etree.ElementTree as ET
import json
import glob
import os


def find_trx_files():
    return glob.glob('**/*.trx', recursive=True)


def parse_trx_files(files):
    total = 0
    passed = 0
    failed = 0
    failed_list = []
    for f in files:
        try:
            tree = ET.parse(f)
            root = tree.getroot()
            # Namespace-agnostic element matching: some TRX files use a default
            # namespace so tags are like '{...}UnitTestResult'. We'll match by
            # tag suffix to be robust across generators.
            def tag_endswith(el, suffix):
                try:
                    return el.tag.endswith(suffix)
                except Exception:
                    return False

            # Find Counters elements (if present)
            file_total = 0
            file_passed = 0
            file_failed = 0
            counters_found = False
            for el in root.iter():
                if tag_endswith(el, 'Counters'):
                    counters_found = True
                    file_total += int(el.attrib.get('total', '0'))
                    file_passed += int(el.attrib.get('passed', '0'))
                    file_failed += int(el.attrib.get('failed', '0'))

            # Collect UnitTestResult nodes
            utrs = [el for el in root.iter() if tag_endswith(el, 'UnitTestResult')]

            def find_message_text(node):
                # Search for the first element with tag ending in 'Message'
                for c in node.iter():
                    if tag_endswith(c, 'Message') and c.text:
                        return c.text.strip()
                return ''

            for utr in utrs:
                outcome = utr.attrib.get('outcome', '')
                if outcome != 'Passed':
                    name = utr.attrib.get('testName') or utr.attrib.get('testId', '')
                    msg = find_message_text(utr)
                    failed_list.append({'file': f, 'name': name, 'outcome': outcome, 'message': msg})

            if not counters_found:
                file_total = len(utrs)
                file_passed = sum(1 for utr in utrs if utr.attrib.get('outcome', '') == 'Passed')
                file_failed = file_total - file_passed

            total += file_total
            passed += file_passed
            failed += file_failed
        except Exception as e:
            failed_list.append({'file': f, 'name': '<parse error>', 'outcome': 'Error', 'message': str(e)})
    summary = {'total': total, 'passed': passed, 'failed': failed, 'files': files, 'failures': failed_list}
    return summary


def write_summary(summary):
    with open('tests-summary.json', 'w', encoding='utf-8') as fh:
        json.dump(summary, fh, indent=2)
    with open('tests-summary.txt', 'w', encoding='utf-8') as fh:
        fh.write(f"Total: {summary['total']}\nPassed: {summary['passed']}\nFailed: {summary['failed']}\n\n")
        if summary['failed'] > 0:
            fh.write('Failures:\n')
            for it in summary['failures']:
                fh.write(f"- {it['name']} ({it['outcome']}): {it['message']} [file:{it['file']}]\n")


def main():
    files = find_trx_files()
    if not files:
        print('No TRX files found')
        # create empty minimal outputs
        write_summary({'total':0,'passed':0,'failed':0,'files':[],'failures':[]})
        return 0
    summary = parse_trx_files(files)
    write_summary(summary)
    print('WROTE tests-summary.json and tests-summary.txt')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
