import { Button } from "@/components/ui/button";
import { Download, Terminal, Info, CheckCircle2 } from "lucide-react";
import { Card } from "@/components/ui/card";
import BackupsPanel from '@/components/Admin/BackupsPanel';

export default function Agent() {
  const handleDownload = () => {
    window.location.href = "/api/agent/download";
  };

  return (
    <div className="space-y-8 max-w-4xl mx-auto">
      <div className="text-center space-y-4">
        <h1 className="text-4xl font-display font-bold text-foreground">Windows Agent Setup</h1>
        <p className="text-lg text-muted-foreground max-w-2xl mx-auto">
          The agent is a lightweight Python script that runs on your Windows machine to detect USB events and execute the configured triggers.
        </p>
      </div>

      <div className="grid md:grid-cols-2 gap-8">
        <Card className="p-8 border-primary/20 bg-gradient-to-br from-card to-primary/5 shadow-lg">
          <div className="flex flex-col items-center text-center space-y-6">
            <div className="w-16 h-16 bg-primary/10 rounded-2xl flex items-center justify-center text-primary">
              <Download className="w-8 h-8" />
            </div>
            <div>
              <h3 className="text-xl font-bold">Download Script</h3>
              <p className="text-muted-foreground mt-2 text-sm">Get the `usb_agent.py` file to run on your host machine.</p>
            </div>
            <Button onClick={handleDownload} size="lg" className="w-full bg-primary shadow-lg shadow-primary/25 hover:shadow-xl hover:shadow-primary/30 transition-all">
              <Download className="w-5 h-5 mr-2" /> Download Agent
            </Button>
          </div>
        </Card>

        <Card className="p-8 border-border shadow-md">
          <h3 className="text-lg font-bold mb-6 flex items-center gap-2">
            <Terminal className="w-5 h-5 text-accent" /> Installation Steps
          </h3>
          
          <div className="space-y-6 relative before:absolute before:left-[15px] before:top-2 before:h-full before:w-[2px] before:bg-border/50">
            {[
              { title: "Install Python", desc: "Ensure Python 3.8+ is installed on your Windows machine." },
              { title: "Install Dependencies", desc: "Run `pip install wmi pywin32 requests` in PowerShell." },
              { title: "Configure Endpoint", desc: "Edit the script to point to this server URL if not 127.0.0.1." },
              { title: "Run the Agent", desc: "Execute `python usb_agent.py` to start monitoring." }
            ].map((step, i) => (
              <div key={i} className="relative pl-10">
                <div className="absolute left-0 top-0 w-8 h-8 rounded-full bg-background border-2 border-primary text-primary text-xs font-bold flex items-center justify-center z-10">
                  {i + 1}
                </div>
                <h4 className="font-bold text-foreground">{step.title}</h4>
                <code className="text-xs text-muted-foreground mt-1 block bg-muted/50 p-2 rounded border border-border/50">
                  {step.desc}
                </code>
              </div>
            ))}
          </div>
        </Card>
      </div>

      <div className="bg-blue-50 dark:bg-blue-900/20 border border-blue-100 dark:border-blue-800 rounded-xl p-6 flex gap-4 items-start">
        <Info className="w-6 h-6 text-blue-600 dark:text-blue-400 shrink-0 mt-0.5" />
        <div>
          <h4 className="font-bold text-blue-900 dark:text-blue-300">Pro Tip: Run as Service</h4>
          <p className="text-sm text-blue-700 dark:text-blue-400 mt-1">
            To have the agent run automatically in the background when Windows starts, you can use NSSM (Non-Sucking Service Manager) or Windows Task Scheduler to run the python script at login.
          </p>
        </div>
      </div>

      <div className="mt-8">
        <BackupsPanel />
      </div>
    </div>
  );
}
