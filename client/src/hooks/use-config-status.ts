import { useQuery } from "@tanstack/react-query";

interface ConfigStatus {
  id: number;
  isRunning: boolean;
  processName: string;
  details?: string;
}

export function useConfigStatus(configId: number) {
  return useQuery({
    queryKey: ["/api/configs/status", configId],
    queryFn: async () => {
      const response = await fetch(`/api/configs/status/${configId}`);
      if (!response.ok) throw new Error("Failed to fetch config status");
      return response.json() as Promise<ConfigStatus>;
    },
    refetchInterval: 5000, // Refetch every 5 seconds
  });
}
