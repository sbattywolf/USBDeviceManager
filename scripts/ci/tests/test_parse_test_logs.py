import os
import json
import tempfile
from scripts.ci.parse_test_logs import parse_trx, parse_console_log

TRX_SAMPLE = '''<?xml version="1.0" encoding="utf-8"?>
<TestRun>
  <ResultSummary>
    <Counters total="3" executed="3" passed="2" failed="0" error="0" timeout="0" aborted="0" inconclusive="0" passedButRunAborted="0" notRunnable="0" notExecuted="1" disconnected="0" warning="0" completed="0" inProgress="0" pending="0" />
  </ResultSummary>
  <Results>
    <UnitTestResult outcome="Passed" testName="TestA" />
    <UnitTestResult outcome="Passed" testName="TestB" />
    <UnitTestResult outcome="Skipped" testName="TestC" />
  </Results>
</TestRun>
'''

def test_parse_trx_and_console():
    with tempfile.TemporaryDirectory() as td:
        trx_path = os.path.join(td, 'sample.trx')
        with open(trx_path, 'w', encoding='utf-8') as f:
            f.write(TRX_SAMPLE)

        trx_info = parse_trx(trx_path)
        assert trx_info['counters'].get('total') == 3 or trx_info['counters'].get('total') == '3'
        assert 'TestC' in trx_info.get('skipped', [])

        log_path = os.path.join(td, 'console.log')
        with open(log_path, 'w', encoding='utf-8') as lf:
            lf.write('INFO starting tests\nException: Something went wrong\n')

        errs = parse_console_log(log_path)
        assert any('Exception' in e['text'] for e in errs)
