import { useUsbConfigs } from "@/hooks/use-usb-configs";
import { useUsbLogs, useSimulateLog } from "@/hooks/use-usb-logs";
import { useConfigStatus } from "@/hooks/use-config-status";
import { useStartSoftware } from "@/hooks/use-start-software";
import { MetricCard } from "@/components/MetricCard";
import { AlertCircle, Usb, Activity, Server, ArrowRight, Play, Zap } from "lucide-react";
import { motion } from "framer-motion";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useState, useMemo } from "react";
import { format } from "date-fns";
import { useToast } from "@/hooks/use-toast";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Link } from "wouter";

export default function Dashboard() {
  const { data: configs } = useUsbConfigs();
  const { data: logs } = useUsbLogs();
  const simulate = useSimulateLog();
  const startSoftware = useStartSoftware();
  const { toast } = useToast();
  
  const [simDeviceId, setSimDeviceId] = useState("USB\\VID_1234&PID_5678");

  const totalConfigs = configs?.length || 0;
  const recentEvents = logs?.length || 0;
  const activeConfigs = configs?.filter(c => c.isEnabled).length || 0;

  // Count devices that are connected from logs
  const connectedDevices = logs
    ? new Set(logs.filter(l => l.eventType === 'CONNECTED').map(l => l.deviceId)).size
    : 0;

  // Calculate software status: how many should be running based on detected USB + enabled config
  const softwareShouldRun = useMemo(() => {
    if (!configs || !logs) return 0;
    
    const connectedDeviceIds = new Set(
      logs.filter(l => l.eventType === 'CONNECTED').map(l => l.deviceId)
    );

    return configs.filter(config => {
      const isEnabled = config.isEnabled;
      const isConnected = Array.from(connectedDeviceIds).some(deviceId =>
        config.deviceId.includes(deviceId) || deviceId.includes(config.deviceId)
      );
      return isEnabled && isConnected;
    }).length;
  }, [configs, logs]);

  const handleSimulate = (eventType: "CONNECTED" | "DISCONNECTED") => {
    simulate.mutate({
      deviceId: simDeviceId,
      eventType: eventType,
      actionTaken: "SIMULATION_PENDING",
      details: "Manual simulation triggered from dashboard",
      friendlyName: "Simulated Device"
    });
  };

  const handleStartAll = async () => {
    if (!configs || !logs) return;

    const connectedDeviceIds = new Set(
      logs.filter(l => l.eventType === 'CONNECTED').map(l => l.deviceId)
    );

    const configsToStart = configs.filter(config => {
      const isEnabled = config.isEnabled;
      const isConnected = Array.from(connectedDeviceIds).some(deviceId =>
        config.deviceId.includes(deviceId) || deviceId.includes(config.deviceId)
      );
      return isEnabled && isConnected;
    });

    if (configsToStart.length === 0) {
      toast({
        title: "No software to start",
        description: "No enabled configurations found for connected USB devices.",
      });
      return;
    }

    // Start all applicable software
    let successCount = 0;
    for (const config of configsToStart) {
      const result = await new Promise((resolve) => {
        startSoftware.mutate(config.id, {
          onSuccess: () => resolve(true),
          onError: () => resolve(false),
        });
      });
      if (result) successCount++;
    }

    toast({
      title: "Operation complete",
      description: `Started ${successCount}/${configsToStart.length} software instances.`,
    });
  };

  const recentLogs = logs?.slice(0, 5) || [];

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-display font-bold text-foreground">Overview</h1>
        <p className="text-muted-foreground mt-2">System status and recent activity summary.</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-6">
        <MetricCard 
          title="Total Configured Devices" 
          value={totalConfigs} 
          icon={Usb} 
          trend="+2 new"
          trendUp={true}
        />
        <MetricCard 
          title="Active Monitors" 
          value={activeConfigs} 
          icon={Server} 
        />
        <MetricCard 
          title="Connected USB Devices" 
          value={connectedDevices} 
          icon={Zap}
          trend="Currently detected"
        />
        <MetricCard 
          title="Software Should Run" 
          value={softwareShouldRun} 
          icon={AlertCircle}
          trend="USB detected & enabled"
        />
        <MetricCard 
          title="Recent Events" 
          value={recentEvents} 
          icon={Activity} 
          trend="Last 24h"
          trendUp={true}
        />
      </div>

      {/* Start All Software Button */}
      {softwareShouldRun > 0 && (
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.4 }}
          className="bg-gradient-to-r from-blue-50 to-cyan-50 dark:from-blue-950/30 dark:to-cyan-950/30 border border-blue-200 dark:border-blue-800 rounded-2xl p-6 flex items-center justify-between"
        >
          <div>
            <h3 className="font-bold text-lg text-foreground mb-1">Software Ready to Launch</h3>
            <p className="text-sm text-muted-foreground">
              {softwareShouldRun} software instance{softwareShouldRun !== 1 ? 's' : ''} are configured for detected USB device{connectedDevices !== 1 ? 's' : ''}. Start them now?
            </p>
          </div>
          <Button 
            onClick={handleStartAll} 
            disabled={startSoftware.isPending}
            className="bg-blue-600 hover:bg-blue-700 text-white shadow-lg shadow-blue-600/20 whitespace-nowrap gap-2"
          >
            <Play className="w-4 h-4" />
            {startSoftware.isPending ? "Starting..." : "Start All"}
          </Button>
        </motion.div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        {/* Main Content: Recent Activity */}
        <motion.div 
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.4 }}
          className="lg:col-span-2 bg-card rounded-2xl border border-border shadow-sm p-6"
        >
          <div className="flex items-center justify-between mb-6">
            <h3 className="text-lg font-bold font-display">Recent Activity</h3>
            <Link href="/logs" className="text-sm font-medium text-primary hover:text-primary/80 flex items-center gap-1 transition-colors">
              View all <ArrowRight className="w-4 h-4" />
            </Link>
          </div>

          <div className="rounded-xl border border-border overflow-hidden">
            <Table>
              <TableHeader className="bg-muted/30">
                <TableRow>
                  <TableHead>Time</TableHead>
                  <TableHead>Event</TableHead>
                  <TableHead>Device</TableHead>
                  <TableHead>Action</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {recentLogs.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={4} className="h-24 text-center text-muted-foreground">
                      No recent logs found.
                    </TableCell>
                  </TableRow>
                ) : (
                  recentLogs.map((log) => (
                    <TableRow key={log.id} className="group hover:bg-muted/20 transition-colors">
                      <TableCell className="text-muted-foreground text-xs font-mono">
                        {log.timestamp ? format(new Date(log.timestamp), "MMM dd HH:mm:ss") : "-"}
                      </TableCell>
                      <TableCell>
                        <span className={`inline-flex items-center px-2 py-1 rounded-md text-xs font-semibold ${
                          log.eventType === 'CONNECTED' 
                            ? 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-400' 
                            : 'bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400'
                        }`}>
                          {log.eventType}
                        </span>
                      </TableCell>
                      <TableCell className="font-medium text-foreground">
                        {log.friendlyName || log.deviceId}
                      </TableCell>
                      <TableCell className="text-muted-foreground text-sm max-w-[200px] truncate">
                        {log.actionTaken}
                      </TableCell>
                    </TableRow>
                  ))
                )}
              </TableBody>
            </Table>
          </div>
        </motion.div>

        {/* Sidebar Widget: Simulation */}
        <motion.div 
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.4, delay: 0.1 }}
          className="bg-gradient-to-br from-card to-muted/20 rounded-2xl border border-border shadow-sm p-6 flex flex-col h-full"
        >
          <div className="mb-6">
            <div className="w-12 h-12 bg-primary/10 rounded-xl flex items-center justify-center mb-4">
              <Activity className="w-6 h-6 text-primary" />
            </div>
            <h3 className="text-lg font-bold font-display">Test Simulation</h3>
            <p className="text-sm text-muted-foreground mt-2">
              Manually trigger a USB event to test your configuration triggers without physical hardware.
            </p>
          </div>

          <div className="space-y-4 mt-auto">
            <div className="space-y-2">
              <label className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">Device ID</label>
              <Input 
                value={simDeviceId} 
                onChange={(e) => setSimDeviceId(e.target.value)} 
                className="bg-background border-2 focus:border-primary font-mono text-sm"
              />
            </div>
            
            <div className="grid grid-cols-2 gap-3 pt-2">
              <Button 
                onClick={() => handleSimulate('CONNECTED')}
                disabled={simulate.isPending}
                className="w-full bg-emerald-600 hover:bg-emerald-700 text-white shadow-lg shadow-emerald-600/20"
              >
                Connect
              </Button>
              <Button 
                onClick={() => handleSimulate('DISCONNECTED')}
                disabled={simulate.isPending}
                variant="outline"
                className="w-full border-rose-200 text-rose-700 hover:bg-rose-50 hover:text-rose-800 dark:border-rose-900 dark:text-rose-400 dark:hover:bg-rose-950"
              >
                Disconnect
              </Button>
            </div>
          </div>
        </motion.div>
      </div>
    </div>
  );
}
