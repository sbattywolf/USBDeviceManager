#!/usr/bin/env python3
"""Merge multiple VSTest TRX files into a single TRX.

Usage: merge_trx.py <src_dir> <out_trx>

This script takes all .trx files under <src_dir> (recursively), and produces
an aggregated TRX at <out_trx> by using the first TRX as a base and appending
all <UnitTestResult> entries from the others. It also sums the <Counters>
attributes in the <ResultSummary> to produce accurate totals.
"""
import sys
import json
import xml.etree.ElementTree as ET
from pathlib import Path


def local_name(tag: str) -> str:
    if tag is None:
        return ''
    if '}' in tag:
        return tag.split('}', 1)[1]
    return tag


def find_counters(elem):
    for child in elem.iter():
        if local_name(child.tag) == 'Counters':
            return child
    return None


def sum_counters(target, src):
    if target is None and src is None:
        return None
    if target is None:
        return src
    if src is None:
        return target
    for k, v in src.attrib.items():
        try:
            val = int(v)
        except Exception:
            continue
        old = int(target.attrib.get(k, '0'))
        target.attrib[k] = str(old + val)
    return target


def sum_counters_from_dict(target, dct):
    if dct is None:
        return target
    if target is None:
        target = ET.Element('Counters')
    for k, v in dct.items():
        try:
            val = int(v)
        except Exception:
            continue
        old = int(target.attrib.get(k, '0'))
        target.attrib[k] = str(old + val)
    return target


def main():
    if len(sys.argv) != 3:
        print("Usage: merge_trx.py <src_dir> <out_trx>", file=sys.stderr)
        return 2
    src = Path(sys.argv[1])
    out = Path(sys.argv[2])
    files = sorted([p for p in src.rglob('*.trx') if p.is_file()])
    if not files:
        print("No TRX files found in", src, file=sys.stderr)
        return 1
    if len(files) == 1:
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_bytes(files[0].read_bytes())
        print(f"Copied single TRX {files[0]} -> {out}")
        return 0

    print(f"Merging {len(files)} TRX files into {out}")
    # Parse first as base
    base_tree = ET.parse(files[0])
    base_root = base_tree.getroot()

    # Find Results container in base
    results_elem = None
    for child in base_root.iter():
        if local_name(child.tag) == 'Results':
            results_elem = child
            break

    if results_elem is None:
        # Create Results element under TestRun if missing
        results_elem = ET.SubElement(base_root, 'Results')

    # Find base counters
    base_summary = None
    for child in base_root.iter():
        if local_name(child.tag) == 'ResultSummary':
            base_summary = child
            break
    base_counters = find_counters(base_summary) if base_summary is not None else None

    # Iterate remaining files and append their UnitTestResult nodes
    for f in files[1:]:
        try:
            tree = ET.parse(f)
            root = tree.getroot()
        except Exception as e:
            print(f"Failed to parse {f}: {e}", file=sys.stderr)
            continue
        # find Results in this file
        other_results = None
        for child in root.iter():
            if local_name(child.tag) == 'Results':
                other_results = child
                break
        if other_results is None:
            continue
        # append each UnitTestResult to base Results
        for r in list(other_results):
            results_elem.append(r)

        # sum counters from this file
        other_summary = None
        for child in root.iter():
            if local_name(child.tag) == 'ResultSummary':
                other_summary = child
                break
        other_counters = find_counters(other_summary) if other_summary is not None else None
        base_counters = sum_counters(base_counters, other_counters)

        # if any summary shows Failed outcome, set base to Failed
        if other_summary is not None and other_summary.attrib.get('outcome', '').lower() == 'failed':
            if base_summary is None:
                # create one
                base_summary = ET.SubElement(base_root, 'ResultSummary')
            base_summary.attrib['outcome'] = 'Failed'

    # Ensure counters are attached under ResultSummary
    if base_summary is None:
        base_summary = ET.SubElement(base_root, 'ResultSummary')
    if base_counters is not None:
        # remove existing counters in base_summary then append our aggregated one
        for c in list(base_summary):
            if local_name(c.tag) == 'Counters':
                base_summary.remove(c)
        base_summary.append(base_counters)

    # Discover any skip-info.json files under the source tree and sum their counters
    # Skip-info format expected: { 'trx': [ { 'file': '...', 'counters': { ... } }, ... ], 'summary': {...} }
    try:
        skip_files = sorted([p for p in src.rglob('skip-info.json') if p.is_file()])
    except Exception:
        skip_files = []
    for s in skip_files:
        try:
            j = json.loads(s.read_text(encoding='utf-8'))
        except Exception as e:
            print(f"Failed to read {s}: {e}", file=sys.stderr)
            continue
        for entry in j.get('trx', []):
            counters = entry.get('counters')
            if counters:
                base_counters = sum_counters_from_dict(base_counters, counters)
        # also consider top-level summary counters if present
        summary = j.get('summary')
        if summary and isinstance(summary, dict):
            # map summary keys to counters where meaningful
            base_counters = sum_counters_from_dict(base_counters, summary)

    # re-attach updated counters after skip-info aggregation
    if base_counters is not None:
        for c in list(base_summary):
            if local_name(c.tag) == 'Counters':
                base_summary.remove(c)
        base_summary.append(base_counters)

    out.parent.mkdir(parents=True, exist_ok=True)
    base_tree.write(out, encoding='utf-8', xml_declaration=True)
    print(f"WROTE {out}")
    return 0


if __name__ == '__main__':
    sys.exit(main())
