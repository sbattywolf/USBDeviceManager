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
from datetime import datetime

# Inline SVG icons (small, high-contrast)
ICON_FOLDER = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="#fff" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h5l2 3h7a2 2 0 0 1 2 2z" fill="#0f172a"/></svg>'''
ICON_TRX = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="#fff" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="2" ry="2" fill="#0f172a"/><path d="M8 7h8M8 11h8M8 15h5" stroke="#fff"/></svg>'''
ICON_FILE = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="#fff" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" fill="#0f172a"/><path d="M14 2v6h6" stroke="#fff"/></svg>'''


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
        <thead><tr><th>Type</th><th>Total</th><th>Passed</th><th>Failed</th><th>Env OK</th><th>Env Reason</th></tr></thead>
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


def find_env_checks(src_dir: Path):
    envs = {}
    for p in src_dir.rglob('env-check.json'):
        try:
            data = json.loads(p.read_text(encoding='utf-8'))
        except Exception:
            data = None
        key = p.parent.name or str(p.parent)
        envs[key] = data
    return envs


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


def build_rows(summaries, env_map=None):
    rows = []
    env_map = env_map or {}
    for k, v in sorted(summaries.items()):
        cls = 'failed' if v['failed'] > 0 else ''
        env = env_map.get(k) or {}
        env_ok = env.get('env_ok') if isinstance(env, dict) else None
        reason = env.get('reason') if isinstance(env, dict) else ''
        env_cell = 'Yes' if env_ok is True or str(env_ok).lower() == 'true' else ('No' if env_ok is False or str(env_ok).lower() == 'false' else 'N/A')
        reason_text = ''
        if isinstance(reason, list):
            reason_text = ';'.join(reason)
        else:
            reason_text = str(reason or '')

        rows.append(f"<tr><td>{k}</td><td>{v['total']}</td><td>{v['passed']}</td><td class=\"{cls}\">{v['failed']}</td><td>{env_cell}</td><td>{html_escape(reason_text)[:200]}</td></tr>")
    return '\n'.join(rows)


NAME_SEGMENTS = 2


def build_failure_section(summaries):
    # categorize failures by test type (Unit, Integration, Functional, Regression, E2E, Other)
    def priority(msg: str):
        m = (msg or '').lower()
        if any(x in m for x in ('exception', 'assert', 'assertion', 'timeout', 'taskcanceled', 'task canceled')):
            return 0
        if any(x in m for x in ('notfound', '404', 'httpstatuscode', 'not found', '500', '503', 'connection')):
            return 1
        return 2

    def severity_label(pri: int):
        return ('high', 'medium', 'low')[pri] if pri in (0,1,2) else 'low'

    def clean_log(text: str) -> str:
        if not text:
            return ''
        lines = []
        for line in (text or '').splitlines():
            s = line.strip()
            if s.startswith('[xunit.net') or s.lower().startswith('discovering:') or s.lower().startswith('discovered:') or s.lower().startswith('starting:') or s.lower().startswith('finished:'):
                continue
            if s == '':
                continue
            lines.append(line)
        return '\n'.join(lines).strip()

    def component_bucket(name: str, group_key: str) -> str:
        # Determine logical component for grouping: Agent, Server, GUI
        n = ((name or '') + ' ' + (group_key or '')).lower()
        if 'agent' in n or 'simracingagent' in n or 'simracing_agent' in n or 'shared/SimRacingAgent' in n:
            return 'Failures Agent'
        if 'gui' in n or 'dashboard' in n or 'web_preview' in n or 'ui' in n:
            return 'Failures GUI (to be done)'
        # default to server for other test failures
        return 'Failures Server'

    # desired presentation sequence
    sequence = ['Failures Agent', 'Failures Server', 'Failures GUI (to be done)']

    def simplify_name(fullname: str) -> str:
        if not fullname:
            return fullname
        # remove common namespace prefixes
        prefixes = ['USBDeviceManager.Tests.', 'USBDeviceManager.Tests', 'USBDeviceManager.', 'Tests.']
        name = fullname
        for p in prefixes:
            if name.startswith(p):
                name = name[len(p):]
                break
        # keep last NAME_SEGMENTS segments to focus on class/method
        parts = name.split('.')
        seg = NAME_SEGMENTS if isinstance(NAME_SEGMENTS, int) and NAME_SEGMENTS > 0 else 2
        if len(parts) >= seg:
            return '.'.join(parts[-seg:])
        return name

    def infer_test_type(fullname: str, group: str) -> str:
        # Infer one of: unit, e2e, regression, other
        n = ((fullname or '') + ' ' + (group or '')).lower()
        if 'unit' in n or '.unit.' in n:
            return 'unit'
        if 'regress' in n or 'regression' in n:
            return 'regression'
        # treat 'functional', 'integration', 'e2e' as e2e-style tests
        if 'functional' in n or 'integration' in n or 'e2e' in n:
            return 'e2e'
        return 'other'

    categories = {s: [] for s in sequence}
    # collect failures
    for k, v in sorted(summaries.items()):
        for f in (v.get('failures', []) or []):
            name = f.get('name') or ''
            cat = component_bucket(name, k)
            # attach context: source folder key and simplified display name
            f['_group'] = k
            f['_display_name'] = simplify_name(name)
            categories.setdefault(cat, []).append(f)

    parts = []
    # build tab buttons
    btns = []
    contents = []
    for cat in sequence:
        items = categories.get(cat, [])
        count = len(items)
        btns.append(f'<button data-tab="tab-{cat.replace(" ", "_")}" class="{'active' if count>0 and len(btns)==0 else ''}">{cat} ({count})</button>')
        # build table for this category
        body = []
        # per-tab sub-controls: sub-tabs (All / Unit / E2E / Regression) and a per-tab name-segments select
        sub_controls = '''<div class="sub-controls" style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px">'''
        sub_controls += '''<div class="sub-tab-buttons"><button data-sub="all" class="active">All</button>'''
        sub_controls += '''<button data-sub="unit">Unit</button><button data-sub="e2e">E2E</button><button data-sub="regression">Regression</button></div>'''
        sub_controls += '''<div class="sub-name-segs">Name segs: <select class="nameSegmentsLocal"><option value="1">1</option><option value="2">2</option><option value="3">3</option></select></div></div>'''

        if count == 0:
            body.append(f'<div class="session-title">{cat}</div><div class="session-sub">No failures in this category.</div>')
        else:
            body.append(f'<div class="session-title">{cat} — Failures ({count})</div>')
            body.append(sub_controls)
            body.append('<table class="fail-table"><thead><tr><th style="width:40%">Test Case</th><th style="width:10%">Outcome</th><th style="width:40%">Description</th><th style="width:10%">Actions</th></tr></thead><tbody>')
            ordered = sorted(items, key=lambda f: (priority(f.get('message','')), f.get('name') or ''))
            for f in ordered:
                name = f.get('_display_name') or (f.get('name') or '')
                outcome = f.get('outcome') or ''
                raw_msg = (f.get('message') or '').strip()
                msg = raw_msg.replace('\n', ' ')
                # trim for table summary (shorter to avoid column overlap)
                trimmed = (msg[:120] + '...') if len(msg) > 120 else msg
                fileloc = f.get('file') or ''
                pri = priority(raw_msg)
                sev = severity_label(pri)
                group = f.get('_group') or ''

                # build action icons (use file:/// URIs where possible)
                from pathlib import Path
                links_html = []
                safe_name = sanitize_filename(name)
                folder_path = Path('artifacts') / 'enriched' / group / safe_name
                if folder_path.exists() and folder_path.is_dir():
                    try:
                        href = folder_path.resolve().as_uri()
                    except Exception:
                        href = str(folder_path).replace('\\', '/')
                    links_html.append(f'<a class="icon" href="{href}" title="Open enrichment folder">{ICON_FOLDER}</a>')

                # surface common TRX files if present in enrichment folder
                for trx_name in ('all-tests.trx', 'server-all.trx', 'shellrunner-fail.trx'):
                    trx_path = folder_path / trx_name
                    if trx_path.exists():
                        try:
                            t_href = trx_path.resolve().as_uri()
                        except Exception:
                            t_href = str(trx_path).replace('\\', '/')
                        links_html.append(f'<a class="icon" href="{t_href}" title="Open TRX {trx_name}">{ICON_TRX}</a>')

                # link to original source/test file if available
                if fileloc:
                    try:
                        p = Path(fileloc)
                        if p.exists():
                            try:
                                p_href = p.resolve().as_uri()
                            except Exception:
                                p_href = str(p).replace('\\', '/')
                            links_html.append(f'<a class="icon" href="{p_href}" title="Open source/test file">{ICON_FILE}</a>')
                    except Exception:
                        pass

                links_cell = ' '.join(links_html) if links_html else '<span class="no-links">—</span>'

                row_cls = f'fail-row-{sev}'
                badge_html = f'<span class="badge {sev}">{sev.upper()}</span>'
                full_name = f.get('name') or ''
                display_name = f.get('_display_name') or full_name
                ttype = infer_test_type(full_name, group)

                # inline details inside the Description cell
                cleaned = clean_log(raw_msg)
                if cleaned:
                    snippet = (cleaned[:800] + '...') if len(cleaned) > 800 else cleaned
                    details_html = f'<details style="margin-top:6px"><summary class="small">Show details</summary><pre class="monospace">{html_escape(snippet)}</pre><div style="margin-top:6px"><small>File: {html_escape(fileloc)}</small></div></details>'
                else:
                    details_html = '<small class="small">No additional log output.</small>'

                # allow brief formatting in the inline summary cell and clamp lines via CSS
                brief = html_escape(trimmed).replace('\n','<br>')
                desc_cell = f"<div class=\"clamp\"><p>{brief}</p></div>{details_html}"

                body.append(f"<tr class=\"{row_cls}\" data-test-type=\"{ttype}\">"
                            f"<td class=\"testcase\" data-fullname=\"{html_escape(full_name)}\">"
                            f"<span class=\"display-name\">{html_escape(display_name)}</span>"
                            f"<div style=\"margin-top:6px\">{badge_html}</div>"
                            f"</td>"
                            f"<td class=\"outcome\">{html_escape(outcome)}</td>"
                            f"<td class=\"description\">{desc_cell}</td>"
                            f"<td class=\"links\">{links_cell}</td>"
                            f"</tr>")
            body.append('</tbody></table>')
        contents.append('<div id="tab-{id}" class="tab-content {act}">{content}</div>'.format(id=cat.replace(' ', '_'), act=('active' if len(contents)==0 else ''), content=''.join(body)))

    # assemble tabs
    parts.append('<div class="tabs">')
    parts.append('<div class="tab-buttons">' + '\n'.join(btns) + '</div>')
    parts.append('\n'.join(contents))
    # add tab switching script
    parts.append('''
<script>
  (function(){
    var buttons = document.querySelectorAll('.tab-buttons button');
    buttons.forEach(function(b){
      b.addEventListener('click', function(){
        buttons.forEach(x=>x.classList.remove('active'));
        b.classList.add('active');
        var tab = b.getAttribute('data-tab');
        document.querySelectorAll('.tab-content').forEach(function(c){
          c.classList.toggle('active', c.id===tab);
        });
      });
    });
  })();
</script>
''')

    return '\n'.join(parts)

    if not parts:
        return '<p>No failures detected.</p>'
    return '\n'.join(parts)


def sanitize_filename(name: str) -> str:
    # create a filesystem-safe folder name from test name
    out = ''.join(c if c.isalnum() or c in (' ', '.', '-', '_') else '_' for c in (name or ''))
    return out.replace(' ', '_')[:200]


def html_escape(s: str) -> str:
    return (s or '').replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--src', default='artifacts/summaries', help='Directory to search for tests-summary.json')
    p.add_argument('--out', default='final-report.html', help='Output HTML filename')
    p.add_argument('--name-segments', type=int, default=2, help='How many trailing dot-separated name segments to keep for display (1/2/3)')
    args = p.parse_args()

    src = Path(args.src)
    if not src.exists():
        # fallback to current workspace (use recursive search)
        src = Path('.')

    # apply CLI-configurable options
    global NAME_SEGMENTS
    NAME_SEGMENTS = int(args.name_segments or 2)

    summaries = load_summaries(src)
    env_map = find_env_checks(src)
    rows = build_rows(summaries, env_map)
    fail_section = build_failure_section(summaries)

    # aggregate totals for ribbon
    total_all = sum(v.get('total', 0) for v in summaries.values())
    passed_all = sum(v.get('passed', 0) for v in summaries.values())
    failed_all = sum(v.get('failed', 0) for v in summaries.values())
    pass_rate = f"{(passed_all / total_all * 100):.2f}%" if total_all else "N/A"

    # try to render from template if present
    tpl_path = Path('templates/report_template.html')
    css_path = Path('assets/report.css')
    if tpl_path.exists():
        tpl = tpl_path.read_text(encoding='utf-8')
        styles = css_path.read_text(encoding='utf-8') if css_path.exists() else ''
        out_html = tpl.replace('{{STYLES}}', styles)
        out_html = out_html.replace('{{UTC}}', datetime.utcnow().isoformat() + 'Z')
        out_html = out_html.replace('{{ROWS}}', rows)
        out_html = out_html.replace('{{FAIL_SECTION}}', fail_section)
        out_html = out_html.replace('{{TOTAL}}', str(total_all))
        out_html = out_html.replace('{{PASSED}}', str(passed_all))
        out_html = out_html.replace('{{FAILED}}', str(failed_all))
        out_html = out_html.replace('{{PASS_RATE}}', pass_rate)
        # replace source display placeholder with the resolved src path
        try:
            out_html = out_html.replace('{{SRC}}', str(src))
        except Exception:
            out_html = out_html.replace('{{SRC}}', '')
        Path(args.out).write_text(out_html, encoding='utf-8')
        print('WROTE', args.out)
        return

    # fallback to built-in template
    html = TEMPLATE.format(utc=datetime.utcnow().isoformat() + 'Z', rows=rows, fail_section=fail_section)
    Path(args.out).write_text(html, encoding='utf-8')
    print('WROTE', args.out)


if __name__ == '__main__':
    main()
