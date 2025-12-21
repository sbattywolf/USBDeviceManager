
import type { Express } from "express";
import type { Server } from "http";
import { storage } from "./storage";
import { api } from "@shared/routes";
import { z } from "zod";

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
API_URL = "http://localhost:5000/api" # CHANGE THIS TO YOUR REPLIT URL
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
  app.get(api.configs.list.path, async (req, res) => {
    const configs = await storage.getConfigs();
    res.json(configs);
  });

  app.post(api.configs.create.path, async (req, res) => {
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
  });

  app.put(api.configs.update.path, async (req, res) => {
    const existing = await storage.getConfig(Number(req.params.id));
    if (!existing) return res.status(404).json({ message: "Config not found" });

    const input = api.configs.update.input.parse(req.body);
    const updated = await storage.updateConfig(Number(req.params.id), input);
    res.json(updated);
  });

  app.delete(api.configs.delete.path, async (req, res) => {
    await storage.deleteConfig(Number(req.params.id));
    res.status(204).end();
  });

  // Log Routes
  app.get(api.logs.list.path, async (req, res) => {
    const logs = await storage.getLogs();
    res.json(logs);
  });

  app.post(api.logs.create.path, async (req, res) => {
    // This endpoint accepts logs from the Windows Agent or the Simulator
    try {
      const input = api.logs.create.input.parse(req.body);
      
      // If the log is "CONNECTED", we should check if we need to "Simulate" a trigger logic
      // In the real agent, the agent does the trigger. 
      // In simulation mode (from frontend), the frontend might ask backend to check config.
      // But for simplicity, the frontend simulator will just post the log it "thinks" happened, 
      // or we can put logic here.
      
      // Let's rely on the client (Agent or Simulator) to tell us what happened.
      const log = await storage.createLog(input);
      
      // However, if this is a simulation request for "CONNECTED", we can check if there was a match
      // and append a secondary log for "Software Triggered" if we want to be fancy.
      // For now, simple logging.
      
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
  });

  app.delete(api.logs.clear.path, async (req, res) => {
    await storage.clearLogs();
    res.status(204).end();
  });

  // Agent Download
  app.get(api.agent.download.path, (req, res) => {
    res.setHeader('Content-Disposition', 'attachment; filename="windows_agent.py"');
    res.setHeader('Content-Type', 'text/x-python');
    res.send(AGENT_SCRIPT);
  });

  return httpServer;
}
