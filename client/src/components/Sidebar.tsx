import { Link, useLocation } from "wouter";
import { LayoutDashboard, Settings2, Activity, HardDriveDownload, Usb } from "lucide-react";

const items = [
  { href: "/", label: "Dashboard", icon: LayoutDashboard },
  { href: "/configs", label: "Configurations", icon: Settings2 },
  { href: "/logs", label: "Event Logs", icon: Activity },
  { href: "/agent", label: "Windows Agent", icon: HardDriveDownload },
];

export function Sidebar() {
  const [location] = useLocation();

  return (
    <div className="w-64 h-screen bg-card border-r border-border flex flex-col fixed left-0 top-0 z-20 shadow-xl shadow-black/5">
      <div className="p-6 border-b border-border/50">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-primary to-accent flex items-center justify-center shadow-lg shadow-primary/25">
            <Usb className="w-6 h-6 text-white" />
          </div>
          <div>
            <h1 className="font-display font-bold text-lg leading-tight">USB Guard</h1>
            <p className="text-xs text-muted-foreground">Device Monitor</p>
          </div>
        </div>
      </div>

      <nav className="flex-1 p-4 space-y-1 overflow-y-auto">
        {items.map((item) => {
          const isActive = location === item.href;
          return (
            <Link key={item.href} href={item.href} className={isActive ? "sidebar-link sidebar-link-active" : "sidebar-link sidebar-link-inactive"}>
                <item.icon className={`w-5 h-5 ${isActive ? "text-primary" : "text-muted-foreground"}`} />
                {item.label}
            </Link>
          );
        })}
      </nav>

      <div className="p-4 border-t border-border/50">
        <div className="bg-primary/5 rounded-lg p-4 border border-primary/10">
          <p className="text-xs font-medium text-primary mb-1">Status: Active</p>
          <p className="text-[10px] text-muted-foreground">System monitoring service is running in background.</p>
        </div>
      </div>
    </div>
  );
}
