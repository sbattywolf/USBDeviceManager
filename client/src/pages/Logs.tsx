import { useUsbLogs, useClearLogs } from "@/hooks/use-usb-logs";
import { format } from "date-fns";
import { Trash2, Download, Search, RefreshCcw } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useState } from "react";
import { motion } from "framer-motion";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";

export default function Logs() {
  const { data: logs, isLoading, refetch } = useUsbLogs();
  const clearLogs = useClearLogs();
  const [searchTerm, setSearchTerm] = useState("");

  const filteredLogs = logs?.filter(log => 
    log.friendlyName?.toLowerCase().includes(searchTerm.toLowerCase()) || 
    log.deviceId.toLowerCase().includes(searchTerm.toLowerCase()) ||
    log.actionTaken?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const handleExport = () => {
    if (!logs) return;
    const csvContent = "data:text/csv;charset=utf-8," 
      + "Timestamp,Device ID,Friendly Name,Event Type,Action,Details\n"
      + logs.map(e => `${e.timestamp},${e.deviceId},${e.friendlyName},${e.eventType},${e.actionTaken},${e.details}`).join("\n");
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement("a");
    link.setAttribute("href", encodedUri);
    link.setAttribute("download", `usb_logs_${format(new Date(), 'yyyy-MM-dd')}.csv`);
    document.body.appendChild(link);
    link.click();
  };

  if (isLoading) return <div className="p-10 text-center text-muted-foreground animate-pulse">Loading logs...</div>;

  return (
    <div className="space-y-8 h-full flex flex-col">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-3xl font-display font-bold text-foreground">Event Logs</h1>
          <p className="text-muted-foreground mt-2">Historical record of all USB connections and automated actions.</p>
        </div>
        <div className="flex gap-2">
           <Button variant="outline" onClick={() => refetch()} title="Refresh">
             <RefreshCcw className="w-4 h-4" />
           </Button>
           <Button variant="outline" onClick={handleExport}>
             <Download className="w-4 h-4 mr-2" /> Export CSV
           </Button>
           <Button 
             variant="destructive" 
             onClick={() => {
               if(confirm("Clear all logs? This cannot be undone.")) clearLogs.mutate();
             }}
           >
             <Trash2 className="w-4 h-4 mr-2" /> Clear History
           </Button>
        </div>
      </div>

      <div className="relative max-w-md">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
        <Input 
          placeholder="Filter logs..." 
          className="pl-10 rounded-xl border-border bg-card shadow-sm"
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
        />
      </div>

      <motion.div 
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        className="bg-card border border-border rounded-2xl shadow-sm overflow-hidden flex-1"
      >
        <div className="overflow-auto max-h-[600px]">
          <Table>
            <TableHeader className="bg-muted/30 sticky top-0 z-10 backdrop-blur-md">
              <TableRow>
                <TableHead className="w-[180px]">Timestamp</TableHead>
                <TableHead className="w-[120px]">Event Type</TableHead>
                <TableHead>Device</TableHead>
                <TableHead>Action Taken</TableHead>
                <TableHead className="w-[300px]">Details</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {filteredLogs?.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={5} className="h-32 text-center text-muted-foreground">
                    No logs match your filter.
                  </TableCell>
                </TableRow>
              ) : (
                filteredLogs?.map((log) => (
                  <TableRow key={log.id} className="hover:bg-muted/20">
                    <TableCell className="font-mono text-xs text-muted-foreground">
                      {log.timestamp ? format(new Date(log.timestamp), "yyyy-MM-dd HH:mm:ss") : "-"}
                    </TableCell>
                    <TableCell>
                      <span className={`inline-flex items-center px-2 py-1 rounded-md text-xs font-semibold border ${
                        log.eventType === 'CONNECTED' 
                          ? 'bg-emerald-50 text-emerald-700 border-emerald-100 dark:bg-emerald-900/20 dark:text-emerald-400 dark:border-emerald-800' 
                          : 'bg-amber-50 text-amber-700 border-amber-100 dark:bg-amber-900/20 dark:text-amber-400 dark:border-amber-800'
                      }`}>
                        {log.eventType}
                      </span>
                    </TableCell>
                    <TableCell>
                      <div className="flex flex-col">
                        <span className="font-medium text-sm">{log.friendlyName || "Unknown Device"}</span>
                        <code className="text-xs text-muted-foreground">{log.deviceId}</code>
                      </div>
                    </TableCell>
                    <TableCell>
                       <span className="text-sm font-medium">{log.actionTaken}</span>
                    </TableCell>
                    <TableCell className="text-xs text-muted-foreground font-mono truncate max-w-[300px]" title={log.details || ""}>
                      {log.details || "-"}
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </div>
      </motion.div>
    </div>
  );
}
