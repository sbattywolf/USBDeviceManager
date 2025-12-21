import { useEffect, useState } from 'react';
import { AlertCircle, CheckCircle2, AlertTriangle, Copy, X } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from '@/components/ui/dialog';
import { useToast } from '@/hooks/use-toast';

interface HealthCheck {
  id: string;
  name: string;
  description: string;
  status: 'pass' | 'fail' | 'warning';
  details?: string;
  remediation?: string;
}

interface HealthCheckResponse {
  status: 'healthy' | 'degraded' | 'failed';
  timestamp: string;
  checks: HealthCheck[];
}

export function HealthCheckModal() {
  const [isOpen, setIsOpen] = useState(false);
  const [data, setData] = useState<HealthCheckResponse | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [errorDetails, setErrorDetails] = useState<string | null>(null);
  const { toast } = useToast();

  useEffect(() => {
    const runHealthCheck = async () => {
      try {
        const response = await fetch('/api/health');
        if (!response.ok) throw new Error('Health check failed');
        const result = await response.json();
        setData(result);
        
        // Show modal if there are issues
        if (result.status !== 'healthy') {
          setIsOpen(true);
        }
      } catch (err) {
        const errorMsg = err instanceof Error ? err.message : String(err);
        setErrorDetails(errorMsg);
        setIsOpen(true);
      } finally {
        setIsLoading(false);
      }
    };

    runHealthCheck();
  }, []);

  const handleCopyError = () => {
    if (errorDetails) {
      navigator.clipboard.writeText(errorDetails);
      toast({
        title: "Copied",
        description: "Error details copied to clipboard",
      });
    }
  };

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'pass':
        return <CheckCircle2 className="w-5 h-5 text-green-600" />;
      case 'fail':
        return <AlertCircle className="w-5 h-5 text-red-600" />;
      case 'warning':
        return <AlertTriangle className="w-5 h-5 text-amber-600" />;
      default:
        return null;
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'healthy':
        return 'text-green-700 bg-green-50 dark:bg-green-950 dark:text-green-200';
      case 'degraded':
        return 'text-amber-700 bg-amber-50 dark:bg-amber-950 dark:text-amber-200';
      case 'failed':
        return 'text-red-700 bg-red-50 dark:bg-red-950 dark:text-red-200';
      default:
        return '';
    }
  };

  if (errorDetails) {
    return (
      <Dialog open={isOpen} onOpenChange={setIsOpen}>
        <DialogContent className="max-w-lg">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2 text-red-600">
              <AlertCircle className="w-5 h-5" />
              Health Check Error
            </DialogTitle>
            <DialogDescription>
              An error occurred while checking system health. Please review the details below.
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-4">
            <div className="p-3 bg-red-50 dark:bg-red-950 rounded border border-red-200 dark:border-red-800">
              <p className="text-sm font-mono text-red-800 dark:text-red-200 break-words whitespace-pre-wrap">
                {errorDetails}
              </p>
            </div>

            <div className="p-3 bg-blue-50 dark:bg-blue-950 rounded border border-blue-200 dark:border-blue-800">
              <p className="text-sm text-blue-900 dark:text-blue-200 mb-2 font-semibold">
                Troubleshooting steps:
              </p>
              <ul className="text-sm text-blue-800 dark:text-blue-300 space-y-1 list-disc list-inside">
                <li>Verify the backend server is running (port 5000)</li>
                <li>Check your internet connection</li>
                <li>Try refreshing the page</li>
                <li>Check browser console for additional errors</li>
              </ul>
            </div>

            <div className="flex justify-between items-center">
              <Button
                onClick={handleCopyError}
                variant="outline"
                size="sm"
                className="gap-2"
                data-testid="button-copy-error"
              >
                <Copy className="w-4 h-4" />
                Copy Error Details
              </Button>
              <Button onClick={() => setIsOpen(false)} data-testid="button-close-error">
                Close
              </Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>
    );
  }

  if (!data) {
    return null;
  }

  const failedChecks = data.checks.filter(c => c.status === 'fail');
  const warningChecks = data.checks.filter(c => c.status === 'warning');

  return (
    <Dialog open={isOpen} onOpenChange={setIsOpen}>
      <DialogContent className="max-w-2xl max-h-[80vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <div className={`px-3 py-1 rounded-full text-sm font-semibold ${getStatusColor(data.status)}`}>
              {data.status === 'healthy' && 'System Healthy'}
              {data.status === 'degraded' && 'Degraded Status'}
              {data.status === 'failed' && 'Critical Issues'}
            </div>
          </DialogTitle>
          <DialogDescription>
            System health check completed at {new Date(data.timestamp).toLocaleTimeString()}
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-4">
          {/* Failed Checks */}
          {failedChecks.length > 0 && (
            <div className="space-y-2">
              <h3 className="font-semibold text-red-600 flex items-center gap-2">
                <AlertCircle className="w-4 h-4" />
                Critical Issues ({failedChecks.length})
              </h3>
              {failedChecks.map(check => (
                <div key={check.id} className="p-3 bg-red-50 dark:bg-red-950 rounded border border-red-200 dark:border-red-800 space-y-2">
                  <div className="flex items-start gap-2">
                    {getStatusIcon(check.status)}
                    <div className="flex-1">
                      <p className="font-semibold text-red-900 dark:text-red-100">{check.name}</p>
                      <p className="text-sm text-red-700 dark:text-red-300">{check.description}</p>
                    </div>
                  </div>
                  {check.details && (
                    <p className="text-sm text-red-800 dark:text-red-200 font-mono bg-red-100 dark:bg-red-900 p-2 rounded">
                      {check.details}
                    </p>
                  )}
                  {check.remediation && (
                    <div className="mt-2 p-2 bg-red-100 dark:bg-red-900 rounded">
                      <p className="text-sm font-semibold text-red-900 dark:text-red-100 mb-1">Fix:</p>
                      <p className="text-sm text-red-800 dark:text-red-200">{check.remediation}</p>
                    </div>
                  )}
                </div>
              ))}
            </div>
          )}

          {/* Warning Checks */}
          {warningChecks.length > 0 && (
            <div className="space-y-2">
              <h3 className="font-semibold text-amber-600 flex items-center gap-2">
                <AlertTriangle className="w-4 h-4" />
                Warnings ({warningChecks.length})
              </h3>
              {warningChecks.map(check => (
                <div key={check.id} className="p-3 bg-amber-50 dark:bg-amber-950 rounded border border-amber-200 dark:border-amber-800 space-y-2">
                  <div className="flex items-start gap-2">
                    {getStatusIcon(check.status)}
                    <div className="flex-1">
                      <p className="font-semibold text-amber-900 dark:text-amber-100">{check.name}</p>
                      <p className="text-sm text-amber-700 dark:text-amber-300">{check.description}</p>
                    </div>
                  </div>
                  {check.details && (
                    <p className="text-sm text-amber-800 dark:text-amber-200 font-mono bg-amber-100 dark:bg-amber-900 p-2 rounded">
                      {check.details}
                    </p>
                  )}
                  {check.remediation && (
                    <div className="mt-2 p-2 bg-amber-100 dark:bg-amber-900 rounded">
                      <p className="text-sm font-semibold text-amber-900 dark:text-amber-100 mb-1">Recommended:</p>
                      <p className="text-sm text-amber-800 dark:text-amber-200">{check.remediation}</p>
                    </div>
                  )}
                </div>
              ))}
            </div>
          )}

          {/* Passed Checks Summary */}
          {data.checks.filter(c => c.status === 'pass').length > 0 && (
            <details className="p-3 bg-green-50 dark:bg-green-950 rounded border border-green-200 dark:border-green-800">
              <summary className="cursor-pointer font-semibold text-green-600 dark:text-green-400 flex items-center gap-2">
                <CheckCircle2 className="w-4 h-4" />
                Passed Checks ({data.checks.filter(c => c.status === 'pass').length})
              </summary>
              <div className="mt-2 space-y-1 pl-6">
                {data.checks.filter(c => c.status === 'pass').map(check => (
                  <div key={check.id} className="text-sm text-green-700 dark:text-green-300">
                    {check.name}
                  </div>
                ))}
              </div>
            </details>
          )}
        </div>

        <div className="flex justify-end gap-2 mt-6">
          {data.status === 'healthy' && (
            <Button onClick={() => setIsOpen(false)} data-testid="button-dismiss-health">
              Continue
            </Button>
          )}
          {data.status !== 'healthy' && (
            <>
              <Button variant="outline" onClick={() => window.location.reload()} data-testid="button-retry-health">
                Retry Check
              </Button>
              <Button onClick={() => setIsOpen(false)} data-testid="button-dismiss-warnings">
                Continue Anyway
              </Button>
            </>
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
}
