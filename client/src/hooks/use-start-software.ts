import { useMutation } from "@tanstack/react-query";
import { useToast } from "@/hooks/use-toast";

interface StartResponse {
  success: boolean;
  message: string;
  processName: string;
}

export function useStartSoftware() {
  const { toast } = useToast();

  return useMutation({
    mutationFn: async (configId: number): Promise<StartResponse> => {
      const response = await fetch(`/api/configs/start/${configId}`, {
        method: "POST",
      });
      if (!response.ok) throw new Error("Failed to start software");
      return response.json();
    },
    onSuccess: (data) => {
      toast({
        title: "Success",
        description: data.message,
      });
    },
    onError: (err) => {
      toast({
        title: "Error",
        description: err instanceof Error ? err.message : "Failed to start software",
        variant: "destructive",
      });
    },
  });
}
