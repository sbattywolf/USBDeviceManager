import { useUsbConfigs } from "@/hooks/use-usb-configs";
import { useUsbLogs } from "@/hooks/use-usb-logs";
import { useState } from "react";
import { format } from "date-fns";
import { Button } from "@/components/ui/button";
import { Link } from "wouter";
import { AlertCircle, CheckCircle2, Plus } from "lucide-react";
import useUsbStream from "@/hooks/use-usb-stream";
import { StartButton } from "@/components/StartButton";
import { motion } from "framer-motion";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";

export default function Devices() {
  const { data: configs } = useUsbConfigs();
  const { data: logs } = useUsbLogs();
  const [showUnconfiguredOnly, setShowUnconfiguredOnly] = useState(true);

  // Get all unique device IDs from logs
  // Get live detected devices from USB stream (falls back to logs)
  const { devices: usbDevices } = useUsbStream({ usbInterval: 10000 });

  const detectedDevices = usbDevices && usbDevices.length
    ? usbDevices.map((d) => ({ deviceId: d.InstanceId || '', friendlyName: d.FriendlyName || '' }))
    : (logs
      ? Array.from(
          new Map(
            logs.map((log) => [
              log.deviceId,
              { deviceId: log.deviceId, friendlyName: log.friendlyName },
            ])
          ).values()
        )
      : []);

  // Find unconfigured devices (detected but not in configs)
  const unconfiguredDevices = detectedDevices.filter(
    (detected) =>
      !configs?.some((config) =>
        config.deviceId.includes(detected.deviceId) ||
        detected.deviceId.includes(config.deviceId)
      )
  );

  // Determine which unconfigured devices to show
  const visibleUnconfigured = showUnconfiguredOnly
    ? unconfiguredDevices
    : detectedDevices;

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-display font-bold text-foreground">
          USB Devices
        </h1>
        <p className="text-muted-foreground mt-2">
          Manage configured devices and discover new USB connections.
        </p>
      </div>

      {/* Device Summary Stats */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.3 }}
          className="bg-card rounded-xl border border-border p-4 shadow-sm"
        >
          <div className="flex items-start justify-between">
            <div>
              <p className="text-sm text-muted-foreground mb-2">
                Configured Devices
              </p>
              <p className="text-3xl font-bold text-foreground">
                {configs?.length || 0}
              </p>
            </div>
            <CheckCircle2 className="w-8 h-8 text-green-600 opacity-20" />
          </div>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.3, delay: 0.1 }}
          className="bg-card rounded-xl border border-border p-4 shadow-sm"
        >
          <div className="flex items-start justify-between">
            <div>
              <p className="text-sm text-muted-foreground mb-2">
                Unconfigured Devices
              </p>
              <p className="text-3xl font-bold text-amber-600">
                {unconfiguredDevices.length}
              </p>
            </div>
            <AlertCircle className="w-8 h-8 text-amber-600 opacity-20" />
          </div>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.3, delay: 0.2 }}
          className="bg-card rounded-xl border border-border p-4 shadow-sm"
        >
          <div className="flex items-start justify-between">
            <div>
              <p className="text-sm text-muted-foreground mb-2">
                Total Events Logged
              </p>
              <p className="text-3xl font-bold text-foreground">
                {logs?.length || 0}
              </p>
            </div>
          </div>
        </motion.div>
      </div>

      {/* Configured Devices Table */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4 }}
        className="bg-card rounded-xl border border-border shadow-sm overflow-hidden"
      >
        <div className="p-6 border-b border-border/50 flex items-center justify-between">
          <div>
            <h2 className="text-lg font-bold font-display text-foreground">
              Configured Devices
            </h2>
            <p className="text-sm text-muted-foreground mt-1">
              USB devices ready for monitoring and software triggers.
            </p>
          </div>
          <Link href="/configs">
            <Button
              variant="default"
              className="gap-2"
              data-testid="button-add-device"
            >
              <Plus className="w-4 h-4" />
              Add Device
            </Button>
          </Link>
        </div>

        <div className="overflow-x-auto">
          <Table>
            <TableHeader className="bg-muted/30">
              <TableRow>
                <TableHead>Device Name</TableHead>
                <TableHead>Device ID</TableHead>
                <TableHead>Port</TableHead>
                <TableHead>Trigger Software</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {!configs || configs.length === 0 ? (
                <TableRow>
                  <TableCell
                    colSpan={6}
                    className="h-24 text-center text-muted-foreground"
                  >
                    No configured devices. Create your first configuration.
                  </TableCell>
                </TableRow>
              ) : (
                configs.map((config) => (
                  <TableRow
                    key={config.id}
                    className="group hover:bg-muted/20 transition-colors"
                  >
                    <TableCell className="font-medium text-foreground">
                      {config.friendlyName}
                    </TableCell>
                    <TableCell className="font-mono text-sm text-muted-foreground">
                      {config.deviceId}
                    </TableCell>
                    <TableCell className="text-sm">
                      {config.port || "-"}
                    </TableCell>
                    <TableCell className="text-sm text-muted-foreground truncate max-w-xs">
                      {config.triggerPath.split("\\").pop()}
                    </TableCell>
                    <TableCell>
                      <span
                        className={`inline-flex items-center px-2 py-1 rounded-md text-xs font-semibold ${
                          config.isEnabled
                            ? "bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-400"
                            : "bg-gray-100 text-gray-700 dark:bg-gray-900/30 dark:text-gray-400"
                        }`}
                      >
                        {config.isEnabled ? "Enabled" : "Disabled"}
                      </span>
                    </TableCell>
                      <TableCell className="flex gap-2">
                      <StartButton configId={config.id} friendlyName={config.friendlyName} />
                      <Link href={`/configs?edit=${config.id}`}>
                        <Button
                          variant="outline"
                          size="sm"
                          data-testid={`button-edit-device-${config.id}`}
                        >
                          Edit
                        </Button>
                      </Link>
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </div>
      </motion.div>

      {/* Unconfigured/Detected Devices Table */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4, delay: 0.1 }}
        className="bg-card rounded-xl border border-amber-200 dark:border-amber-900/30 shadow-sm overflow-hidden"
      >
        <div className="p-6 border-b border-amber-200 dark:border-amber-900/30 bg-amber-50 dark:bg-amber-950/20 flex items-center justify-between">
          <div className="flex-1">
            <div className="flex items-center gap-2 mb-2">
              <AlertCircle className="w-5 h-5 text-amber-600" />
              <h2 className="text-lg font-bold font-display text-amber-900 dark:text-amber-100">
                Unconfigured USB Devices
              </h2>
            </div>
            <p className="text-sm text-amber-700 dark:text-amber-200">
              These devices were detected but have no configuration. Click to
              configure them.
            </p>
          </div>
          <div className="flex items-center gap-2 ml-4">
            <Button
              variant={showUnconfiguredOnly ? "default" : "outline"}
              size="sm"
              onClick={() => setShowUnconfiguredOnly(!showUnconfiguredOnly)}
              data-testid="button-filter-unconfigured"
            >
              {showUnconfiguredOnly
                ? `Show All (${visibleUnconfigured.length})`
                : `Show Unconfigured (${unconfiguredDevices.length})`}
            </Button>
          </div>
        </div>

        <div className="overflow-x-auto">
          <Table>
            <TableHeader className="bg-muted/30">
              <TableRow>
                <TableHead>Device Name</TableHead>
                <TableHead>Device ID</TableHead>
                <TableHead>First Detected</TableHead>
                <TableHead>Last Seen</TableHead>
                <TableHead>Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {visibleUnconfigured.length === 0 ? (
                <TableRow>
                  <TableCell
                    colSpan={5}
                    className="h-24 text-center text-muted-foreground"
                  >
                    {showUnconfiguredOnly
                      ? "No unconfigured devices detected. All detected devices are configured."
                      : "No devices detected yet. Connect a USB device to track it."}
                  </TableCell>
                </TableRow>
              ) : (
                visibleUnconfigured.map((device) => {
                  // Get first and last event timestamps for this device
                  const deviceLogs = logs?.filter(
                    (log) =>
                      log.deviceId.includes(device.deviceId) ||
                      device.deviceId.includes(log.deviceId)
                  ) || [];

                  const firstDetected = deviceLogs[deviceLogs.length - 1];
                  const lastSeen = deviceLogs[0];

                  return (
                    <TableRow
                      key={device.deviceId}
                      className="group hover:bg-amber-50 dark:hover:bg-amber-950/30 transition-colors"
                    >
                      <TableCell className="font-medium text-foreground">
                        {device.friendlyName || "Unknown Device"}
                      </TableCell>
                      <TableCell className="font-mono text-sm text-muted-foreground">
                        {device.deviceId}
                      </TableCell>
                      <TableCell className="text-sm text-muted-foreground">
                        {firstDetected?.timestamp
                          ? format(new Date(firstDetected.timestamp), "MMM dd HH:mm:ss")
                          : "-"}
                      </TableCell>
                      <TableCell className="text-sm text-muted-foreground">
                        {lastSeen?.timestamp
                          ? format(new Date(lastSeen.timestamp), "MMM dd HH:mm:ss")
                          : "-"}
                      </TableCell>
                      <TableCell className="flex gap-2">
                        {configs?.filter(c => 
                          c.deviceId.includes(device.deviceId) || device.deviceId.includes(c.deviceId)
                        ).map(config => (
                          <StartButton key={config.id} configId={config.id} friendlyName={config.friendlyName} />
                        ))}
                        <Link href="/configs">
                          <Button
                            variant="default"
                            size="sm"
                            className="bg-amber-600 hover:bg-amber-700 text-white"
                            data-testid={`button-configure-device-${device.deviceId}`}
                          >
                            Configure
                          </Button>
                        </Link>
                      </TableCell>
                    </TableRow>
                  );
                })
              )}
            </TableBody>
          </Table>
        </div>
      </motion.div>
    </div>
  );
}
