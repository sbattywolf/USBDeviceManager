import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useToast } from "./use-toast";

interface StopResponse {
  success: boolean;
  message: string;
  stopped?: number;
}

export function useStopSoftware() {
  const { toast } = useToast();
  const qc = useQueryClient();

  return useMutation({
    mutationFn: async (configId: number): Promise<StopResponse> => {
      const res = await fetch(`/api/configs/stop/${configId}`, { method: 'POST' });
      if (!res.ok) {
        const txt = await res.text().catch(() => '');
        throw new Error(txt || 'Failed to stop software');
      }
      return res.json();
    },
    onSuccess: (data, vars) => {
      toast({ title: data.success ? 'Stopped' : 'Stop Failed', description: data.message, variant: data.success ? undefined : 'destructive' });
      qc.invalidateQueries(["/api/configs/status", vars]);
    },
    onError: (err, vars) => {
      toast({ title: 'Error', description: err instanceof Error ? err.message : 'Failed to stop software', variant: 'destructive' });
      qc.invalidateQueries(["/api/configs/status", vars]);
    }
  });
}
