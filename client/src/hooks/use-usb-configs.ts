import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api, buildUrl, type CreateConfigParams, type UpdateConfigParams } from "@shared/routes";
import { useToast } from "@/hooks/use-toast";

export function useUsbConfigs() {
  return useQuery({
    queryKey: [api.configs.list.path],
    queryFn: async () => {
      const res = await fetch(api.configs.list.path, { credentials: "include" });
      if (!res.ok) throw new Error("Failed to fetch configs");
      return api.configs.list.responses[200].parse(await res.json());
    },
  });
}

export function useCreateUsbConfig() {
  const queryClient = useQueryClient();
  const { toast } = useToast();

  return useMutation({
    mutationFn: async (data: CreateConfigParams) => {
      // Validate with schema first if needed, though form handles validation mostly
      const validated = api.configs.create.input.parse(data);
      const res = await fetch(api.configs.create.path, {
        method: api.configs.create.method,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(validated),
        credentials: "include",
      });

      if (!res.ok) {
        if (res.status === 400) {
          const error = api.configs.create.responses[400].parse(await res.json());
          throw new Error(error.message);
        }
        throw new Error("Failed to create configuration");
      }
      return api.configs.create.responses[201].parse(await res.json());
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [api.configs.list.path] });
      toast({ title: "Success", description: "USB Configuration created successfully" });
    },
    onError: (err) => {
      toast({ title: "Error", description: err.message, variant: "destructive" });
    },
  });
}

export function useUpdateUsbConfig() {
  const queryClient = useQueryClient();
  const { toast } = useToast();

  return useMutation({
    mutationFn: async ({ id, ...updates }: { id: number } & UpdateConfigParams) => {
      const validated = api.configs.update.input.parse(updates);
      const url = buildUrl(api.configs.update.path, { id });
      
      const res = await fetch(url, {
        method: api.configs.update.method,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(validated),
        credentials: "include",
      });

      if (!res.ok) {
        if (res.status === 404) throw new Error("Config not found");
        throw new Error("Failed to update configuration");
      }
      return api.configs.update.responses[200].parse(await res.json());
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [api.configs.list.path] });
      toast({ title: "Success", description: "Configuration updated" });
    },
    onError: (err) => {
      toast({ title: "Error", description: err.message, variant: "destructive" });
    },
  });
}

export function useDeleteUsbConfig() {
  const queryClient = useQueryClient();
  const { toast } = useToast();

  return useMutation({
    mutationFn: async (id: number) => {
      const url = buildUrl(api.configs.delete.path, { id });
      const res = await fetch(url, { 
        method: api.configs.delete.method, 
        credentials: "include" 
      });
      
      if (!res.ok) throw new Error("Failed to delete configuration");
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [api.configs.list.path] });
      toast({ title: "Deleted", description: "Configuration removed successfully" });
    },
    onError: (err) => {
      toast({ title: "Error", description: err.message, variant: "destructive" });
    },
  });
}
