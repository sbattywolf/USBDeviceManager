import { useUsbConfigs, useCreateUsbConfig, useDeleteUsbConfig, useUpdateUsbConfig } from "@/hooks/use-usb-configs";
import { Plus, Trash2, Edit2, Play, Search, Power } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
  DialogFooter,
  DialogDescription,
} from "@/components/ui/dialog";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Label } from "@/components/ui/label";
import { Checkbox } from "@/components/ui/checkbox";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { insertUsbConfigSchema } from "@shared/schema";
import { type InsertUsbConfig } from "@shared/schema";
import { Badge } from "@/components/ui/badge";

export default function Configurations() {
  const { data: configs, isLoading } = useUsbConfigs();
  const deleteConfig = useDeleteUsbConfig();
  const updateConfig = useUpdateUsbConfig();
  const [searchTerm, setSearchTerm] = useState("");
  const [isCreateOpen, setIsCreateOpen] = useState(false);

  const filteredConfigs = configs?.filter(c => 
    c.friendlyName.toLowerCase().includes(searchTerm.toLowerCase()) || 
    c.deviceId.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const toggleStatus = (id: number, currentStatus: boolean) => {
    updateConfig.mutate({ id, isEnabled: !currentStatus });
  };

  if (isLoading) return <div className="p-10 text-center text-muted-foreground animate-pulse">Loading configurations...</div>;

  return (
    <div className="space-y-8">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-3xl font-display font-bold text-foreground">Configurations</h1>
          <p className="text-muted-foreground mt-2">Manage automated triggers for your USB devices.</p>
        </div>
        <Button onClick={() => setIsCreateOpen(true)} className="bg-primary hover:bg-primary/90 shadow-lg shadow-primary/25 rounded-xl px-6">
          <Plus className="w-5 h-5 mr-2" />
          Add Configuration
        </Button>
      </div>

      <div className="relative max-w-md">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
        <Input 
          placeholder="Search by name or device ID..." 
          className="pl-10 rounded-xl border-border bg-card shadow-sm"
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
        />
      </div>

      <div className="grid gap-4">
        <AnimatePresence>
          {filteredConfigs?.length === 0 ? (
            <motion.div 
              initial={{ opacity: 0 }} 
              animate={{ opacity: 1 }}
              className="p-12 text-center border border-dashed border-border rounded-2xl bg-card/50"
            >
              <div className="w-16 h-16 bg-muted/50 rounded-full flex items-center justify-center mx-auto mb-4">
                <Search className="w-8 h-8 text-muted-foreground" />
              </div>
              <h3 className="text-lg font-medium text-foreground">No configurations found</h3>
              <p className="text-muted-foreground mt-1">Try adjusting your search or add a new one.</p>
            </motion.div>
          ) : (
            filteredConfigs?.map((config, i) => (
              <motion.div
                key={config.id}
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: i * 0.05 }}
                className="group relative bg-card hover:bg-card/80 border border-border rounded-2xl p-6 shadow-sm hover:shadow-md transition-all duration-200"
              >
                <div className="flex items-start justify-between gap-4">
                  <div className="flex items-start gap-4">
                    <div className={`w-12 h-12 rounded-xl flex items-center justify-center transition-colors ${config.isEnabled ? 'bg-primary/10 text-primary' : 'bg-muted text-muted-foreground'}`}>
                      <Play className="w-6 h-6" />
                    </div>
                    <div>
                      <div className="flex items-center gap-3">
                        <h3 className="font-bold text-lg text-foreground">{config.friendlyName}</h3>
                        <Badge variant={config.isEnabled ? "default" : "secondary"} className={config.isEnabled ? "bg-emerald-100 text-emerald-800 hover:bg-emerald-200" : ""}>
                          {config.isEnabled ? 'Active' : 'Disabled'}
                        </Badge>
                      </div>
                      <code className="text-xs bg-muted/50 px-1.5 py-0.5 rounded text-muted-foreground mt-1 block w-fit">
                        {config.deviceId}
                      </code>
                      <div className="mt-3 text-sm text-muted-foreground flex items-center gap-2">
                        <span className="font-medium text-foreground">Triggers:</span> 
                        <span className="truncate max-w-md bg-muted/30 px-2 py-0.5 rounded border border-border/50 font-mono text-xs">
                          {config.triggerPath} {config.triggerParams}
                        </span>
                      </div>
                    </div>
                  </div>

                  <div className="flex items-center gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                    <Button 
                      size="icon" 
                      variant="ghost" 
                      className={config.isEnabled ? "text-amber-600 hover:text-amber-700 hover:bg-amber-50" : "text-emerald-600 hover:text-emerald-700 hover:bg-emerald-50"}
                      onClick={() => toggleStatus(config.id, config.isEnabled)}
                      title={config.isEnabled ? "Disable" : "Enable"}
                    >
                      <Power className="w-4 h-4" />
                    </Button>
                    <Button 
                      size="icon" 
                      variant="ghost" 
                      className="text-destructive hover:text-destructive hover:bg-destructive/10"
                      onClick={() => {
                        if (confirm('Are you sure you want to delete this config?')) {
                          deleteConfig.mutate(config.id);
                        }
                      }}
                    >
                      <Trash2 className="w-4 h-4" />
                    </Button>
                  </div>
                </div>
                
                <div className="mt-4 flex gap-2 text-xs text-muted-foreground">
                  {config.runSilently && (
                    <span className="flex items-center gap-1 bg-muted/30 px-2 py-1 rounded">Run Silently</span>
                  )}
                  {config.forceMinimize && (
                    <span className="flex items-center gap-1 bg-muted/30 px-2 py-1 rounded">Minimize Window</span>
                  )}
                  {config.port && (
                    <span className="flex items-center gap-1 bg-muted/30 px-2 py-1 rounded">Port: {config.port}</span>
                  )}
                </div>
              </motion.div>
            ))
          )}
        </AnimatePresence>
      </div>

      <CreateConfigDialog open={isCreateOpen} onOpenChange={setIsCreateOpen} />
    </div>
  );
}

function CreateConfigDialog({ open, onOpenChange }: { open: boolean; onOpenChange: (open: boolean) => void }) {
  const createMutation = useCreateUsbConfig();
  const form = useForm<InsertUsbConfig>({
    resolver: zodResolver(insertUsbConfigSchema),
    defaultValues: {
      friendlyName: "",
      deviceId: "",
      triggerPath: "",
      triggerParams: "",
      isEnabled: true,
      runSilently: false,
      forceMinimize: false,
      port: ""
    }
  });

  const onSubmit = (data: InsertUsbConfig) => {
    createMutation.mutate(data, {
      onSuccess: () => {
        onOpenChange(false);
        form.reset();
      }
    });
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-xl">
        <DialogHeader>
          <DialogTitle className="font-display text-2xl">Add Configuration</DialogTitle>
          <DialogDescription>Define what happens when a specific USB device is connected.</DialogDescription>
        </DialogHeader>

        <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6 py-4">
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label htmlFor="friendlyName">Friendly Name</Label>
              <Input id="friendlyName" {...form.register("friendlyName")} placeholder="e.g. My Backup Drive" />
              {form.formState.errors.friendlyName && <p className="text-xs text-destructive">{form.formState.errors.friendlyName.message}</p>}
            </div>
            <div className="space-y-2">
              <Label htmlFor="deviceId">Device ID (VID:PID)</Label>
              <Input id="deviceId" {...form.register("deviceId")} placeholder="e.g. 1234:5678" className="font-mono" />
              {form.formState.errors.deviceId && <p className="text-xs text-destructive">{form.formState.errors.deviceId.message}</p>}
            </div>
          </div>

          <div className="space-y-2">
            <Label htmlFor="triggerPath">Application Path</Label>
            <Input id="triggerPath" {...form.register("triggerPath")} placeholder="C:\Windows\System32\notepad.exe" className="font-mono" />
            {form.formState.errors.triggerPath && <p className="text-xs text-destructive">{form.formState.errors.triggerPath.message}</p>}
          </div>

          <div className="grid grid-cols-2 gap-4">
             <div className="space-y-2">
              <Label htmlFor="triggerParams">Parameters (Optional)</Label>
              <Input id="triggerParams" {...form.register("triggerParams")} placeholder="--minimized --silent" className="font-mono" />
            </div>
             <div className="space-y-2">
              <Label htmlFor="port">Port Binding (Optional)</Label>
              <Input id="port" {...form.register("port")} placeholder="COM3" className="font-mono" />
            </div>
          </div>

          <div className="flex gap-6 p-4 bg-muted/30 rounded-xl border border-border/50">
            <div className="flex items-center space-x-2">
              <Checkbox id="runSilently" checked={form.watch("runSilently")} onCheckedChange={(c) => form.setValue("runSilently", c as boolean)} />
              <Label htmlFor="runSilently" className="font-medium cursor-pointer">Run Silently</Label>
            </div>
            <div className="flex items-center space-x-2">
              <Checkbox id="forceMinimize" checked={form.watch("forceMinimize")} onCheckedChange={(c) => form.setValue("forceMinimize", c as boolean)} />
              <Label htmlFor="forceMinimize" className="font-medium cursor-pointer">Force Minimize</Label>
            </div>
          </div>

          <DialogFooter>
            <Button type="button" variant="ghost" onClick={() => onOpenChange(false)}>Cancel</Button>
            <Button type="submit" disabled={createMutation.isPending} className="bg-primary hover:bg-primary/90">
              {createMutation.isPending ? "Creating..." : "Create Configuration"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
