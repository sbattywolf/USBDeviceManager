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
            for counters in root.findall('.//Counters'):
                total += int(counters.attrib.get('total', '0'))
                passed += int(counters.attrib.get('passed', '0'))
                failed += int(counters.attrib.get('failed', '0'))
            for utr in root.findall('.//UnitTestResult'):
                if utr.attrib.get('outcome', '') != 'Passed':
                    name = utr.attrib.get('testName') or utr.attrib.get('testId', '')
                    msg = ''
                    m = utr.find('.//Message')
                    if m is None:
                        m = utr.find('.//Output/ErrorInfo/Message')
                    if m is not None and m.text:
                        msg = m.text.strip()
                    failed_list.append({'file': f, 'name': name, 'outcome': utr.attrib.get('outcome', ''), 'message': msg})
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
