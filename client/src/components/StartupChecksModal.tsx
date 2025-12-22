import React, { useState } from 'react';
import useStartupChecks from '@/hooks/use-startup-checks';
import { Button } from '@/components/ui/button';
import { useState as useState2 } from 'react';

export function StartupChecksModal() {
  const { result, loading, run } = useStartupChecks();
  const [visible, setVisible] = useState(true);

  if (!visible) return null;

  const errors = result?.checks.filter(c => c.status === 'fail') || [];
  const warnings = result?.checks.filter(c => c.status === 'warning') || [];

  const copyDetails = () => {
    const payload = JSON.stringify({ result }, null, 2);
    navigator.clipboard?.writeText(payload);
  };

  const [showFixes, setShowFixes] = useState2(false);
  const [fixCmd, setFixCmd] = useState2<string | null>(null);
  const [fetchingFix, setFetchingFix] = useState2(false);

  const openDoc = (path: string) => {
    try { window.open(path, '_blank'); } catch {}
  };

  const fetchFix = async (id: string) => {
    setFetchingFix(true);
    try {
      const res = await fetch('/api/remediation', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ id }) });
      if (!res.ok) throw new Error(String(res.status));
      const json = await res.json();
      // Show all platform commands
      setFixCmd(json);
    } catch (e: any) {
      setFixCmd({ error: String(e) });
    } finally {
      setFetchingFix(false);
      setShowFixes(true);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-start justify-center p-6">
      <div className="w-full max-w-3xl bg-white dark:bg-slate-900 rounded-xl shadow-lg border border-border p-6">
        <div className="flex items-start justify-between">
          <div>
            <h3 className="text-lg font-bold">Startup Diagnostics</h3>
            <p className="text-sm text-muted-foreground mt-1">Checks required for correct operation. Resolve failing items before proceeding.</p>
          </div>
          <div className="flex gap-2">
            <Button variant="ghost" onClick={() => run()} disabled={loading}>{loading ? 'Running...' : 'Re-run checks'}</Button>
            <Button variant="outline" onClick={copyDetails}>Copy Details</Button>
            <Button onClick={() => setVisible(false)}>Dismiss</Button>
          </div>
        </div>

        <div className="mt-4 space-y-3">
          {result?.checks.map((c) => (
            <div key={c.id} className={`p-3 rounded-md border ${c.status === 'fail' ? 'border-red-200 bg-red-50' : c.status === 'warning' ? 'border-amber-200 bg-amber-50' : 'border-emerald-200 bg-emerald-50'}`}>
              <div className="flex items-center justify-between">
                <div>
                  <div className="font-semibold">{c.name} <span className="text-xs text-muted-foreground">({c.id})</span></div>
                  <div className="text-sm text-muted-foreground">{c.description}</div>
                </div>
                <div className="text-right">
                  <div className="text-sm font-semibold">{c.status.toUpperCase()}</div>
                  {c.remediation && <div className="text-xs text-muted-foreground mt-1">{c.remediation}</div>}
                </div>
              </div>
              {c.details && <pre className="mt-2 text-xs bg-black/5 p-2 rounded text-xs overflow-auto">{c.details}</pre>}
            </div>
          ))}
        </div>
        <div className="mt-4 flex items-center gap-2">
          <Button variant="ghost" onClick={() => openDoc('/BUILD_WINDOWS.md')}>Open Build Instructions</Button>
          <Button variant="ghost" onClick={() => openDoc('/README.md')}>Open README</Button>
          <Button variant="outline" onClick={() => fetchFix('install_python')} disabled={fetchingFix}>{fetchingFix ? '...' : 'Get Fix Commands'}</Button>
        </div>

        {showFixes && fixCmd && (
          <div className="mt-4 p-3 border border-border rounded bg-surface">
            <h4 className="font-semibold mb-2">Remediation Commands</h4>
            {fixCmd.error ? (
              <div className="text-red-600">{fixCmd.error}</div>
            ) : (
              <>
                <div className="mb-2 text-sm">{fixCmd.description}</div>
                <div className="space-y-2">
                  {Object.entries(fixCmd.commands || {}).map(([platform, cmd]) => (
                    <div key={platform} className="flex items-center gap-2">
                      <span className="font-mono text-xs bg-black/5 px-2 py-1 rounded">{platform}</span>
                      <pre className="inline-block m-0 p-2 bg-black/5 rounded text-xs overflow-auto">{cmd}</pre>
                      <Button size="sm" variant="outline" onClick={() => navigator.clipboard?.writeText(cmd as string)}>Copy</Button>
                    </div>
                  ))}
                </div>
              </>
            )}
          </div>
        )}
      </div>
    </div>
  );
}

export default StartupChecksModal;
