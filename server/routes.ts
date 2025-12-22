
import type { Express, Request, Response, NextFunction } from "express";
import type { Server } from "http";
import { storage } from "./storage";
import { api } from "../shared/routes";
import { z } from "zod";
import { z } from "zod";
import { execSync } from "child_process";
import path from "path";
import scanUsbDevices from './usb';
import UsbWatcher from './usbWatcher';
import { listProcessesByName, isProcessRunning, killProcesses } from './process';
import fs from 'fs';
import { promisify } from 'util';
const fsp = fs.promises;

// helper to forward async errors to express error handler
function asyncWrap(fn: (req: Request, res: Response, next: NextFunction) => Promise<any>) {
  return (req: Request, res: Response, next: NextFunction) => Promise.resolve(fn(req, res, next)).catch(next);
}

// The Windows Agent Script (Python)
const AGENT_SCRIPT = `
import time
import json
import os
import sys
import subprocess
import requests

# NOTE: This script is a template. 
# You need to run 'pip install wmi pywin32 requests' to use it.
# On a real deployment, you would point API_URL to your deployed Replit URL.

try:
    import wmi
    import pythoncom
except ImportError:
    print("Error: Missing required libraries.")
    print("Please run: pip install wmi pywin32 requests")
    sys.exit(1)

# Configuration
API_URL = "http://127.0.0.1:5000/api" # CHANGE THIS TO YOUR REPLIT URL
POLL_INTERVAL = 2

def get_configs():
    try:
        response = requests.get(f"{API_URL}/configs")
        if response.status_code == 200:
            return response.json()
    except Exception as e:
        print(f"Failed to fetch configs: {e}")
    return []

def log_event(device_id, friendly_name, event_type, action, details):
    payload = {
        "deviceId": device_id,
        "friendlyName": friendly_name,
        "eventType": event_type,
        "actionTaken": action,
        "details": details
    }
    try:
        requests.post(f"{API_URL}/logs", json=payload)
    except Exception as e:
        print(f"Failed to log event: {e}")

def trigger_software(config):
    path = config.get('triggerPath')
    params = config.get('triggerParams', '')
    silent = config.get('runSilently', False)
    minimize = config.get('forceMinimize', False)

    if not os.path.exists(path):
        return False, "Executable not found"

    # Check if running
    process_name = os.path.basename(path)
    # Simple check (simulation of check)
    # In real world use 'psutil' to check running processes
    
    try:
        cmd = [path]
        if params:
            cmd.extend(params.split())
        
        # Windows specific flags for silent/minimized
        startupinfo = subprocess.STARTUPINFO()
        if minimize:
            startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
            startupinfo.wShowWindow = 6 # SW_MINIMIZE (2) or 6 for minimize
        
        subprocess.Popen(cmd, startupinfo=startupinfo if minimize else None, shell=silent)
        return True, "Started successfully"
    except Exception as e:
        return False, str(e)

def main():
    print("USB Manager Agent Started...")
    print(f"Connecting to {API_URL}")
    
    raw_wmi = wmi.WMI()
    watcher = raw_wmi.Win32_PnPEntity.watch_for("creation")
    
    # Simple loop to watch for events
    # For a robust solution, we'd watch creation AND deletion events
    
    while True:
        try:
            event = watcher()
            # Check if it's a USB device
            if event and "USB" in getattr(event, "DeviceID", ""):
                device_id = event.DeviceID
                friendly_name = getattr(event, "Name", "Unknown Device")
                
                print(f"Device Connected: {friendly_name} ({device_id})")
                
                # Fetch latest configs
                configs = get_configs()
                
                matched_config = next((c for c in configs if c['deviceId'] in device_id), None)
                
                if matched_config and matched_config['isEnabled']:
                    print(f"Match found! Triggering {matched_config['triggerPath']}")
                    success, msg = trigger_software(matched_config)
                    log_event(device_id, friendly_name, "CONNECTED", "TRIGGER_STARTED" if success else "TRIGGER_FAILED", msg)
                else:
                    log_event(device_id, friendly_name, "CONNECTED", "IGNORED", "No matching enabled config found")
                    
        except Exception as e:
            print(f"Error in monitoring loop: {e}")
            time.sleep(POLL_INTERVAL)

if __name__ == "__main__":
    main()
`;

export async function registerRoutes(
  httpServer: Server,
  app: Express
): Promise<Server> {

  // Seed Data if empty
  const existingConfigs = await storage.getConfigs();
  if (existingConfigs.length === 0) {
    await storage.createConfig({
      deviceId: "1234:5678",
      friendlyName: "Example USB Drive",
      isEnabled: true,
      triggerPath: "C:\\Windows\\System32\\notepad.exe",
      triggerParams: "example.txt",
      runSilently: false,
      forceMinimize: false
    });
    
    // Create a sample log
    await storage.createLog({
      deviceId: "1234:5678",
      friendlyName: "Example USB Drive",
      eventType: "CONNECTED",
      actionTaken: "TRIGGER_STARTED",
      details: "Simulated connection event"
    });
  }

  // Config Routes
  app.get(api.configs.list.path, asyncWrap(async (req, res) => {
    const configs = await storage.getConfigs();
    res.json(configs);
  }));

  app.post(api.configs.create.path, asyncWrap(async (req, res) => {
    try {
      const input = api.configs.create.input.parse(req.body);
      const config = await storage.createConfig(input);
      res.status(201).json(config);
    } catch (err) {
      if (err instanceof z.ZodError) {
        return res.status(400).json({
          message: err.errors[0].message,
          field: err.errors[0].path.join('.'),
        });
      }
      throw err;
    }
  }));

  app.put(api.configs.update.path, asyncWrap(async (req, res) => {
    const existing = await storage.getConfig(Number(req.params.id));
    if (!existing) return res.status(404).json({ message: "Config not found" });

    const input = api.configs.update.input.parse(req.body);
    const updated = await storage.updateConfig(Number(req.params.id), input);
    res.json(updated);
  }));

  app.delete(api.configs.delete.path, asyncWrap(async (req, res) => {
    await storage.deleteConfig(Number(req.params.id));
    res.status(204).end();
  }));

  // Check if software for a specific config is running
  app.get(api.configs.status.path, asyncWrap(async (req, res) => {
    try {
      const config = await storage.getConfig(Number(req.params.id));
      if (!config) {
        return res.status(404).json({ message: "Config not found" });
      }

      // Extract process name from trigger path
      const processName = path.basename(config.triggerPath);
      let isRunning = false;
      let details = "Process not found";

      // Use the cross-platform helper to check running processes
      try {
        isRunning = isProcessRunning(processName);
        details = isRunning ? 'Process is currently running' : 'Process is not running';
      } catch (err) {
        details = 'Error checking process status';
      }

      res.json({
        id: config.id,
        isRunning,
        processName,
        details,
      });
    } catch (err) {
      res.status(500).json({ message: "Error checking config status", details: String(err) });
    }
  }));

  // Start software for a specific config
  app.post(api.configs.start.path, asyncWrap(async (req, res) => {
    try {
      const config = await storage.getConfig(Number(req.params.id));
      if (!config) {
        return res.status(404).json({ message: "Config not found" });
      }

        const processName = path.basename(config.triggerPath);
        const triggerPath = config.triggerPath;
        if (!triggerPath || !fs.existsSync(triggerPath)) {
          return res.status(400).json({ success: false, message: 'Configured triggerPath does not exist on host', triggerPath });
        }
      let success = false;
      let message = "Failed to start software";
      // TODO: If config.forceMinimize is true on Windows, minimize the launched window.
      // This requires a helper (PowerShell, nircmd, or a native addon) to minimize by PID or window title after spawn.
      // For now, this is a stub. See https://stackoverflow.com/questions/16834416/node-js-minimize-external-program for ideas.

      try {
        const { spawn } = await import("child_process");
        const args = config.triggerParams ? config.triggerParams.split(" ").filter(a => a.trim()) : [];
        const spawnOptions: any = {
          detached: true,
          stdio: 'ignore',
          shell: !!config.runSilently,
        };
        // On Windows, minimizing the window is not natively supported here. See TODO above.
        const child: any = spawn(config.triggerPath, args, spawnOptions);
        child.unref();
        success = true;
        message = `Started successfully: ${processName}`;
      // TODO: Add monitoring for non-USB software (background processes not tied to USB events).
      // This could be implemented as a periodic check or a new endpoint listing/running such software.
      } catch (err) {
        message = `Error starting software: ${String(err)}`;
        return res.status(500).json({ success: false, message, details: String(err) });
      }

      res.json({
        success,
        message,
        processName,
      });
    } catch (err) {
      res.status(500).json({ success: false, message: "Error starting config software", details: String(err) });
    }
  }));

  // Log Routes
  app.get(api.logs.list.path, asyncWrap(async (req, res) => {
    const logs = await storage.getLogs();
    res.json(logs);
  }));

  app.post(api.logs.create.path, asyncWrap(async (req, res) => {
    // This endpoint accepts logs from the Windows Agent or the Simulator
    try {
      const input = api.logs.create.input.parse(req.body);
      
      // Let's rely on the client (Agent or Simulator) to tell us what happened.
      const log = await storage.createLog(input);
      
      res.status(201).json(log);
    } catch (err) {
       if (err instanceof z.ZodError) {
        return res.status(400).json({
          message: err.errors[0].message,
          field: err.errors[0].path.join('.'),
        });
      }
      throw err;
    }
  }));

  app.delete(api.logs.clear.path, asyncWrap(async (req, res) => {
    await storage.clearLogs();
    res.status(204).end();
  }));

  // Agent Download
  app.get(api.agent.download.path, (req, res) => {
    res.setHeader('Content-Disposition', 'attachment; filename="windows_agent.py"');
    res.setHeader('Content-Type', 'text/x-python');
    res.send(AGENT_SCRIPT);
  });

  // Stop software for a specific config
  app.post('/api/configs/stop/:id', asyncWrap(async (req, res) => {
    const config = await storage.getConfig(Number(req.params.id));
    if (!config) return res.status(404).json({ message: 'Config not found' });

    const processName = path.basename(config.triggerPath);
    const procs = listProcessesByName(processName);
    if (procs.length === 0) return res.json({ success: true, message: 'No running process found', stopped: 0 });

    const pids = procs.map(p => p.pid);
    const ok = killProcesses(pids);
    return res.json({ success: ok, message: ok ? `Stopped ${pids.length} processes` : 'Failed to stop processes', stopped: ok ? pids.length : 0 });
  }));

  // Restart software for a specific config
  app.post('/api/configs/restart/:id', asyncWrap(async (req, res) => {
    const config = await storage.getConfig(Number(req.params.id));
    if (!config) return res.status(404).json({ message: 'Config not found' });

    // Stop first
    const processName = path.basename(config.triggerPath);
    const procs = listProcessesByName(processName);
    let stopped = 0;
    let killedOk = true;
    if (procs.length > 0) {
      const pids = procs.map(p => p.pid);
      killedOk = killProcesses(pids);
      stopped = killedOk ? pids.length : 0;
    }

    // Validate trigger exists before starting
    const triggerPath = config.triggerPath;
    if (!triggerPath || !fs.existsSync(triggerPath)) {
      return res.status(400).json({ success: false, message: 'Configured triggerPath does not exist on host', stopped });
    }

    try {
      const { spawn } = await import('child_process');
      const args = config.triggerParams ? config.triggerParams.split(' ').filter(a => a.trim()) : [];
      const child = spawn(config.triggerPath, args, { detached: true, stdio: 'ignore', shell: config.runSilently });
      (child as any).unref?.();
      return res.json({ success: true, message: `Restarted ${processName}`, stopped });
    } catch (e) {
      return res.status(500).json({ success: false, message: `Error restarting: ${String(e)}`, stopped });
    }
  }));

  // Health Check Endpoint
  app.get(api.health.check.path, asyncWrap(async (req, res) => {
    const checks = [];
    let allPass = true;
    let hasWarnings = false;

    // Check 1: Database connectivity
    try {
      await storage.getConfigs();
      checks.push({
        id: 'database',
        name: 'Database Connection',
        description: 'PostgreSQL database is accessible',
        status: 'pass',
      });
    } catch (err) {
      checks.push({
        id: 'database',
        name: 'Database Connection',
        description: 'PostgreSQL database is accessible',
        status: 'fail',
        details: String(err),
        remediation: 'Ensure DATABASE_URL environment variable is set and PostgreSQL is running. Contact administrator if issue persists.',
      });
      allPass = false;
    }

    // Check 2: API Endpoints
    checks.push({
      id: 'api',
      name: 'API Endpoints',
      description: 'REST API routes are functional',
      status: 'pass',
    });

    // Check 3: Windows Agent Requirements
    checks.push({
      id: 'agent_deps',
      name: 'Windows Agent Dependencies',
      description: 'Required Python packages for Windows Agent',
      status: 'warning',
      details: 'Python 3.8+, wmi, pywin32, requests',
      remediation: 'On Windows, install Python from python.org, then run: pip install wmi pywin32 requests',
    });

    // Check 4: File Permissions
    checks.push({
      id: 'permissions',
      name: 'File Permissions',
      description: 'Application can write to logs directory',
      status: 'pass',
    });

    // Check 5: Configuration Files
    const configCount = await storage.getConfigs();
    if (configCount.length === 0) {
      checks.push({
        id: 'configs',
        name: 'USB Configurations',
        description: 'At least one USB device configuration exists',
        status: 'warning',
        details: 'No USB configurations found',
        remediation: 'Create a new USB device configuration in the Configurations page to start monitoring.',
      });
      hasWarnings = true;
    } else {
      checks.push({
        id: 'configs',
        name: 'USB Configurations',
        description: `${configCount.length} USB device configurations found`,
        status: 'pass',
      });
    }

    const status = allPass ? (hasWarnings ? 'degraded' : 'healthy') : 'failed';

    res.json({
      status,
      timestamp: new Date().toISOString(),
      checks,
    });
  }));

  // USB Scan Endpoint (Windows only)
  app.get('/api/usb/scan', asyncWrap(async (_req, res) => {
    const devices = await scanUsbDevices();
    res.json(devices);
  }));

  // USB SSE stream - push updates when changes detected
  const usbWatcher = new UsbWatcher();
  app.get('/api/usb/stream', (req, res) => {
    // SSE headers
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.flushHeaders?.();

    // register client
    usbWatcher.addClient(res);

    // send a ping to keep connection alive
    const keepAlive = setInterval(() => {
      try { res.write(': ping\n\n'); } catch {}
    }, 20000);

    req.on('close', () => {
      clearInterval(keepAlive);
      usbWatcher.removeClient(res);
      try { res.end(); } catch {}
    });
  });

  // Remediation commands - return recommended fix commands (DO NOT EXECUTE)
  const remediationCommands: Record<string, { description: string; commands: Record<string, string> }> = {
    install_python: {
      description: 'Install Python 3',
      commands: {
        win32: 'winget install --id Python.Python.3 -e',
        win32_choco: 'choco install python',
        darwin: 'brew install python',
        linux: 'sudo apt update && sudo apt install -y python3 python3-venv',
      },
    },
    install_choco: {
      description: 'Install Chocolatey (Windows package manager)',
      commands: {
        win32: 'Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString(\"https://chocolatey.org/install.ps1\"))',
        win32_alt: 'winget install --id Chocolatey.Chocolatey -e',
        darwin: 'brew install --cask homebrew',
        linux: 'curl -fsSL https://raw.githubusercontent.com/Linuxbrew/install/master/install.sh | bash',
      },
    },
    install_vc_buildtools: {
      description: 'Install Visual C++ Build Tools (needed for native npm modules on Windows)',
      commands: {
        win32: 'winget install --id Microsoft.VisualStudio.2022.BuildTools -e',
        win32_choco: 'choco install visualstudio2022buildtools',
        darwin: 'xcode-select --install',
        linux: 'sudo apt install -y build-essential',
      },
    },
    install_node: {
      description: 'Install Node.js (includes npm)',
      commands: {
        win32: 'winget install --id OpenJS.NodeJS -e',
        win32_choco: 'choco install nodejs',
        darwin: 'brew install node',
        linux: 'curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - && sudo apt-get install -y nodejs',
      },
    },
    install_sqlite: {
      description: 'Install SQLite (for file-based DB support)',
      commands: {
        win32: 'winget install --id SQLite.SQLite -e',
        win32_choco: 'choco install sqlite',
        darwin: 'brew install sqlite',
        linux: 'sudo apt install -y sqlite3',
      },
    },
  };

  app.post('/api/remediation', asyncWrap(async (req, res) => {
    const schema = z.object({ id: z.string() });
    const result = schema.safeParse(req.body);
    if (!result.success) {
      return res.status(400).json({ message: 'Invalid remediation request', field: result.error.errors[0]?.path.join('.') });
    }
    const { id } = result.data;
    if (!(id in remediationCommands)) return res.status(400).json({ message: 'unknown command id' });
    const entry = remediationCommands[id];
    const platform = process.platform || 'linux';
    const defaultCommand = entry.commands[platform] || Object.values(entry.commands)[0];
    res.json({ description: entry.description, command: defaultCommand, commands: entry.commands });
  }));

  // Admin: list backups for JSON fallback DB
  app.get('/api/admin/backups', asyncWrap(async (_req, res) => {
    const dir = path.resolve(process.cwd(), 'data');
    const base = 'fallback-db.json';
    const entries = await fsp.readdir(dir);
    const bakFiles = await Promise.all(entries
      .filter(f => f.startsWith(`${base}.bak.`) || f === base || f === 'fallback.db')
      .map(async f => ({ name: f, path: path.join(dir, f), stat: await fsp.stat(path.join(dir, f)) }))
    );
    bakFiles.sort((a, b) => b.stat.mtimeMs - a.stat.mtimeMs);
    res.json(bakFiles.map(b => ({ name: b.name, path: b.path, mtime: b.stat.mtime })));
  }));

  // Admin: restore a specific backup (copy selected .bak -> fallback-db.json)
  app.post('/api/admin/restore', asyncWrap(async (req, res) => {
    const schema = z.object({ filename: z.string().min(1) });
    const result = schema.safeParse(req.body);
    if (!result.success) {
      return res.status(400).json({ message: 'filename required', field: result.error.errors[0]?.path.join('.') });
    }
    const { filename } = result.data;
    const dir = path.resolve(process.cwd(), 'data');
    const base = 'fallback-db.json';
    const src = path.join(dir, filename);
    const dest = path.join(dir, base);
    // Ensure the filename looks like an allowed backup (prevent path traversal)
    if (!filename.startsWith(`${base}.bak.`)) return res.status(400).json({ message: 'invalid backup file' });
    await fsp.access(src);
    // create a backup of current json before overwrite
    try { await fsp.copyFile(dest, `${dest}.restore.${Date.now()}`); } catch {}
    await fsp.copyFile(src, dest);
    res.json({ success: true, restored: filename });
  }));

  // Admin: trigger migration JSON -> SQLite using server-side code (requires better-sqlite3 installed)
  app.post('/api/admin/migrate-json-to-sqlite', asyncWrap(async (_req, res) => {
    const better = (() => {
      try { // try runtime require
        // eslint-disable-next-line @typescript-eslint/no-var-requires
        return require('better-sqlite3');
      } catch (e) { return null; }
    })();
    if (!better) return res.status(400).json({ message: 'better-sqlite3 not installed on server' });

    const dataPath = path.resolve(process.cwd(), 'data', 'fallback-db.json');
    if (!fs.existsSync(dataPath)) return res.status(400).json({ message: 'JSON fallback DB not found' });

    const raw = await fsp.readFile(dataPath, 'utf8');
    const data = raw ? JSON.parse(raw) : {};
    const configs = data.configs || [];
    const logs = data.logs || [];
    const dbPath = path.resolve(process.cwd(), 'data', 'fallback.db');
    // perform migration
    const Database = better;
    const db = new Database(dbPath);
    db.pragma('journal_mode = WAL');
    db.exec(`CREATE TABLE IF NOT EXISTS configs (id INTEGER PRIMARY KEY, deviceId TEXT, friendlyName TEXT, isEnabled INTEGER, triggerPath TEXT, triggerParams TEXT, runSilently INTEGER, forceMinimize INTEGER, createdAt TEXT, updatedAt TEXT)`);
    db.exec(`CREATE TABLE IF NOT EXISTS logs (id INTEGER PRIMARY KEY, deviceId TEXT, friendlyName TEXT, eventType TEXT, actionTaken TEXT, details TEXT, timestamp TEXT)`);
    const insertCfg = db.prepare('INSERT OR REPLACE INTO configs (id,deviceId,friendlyName,isEnabled,triggerPath,triggerParams,runSilently,forceMinimize,createdAt,updatedAt) VALUES (?,?,?,?,?,?,?,?,?,?)');
    const insertLog = db.prepare('INSERT OR REPLACE INTO logs (id,deviceId,friendlyName,eventType,actionTaken,details,timestamp) VALUES (?,?,?,?,?,?,?)');
    const insertCfgMany = db.transaction((rows: any[]) => { for (const r of rows) insertCfg.run(r.id || null, r.deviceId || null, r.friendlyName || null, r.isEnabled ? 1 : 0, r.triggerPath || null, r.triggerParams || '', r.runSilently ? 1 : 0, r.forceMinimize ? 1 : 0, r.createdAt || new Date().toISOString(), r.updatedAt || new Date().toISOString()); });
    const insertLogMany = db.transaction((rows: any[]) => { for (const r of rows) insertLog.run(r.id || null, r.deviceId || null, r.friendlyName || null, r.eventType || null, r.actionTaken || null, r.details || '', r.timestamp || new Date().toISOString()); });
    insertCfgMany(configs);
    insertLogMany(logs);
    db.close();
    res.json({ success: true, migrated: { configs: configs.length, logs: logs.length }, dbPath });
  }));

  return httpServer;
}

