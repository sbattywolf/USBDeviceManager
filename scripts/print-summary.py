#!/usr/bin/env python3
import sys, json

def main():
    if len(sys.argv) < 2:
        print('Usage: print-summary.py <json-file>', file=sys.stderr)
        return 2
    p = sys.argv[1]
    try:
        d = json.load(open(p, encoding='utf-8'))
    except Exception as e:
        print(f"Total: 0, Passed: 0, Failed: 0  # parse error: {e}")
        return 0
    total = d.get('total','n/a')
    passed = d.get('passed','n/a')
    failed = d.get('failed',0)
    print(f"Total: {total}, Passed: {passed}, Failed: {failed}")
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
