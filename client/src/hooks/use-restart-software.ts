import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useToast } from "./use-toast";

interface RestartResponse {
  success: boolean;
  message: string;
  stopped?: number;
}

export function useRestartSoftware() {
  const { toast } = useToast();
  const qc = useQueryClient();

  return useMutation({
    mutationFn: async (configId: number): Promise<RestartResponse> => {
      const res = await fetch(`/api/configs/restart/${configId}`, { method: 'POST' });
      if (!res.ok) {
        const txt = await res.text().catch(() => '');
        throw new Error(txt || 'Failed to restart software');
      }
      return res.json();
    },
    onSuccess: (data, vars) => {
      toast({ title: data.success ? 'Restarted' : 'Restart Failed', description: data.message, variant: data.success ? undefined : 'destructive' });
      qc.invalidateQueries(["/api/configs/status", vars]);
    },
    onError: (err, vars) => {
      toast({ title: 'Error', description: err instanceof Error ? err.message : 'Failed to restart software', variant: 'destructive' });
      qc.invalidateQueries(["/api/configs/status", vars]);
    }
  });
}
