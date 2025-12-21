import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api, type InsertUsbLog } from "@shared/routes";
import { useToast } from "@/hooks/use-toast";

export function useUsbLogs() {
  return useQuery({
    queryKey: [api.logs.list.path],
    queryFn: async () => {
      const res = await fetch(api.logs.list.path, { credentials: "include" });
      if (!res.ok) throw new Error("Failed to fetch logs");
      return api.logs.list.responses[200].parse(await res.json());
    },
  });
}

export function useSimulateLog() {
  const queryClient = useQueryClient();
  const { toast } = useToast();

  return useMutation({
    mutationFn: async (data: InsertUsbLog) => {
      const validated = api.logs.create.input.parse(data);
      const res = await fetch(api.logs.create.path, {
        method: api.logs.create.method,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(validated),
        credentials: "include",
      });

      if (!res.ok) throw new Error("Failed to simulate event");
      return api.logs.create.responses[201].parse(await res.json());
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [api.logs.list.path] });
      toast({ title: "Event Simulated", description: "Check logs for details." });
    },
    onError: (err) => {
      toast({ title: "Simulation Failed", description: err.message, variant: "destructive" });
    },
  });
}

export function useClearLogs() {
  const queryClient = useQueryClient();
  const { toast } = useToast();

  return useMutation({
    mutationFn: async () => {
      const res = await fetch(api.logs.clear.path, { 
        method: api.logs.clear.method,
        credentials: "include" 
      });
      if (!res.ok) throw new Error("Failed to clear logs");
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [api.logs.list.path] });
      toast({ title: "Logs Cleared", description: "History has been reset." });
    },
    onError: (err) => {
      toast({ title: "Error", description: err.message, variant: "destructive" });
    },
  });
}
