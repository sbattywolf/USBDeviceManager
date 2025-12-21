import { Button } from "@/components/ui/button";
import { Zap } from "lucide-react";
import { useConfigStatus } from "@/hooks/use-config-status";
import { useStartSoftware } from "@/hooks/use-start-software";

export function StartButton({ configId }: { configId: number }) {
  const { data: status } = useConfigStatus(configId);
  const startSoftware = useStartSoftware();

  if (status?.isRunning) return null;

  return (
    <Button
      variant="outline"
      size="sm"
      onClick={() => startSoftware.mutate(configId)}
      disabled={startSoftware.isPending}
      className="border-green-300 text-green-700 hover:bg-green-50 dark:border-green-700 dark:text-green-400 dark:hover:bg-green-950"
      data-testid={`button-start-software-${configId}`}
    >
      <Zap className="w-3 h-3 mr-1" />
      Start
    </Button>
  );
}
