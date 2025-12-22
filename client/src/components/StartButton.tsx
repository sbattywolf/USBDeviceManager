import { Button } from "@/components/ui/button";
import { Zap, RotateCw, StopCircle } from "lucide-react";
import { useConfigStatus } from "@/hooks/use-config-status";
import { useStartSoftware } from "@/hooks/use-start-software";
import { useStopSoftware } from "@/hooks/use-stop-software";
import { useRestartSoftware } from "@/hooks/use-restart-software";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
  DialogClose,
  DialogTrigger,
} from "@/components/ui/dialog";
import { useState } from "react";

export function StartButton({ configId, friendlyName }: { configId: number; friendlyName?: string }) {
  const { data: status, isLoading: statusLoading } = useConfigStatus(configId);
  const startSoftware = useStartSoftware();
  const stopSoftware = useStopSoftware();
  const restartSoftware = useRestartSoftware();

  // Show start when not running
  if (!statusLoading && !status?.isRunning) {
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

  // When running, show Stop and Restart buttons with confirmation dialogs
  const [stopOpen, setStopOpen] = useState(false);
  const [restartOpen, setRestartOpen] = useState(false);

  return (
    <div className="flex items-center gap-2">
      <Dialog open={stopOpen} onOpenChange={setStopOpen}>
        <DialogTrigger asChild>
          <Button
            variant="outline"
            size="sm"
            onClick={() => setStopOpen(true)}
            disabled={stopSoftware.isPending}
            className="border-red-300 text-red-700 hover:bg-red-50 dark:border-red-700 dark:text-red-400 dark:hover:bg-red-950"
            data-testid={`button-stop-software-${configId}`}
          >
            <StopCircle className="w-3 h-3 mr-1" />
            Stop
          </Button>
        </DialogTrigger>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Confirm Stop</DialogTitle>
            <DialogDescription>
              Are you sure you want to stop the configured software for
              {friendlyName ? ` "${friendlyName}"` : ' this device'}?
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="ghost" onClick={() => setStopOpen(false)}>Cancel</Button>
            <Button
              variant="destructive"
              onClick={() => {
                stopSoftware.mutate(configId);
                setStopOpen(false);
              }}
              data-testid={`confirm-stop-${configId}`}
            >
              Stop
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={restartOpen} onOpenChange={setRestartOpen}>
        <DialogTrigger asChild>
          <Button
            variant="outline"
            size="sm"
            onClick={() => setRestartOpen(true)}
            disabled={restartSoftware.isPending}
            className="border-amber-300 text-amber-700 hover:bg-amber-50 dark:border-amber-700 dark:text-amber-400 dark:hover:bg-amber-950"
            data-testid={`button-restart-software-${configId}`}
          >
            <RotateCw className="w-3 h-3 mr-1" />
            Restart
          </Button>
        </DialogTrigger>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Confirm Restart</DialogTitle>
            <DialogDescription>
              This will stop the process (if running) and start it again for
              {friendlyName ? ` "${friendlyName}"` : ' this device'}. Continue?
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="ghost" onClick={() => setRestartOpen(false)}>Cancel</Button>
            <Button
              variant="default"
              onClick={() => {
                restartSoftware.mutate(configId);
                setRestartOpen(false);
              }}
              data-testid={`confirm-restart-${configId}`}
            >
              Restart
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
