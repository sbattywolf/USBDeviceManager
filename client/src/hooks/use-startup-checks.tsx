import { useEffect, useState } from 'react';

export type HealthCheckItem = {
  id: string;
  name: string;
  description: string;
  status: 'pass' | 'fail' | 'warning';
  details?: string;
  remediation?: string;
};

export type HealthCheckResponse = {
  status: 'healthy' | 'degraded' | 'failed';
  timestamp: string;
  checks: HealthCheckItem[];
};

export function useStartupChecks() {
  const [result, setResult] = useState<HealthCheckResponse | null>(null);
  const [loading, setLoading] = useState(false);

  const run = async () => {
    setLoading(true);
    try {
      const res = await fetch('/api/health');
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const json = await res.json();
      setResult(json as HealthCheckResponse);
    } catch (e: any) {
      setResult({ status: 'failed', timestamp: new Date().toISOString(), checks: [{ id: 'network', name: 'Health Endpoint', description: 'Could not reach health endpoint', status: 'fail', details: String(e), remediation: 'Ensure server is running and reachable' }] });
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    // run once on mount
    void run();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return { result, loading, run };
}

export default useStartupChecks;
