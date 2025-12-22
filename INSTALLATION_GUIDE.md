# USB Device Management System - Installation & Setup Guide

## Overview
This application provides a comprehensive GUI dashboard for managing USB device monitoring and automatic software triggering on Windows 11. It consists of:
- **Dashboard (Web Interface)**: Manage configurations, view logs, simulate events
- **Windows Agent (Python Script)**: Runs on your Windows PC to monitor actual USB connections

---

## Part 1: Desktop Installation (Web Dashboard)

### Prerequisites
- **Windows 11** with administrative access
- **Node.js** (v16 or higher) - [Download](https://nodejs.org/)
- **PostgreSQL** (v12 or higher) - [Download](https://www.postgresql.org/download/windows/)
  - Or use the built-in cloud database if deploying to Replit

### Step 1: Clone/Download the Application
```bash
# Clone the repository
git clone <your-repo-url>
cd usb-device-manager

# Or if you have a zip file, extract it
```

### Step 2: Install Dependencies
```bash
# Install all required packages
npm install
```

### Step 3: Configure Database
The application uses PostgreSQL. Set up your database:

**Option A: Local PostgreSQL Installation**
```bash
# Create a new database
CREATE DATABASE usb_manager;

# Note your connection details:
# Host: 127.0.0.1
# Port: 5432 (default)
# User: postgres (default)
# Password: <your-password>
# Database: usb_manager
```

**Option B: Cloud Database (Recommended for simplicity)**
- If using Replit's built-in PostgreSQL, the `DATABASE_URL` is already configured

### Step 4: Set Environment Variables
Create a `.env` file in the root directory:
```env
DATABASE_URL=postgresql://username:password@127.0.0.1:5432/usb_manager
PORT=5000
NODE_ENV=development
```

Replace `username`, `password`, `127.0.0.1`, and `usb_manager` with your actual database credentials.

### Step 5: Initialize Database
```bash
# Push the schema to your database
npm run db:push

# This creates all necessary tables (usb_configs, usb_logs)
```

### Step 6: Start the Application
```bash
# Start the development server
npm run dev

# The application will be available at: http://127.0.0.1:5000
```

You should see:
```
2:48:26 PM [express] serving on port 5000
```

Open your browser and navigate to `http://127.0.0.1:5000`

---

## Part 2: Windows Agent Installation

### Prerequisites
- **Python 3.8+** installed on your Windows PC - [Download](https://www.python.org/downloads/windows/)
- **Administrator access** (required to monitor USB events)
- The web dashboard running and accessible (noted from Part 1)

### Step 1: Download the Agent Script
1. Open the Dashboard in your browser
2. Go to the **Agent** page (left sidebar)
3. Click **"Download Agent Script"** to download `windows_agent.py`
4. Save it to a convenient location (e.g., `C:\usb-manager\windows_agent.py`)

### Step 2: Install Python Dependencies
Open **PowerShell as Administrator** and run:

```powershell
# Install required packages
pip install wmi pywin32 requests

# Configure PyWin32 (required for WMI access)
pywin32_postinstall -install

# Verify installation
python -c "import wmi; print('WMI installed successfully')"
```

If you get an error, ensure Python is added to your PATH:
```powershell
# Check Python is accessible
python --version

# If not found, add Python to PATH manually
```

### Step 3: Configure the Agent
Edit `windows_agent.py` with a text editor and update this line:

```python
API_URL = "http://127.0.0.1:5000/api"  # Change this value if running remotely
```

**Examples:**
- **Local machine**: `http://127.0.0.1:5000/api`
- **Remote/Network machine**: `http://192.168.1.100:5000/api` (replace with your IP)
- **Cloud dashboard**: `https://your-replit-app.replit.dev/api`

### Step 4: Test the Agent
Run the agent in PowerShell (as Administrator):

```powershell
python C:\usb-manager\windows_agent.py
```

You should see:
```
USB Manager Agent Started...
Connecting to http://localhost:5000/api
```

**The agent will now monitor for USB device connections.**

### Step 5: Set Up Auto-Start (Optional)
To run the agent automatically when Windows starts:

#### Using Windows Task Scheduler:
1. Open **Task Scheduler** (search in Windows)
2. Click **Create Task** in the right panel
3. **General Tab:**
   - Name: `USB Manager Agent`
   - Check "Run with highest privileges"
4. **Triggers Tab:**
   - Click "New"
   - Select "At startup"
5. **Actions Tab:**
   - Program: `python.exe`
   - Arguments: `C:\usb-manager\windows_agent.py`
6. Click OK and confirm with your credentials

#### Using Batch Script (Simpler):
Create a file `start_agent.bat`:
```batch
@echo off
REM USB Manager Agent Startup Script
cd C:\usb-manager
python windows_agent.py
pause
```

Save as `start_agent.bat`, then:
- Place it in `C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\`
- Agent will start automatically on next reboot

---

## Part 3: Configure USB Devices to Monitor

### In the Dashboard:
1. Navigate to **Configurations** page
2. Click **"Add Configuration"**
3. Fill in the required fields:

| Field | Description | Example |
|-------|-------------|---------|
| **Device ID** | USB device identifier (VID:PID) | `1234:5678` |
| **Friendly Name** | Human-readable name | "USB Drive - Backup" |
| **Port** (optional) | Specific USB port (e.g., COM5) | `COM5` |
| **Trigger Path** | Full path to executable | `C:\Windows\System32\notepad.exe` |
| **Parameters** (optional) | Command-line arguments | `example.txt` |
| **Run Silently** | Hide application window | Checked |
| **Force Minimize** | Minimize after launch | Checked |

4. Click **Save**

### How to Find Your USB Device ID:
In PowerShell (as Administrator):
```powershell
# List all USB devices
Get-PnpDevice -Class USB* | Select-Object Name, PNPDeviceID

# Look for your device, note the VID:PID (e.g., USB\VID_1234&PID_5678)
```

---

## Part 4: Testing & Troubleshooting

### Simulating USB Events (Without Physical USB)
In the Dashboard **Home** page:
1. Use the "Simulate USB Event" widget
2. Enter a Device ID that matches a configuration
3. Click "Simulate Connection"
4. Check the **Logs** page to verify the action was triggered

### Checking Logs
Navigate to **Logs** page to view:
- All USB connection events
- Actions taken (software triggered, ignored, failed)
- Timestamps and error details

### Troubleshooting Checklist

| Issue | Cause | Solution |
|-------|-------|----------|
| **Agent won't start** | Python not installed | Download Python 3.8+ from python.org |
| **"Module not found" error** | Missing dependencies | Run: `pip install wmi pywin32 requests` |
| **Agent can't connect to dashboard** | Wrong API_URL | Update API_URL in windows_agent.py, use correct IP |
| **Software not triggering** | Device ID mismatch | Verify Device ID matches configuration |
| **Database connection error** | Database not running | Start PostgreSQL service |
| **Port 5000 already in use** | Another app using port | Change PORT in .env file or close other apps |


### Viewing Detailed Logs
Check the application logs in the browser console:
- Press **F12** to open Developer Tools
- Go to **Console** tab to see errors
- All API responses are logged here

#### Server Error Log (Persistent)
In addition to browser logs, all server-side errors are written to a persistent log file:

   data/error.log

This file is created automatically. Each entry includes a timestamp, error message, and stack trace. If you encounter server issues (such as failed API requests, process errors, or unexplained failures), check this file for details.

**Troubleshooting with error.log:**
- Open `data/error.log` in a text editor to review recent errors.
- Each entry will show the time, error message, and stack trace for debugging.
- If the file grows too large, you can delete or archive it; a new one will be created automatically.

**Example error entry:**
```
[2025-12-22T14:35:10.123Z] Error: Failed to start process
   at startProcess (server/process.ts:42:15)
   at ...
```

For client-side errors, look for toast notifications in the UI and cross-reference with the error log for technical details.

---

## Part 5: Advanced Configuration

### Custom Software Parameters
When triggering software, you can pass parameters:

**Example: Launch Backup Software with specific folder**
```
Trigger Path: C:\Program Files\BackupApp\backup.exe
Parameters: --source "D:\Important Files" --destination "E:\Backup"
```

### Multiple Devices
Create multiple configurations to monitor different USB drives:
- Backup USB → Trigger backup software
- Tools USB → Trigger tool installation
- Media USB → Trigger media player

### Error Handling
The system automatically:
- Checks if software is already running (skips duplicate starts)
- Logs all connection events with timestamps
- Records error messages for debugging
- Provides remediation guidance in health checks

---

## Security Notes

⚠️ **Important:**
1. **Administrator Privileges**: The agent requires admin rights to access WMI
2. **File Paths**: Use absolute paths (e.g., `C:\Program Files\...`)
3. **Credentials**: Don't hardcode passwords in parameters
4. **Firewall**: If running remotely, allow port 5000 through Windows Firewall:
   ```powershell
   netsh advfirewall firewall add rule name="USB Manager" dir=in action=allow protocol=tcp localport=5000
   ```

---

## Uninstallation

### Remove Dashboard
```bash
# Stop the running server (Ctrl+C in terminal)
# Then delete the application directory
rmdir /s usb-device-manager

# Remove database (if local)
# In PostgreSQL: DROP DATABASE usb_manager;
```

### Remove Agent
1. Delete the Python script folder
2. Remove from Windows Task Scheduler if added
3. Delete `start_agent.bat` from Startup folder

---

## Support & Debugging

### Generating Debug Report
If something isn't working:

1. **Open Dashboard Health Check** (appears automatically on startup):
   - Note all check statuses
   - Copy any error messages

2. **Collect logs**:
   - Export logs from the **Logs** page
   - Save screenshot of any errors

3. **Check agent output**:
   - Keep agent terminal window open to see real-time messages
   - Copy any error text

### Common Questions

**Q: Can I run the agent on a different computer?**  
A: Yes! Update `API_URL` in the agent script to point to your dashboard's IP address.

**Q: What if my USB device ID keeps changing?**  
A: Use a more general matching pattern if available, or implement a registration workflow.

**Q: Can I trigger multiple applications?**  
A: Yes, create a batch script (.bat) that launches all your apps, then trigger the batch file.

---

## System Requirements Summary

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **OS** | Windows 10 | Windows 11 |
| **RAM** | 2 GB | 4 GB |
| **Disk** | 500 MB | 1 GB |
| **Python** | 3.8 | 3.11+ |
| **Node.js** | 16 | 18+ |
| **Database** | PostgreSQL 12 | PostgreSQL 14+ |

---

## Next Steps

1. ✅ Install and run the dashboard
2. ✅ Download and configure the agent
3. ✅ Add your USB device configurations
4. ✅ Test with simulated events
5. ✅ Deploy agent on target Windows PC
6. ✅ Monitor logs and verify functionality

Happy monitoring! 🚀
