# USB Device Management System

A professional Windows-based application that monitors USB device connections and automatically triggers software execution when specified devices are connected. Features a web-based dashboard for configuration management and a Python agent for Windows hardware monitoring.

## Features

✅ **Web Dashboard**
- Monitor all USB device connections in real-time
- Create and manage USB device configurations
- View comprehensive connection history and logs
- Simulate USB events for testing
- Download Windows Agent script
- Automatic system health checks on startup

✅ **Windows Agent (Python)**
- Monitor actual USB connections on Windows
- Automatic software trigger execution when devices are detected
- Check for already running instances (prevents duplicates)
- Silent execution and window minimization support
- Full error logging and reporting

✅ **Professional Architecture**
- PostgreSQL database for persistent storage
- RESTful API backend (Node.js/Express)
- Modern React frontend with Tailwind CSS
- Real-time health status monitoring
- Comprehensive error handling and remediation guidance

## Quick Start

### 1. **Start the Dashboard** (Easiest for Testing)
```bash
# Install dependencies
npm install

# Start the development server
npm run dev

# Open http://127.0.0.1:5000 in your browser
```

The application will automatically perform health checks on startup and guide you through any issues.

### 2. **Download & Install Windows Agent** (For Production Use)
1. Go to **Agent** page in the dashboard
2. Click **"Download Agent Script"**
   - npm test

3. Follow the comprehensive **INSTALLATION_GUIDE.md** for step-by-step setup

## System Health Checks

The dashboard automatically runs health checks on startup, verifying:
- ✅ Database connectivity
- ✅ API endpoints functionality
- ⚠️ Windows Agent Python dependencies
- ✅ File permissions
- ⚠️ USB device configurations

If issues are detected, you'll see:
- **Critical Issues** (red): Must be fixed before operation
- **Warnings** (yellow): Recommended actions
- **Passed Checks** (green): Components working correctly

Each issue includes:
- Clear description of the problem
- Specific remediation steps
- Helpful debugging information
- One-click copy-to-clipboard for error details

## Directory Structure

```
.
├── client/                    # React Frontend
│   ├── src/
│   │   ├── pages/            # Dashboard, Configs, Logs, Agent pages
│   │   ├── components/       # UI components + HealthCheckModal
│   │   ├── App.tsx           # Main app with health checks
│   │   └── index.css         # Tailwind + theme colors
│   └── index.html
├── server/                    # Node.js Backend
│   ├── routes.ts             # API endpoints + health checks
│   ├── storage.ts            # Database operations
│   ├── db.ts                 # Database connection
│   └── index.ts              # Express server setup
├── shared/                    # Shared Types
│   ├── schema.ts             # Database schema + types
│   └── routes.ts             # API contract definitions
├── INSTALLATION_GUIDE.md      # Comprehensive setup guide
├── README.md                  # This file
└── package.json
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/configs` | List all USB configurations |
| POST | `/api/configs` | Create new configuration |
| PUT | `/api/configs/:id` | Update configuration |
| DELETE | `/api/configs/:id` | Delete configuration |
| GET | `/api/logs` | View all connection logs |
| POST | `/api/logs` | Create log entry |
| DELETE | `/api/logs` | Clear all logs |
| GET | `/api/health` | System health check |
| GET | `/api/agent/download` | Download agent script |

## Database Schema

### `usb_configs` Table
Stores USB device trigger configurations:
- `id` - Primary key
- `deviceId` - USB device identifier (VID:PID)
- `friendlyName` - Human-readable device name
- `port` - Optional specific USB port
- `isEnabled` - Enable/disable monitoring
- `triggerPath` - Path to software executable
- `triggerParams` - Optional command-line arguments
- `runSilently` - Hide application window
- `forceMinimize` - Minimize after launch
- `createdAt`, `updatedAt` - Timestamps

### `usb_logs` Table
Historical record of USB events:
- `id` - Primary key
- `deviceId` - USB device that triggered
- `friendlyName` - Device name
- `eventType` - CONNECTED or DISCONNECTED
- `actionTaken` - TRIGGER_STARTED, IGNORED, or FAILED
- `details` - Error messages or success info
- `timestamp` - Event time

## Configuration Example

**Dashboard Configuration:**
```
Device ID:      1234:5678
Friendly Name:  USB Backup Drive
Trigger Path:   C:\Program Files\BackupSoftware\backup.exe
Parameters:     --auto-sync --exclude-temp
Run Silently:   ✓ Checked
Force Minimize: ✓ Checked
```

When this USB device is detected by the agent, the backup software will launch automatically with the specified parameters, in silent mode, minimized.

## Troubleshooting

### Dashboard Issues
1. **Port 5000 already in use**
   - Change PORT in `.env` file
   - Or kill existing process on port 5000

2. **Database connection error**
   - Verify DATABASE_URL is correct
   - Ensure PostgreSQL is running
   - Check database exists and is accessible

3. **Health check shows failures**
   - Follow the remediation steps in the modal
   - Each issue includes specific fixing instructions

### Agent Issues
1. **Agent won't start**
   - Ensure Python 3.8+ is installed
   - Run: `pip install wmi pywin32 requests`
   - Run PowerShell as Administrator

2. **Software not triggering**
   - Verify Device ID matches config
   - Check trigger path is correct (use absolute path)
   - Confirm software isn't already running (check Task Manager)

3. **Connection errors**
   - Verify API_URL in agent script points to dashboard
   - Check Windows Firewall allows port 5000
   - Test network connectivity between machines

## Security Considerations

- 🔐 Store agent scripts securely - don't share publicly
- 🔐 Use absolute paths for executables
- 🔐 Never hardcode passwords in trigger parameters
- 🔐 Agent requires Administrator privileges to monitor USB
- 🔐 Set up Windows Firewall rules if accessing remotely

## Environment Variables

```env
# Required
DATABASE_URL=postgresql://user:pass@127.0.0.1:5432/dbname

# Optional
PORT=5000                    # Server port (default: 5000)
NODE_ENV=development         # development or production
```

## Deployment

### For Production (Replit Cloud)
1. Push to GitHub
2. Connect Replit to GitHub repository
3. Replit automatically provisions PostgreSQL
4. Deploy with one click
5. Share your dashboard URL with team

### For Windows Desktop
1. Follow **INSTALLATION_GUIDE.md** part 1-2
2. Run agent as Windows Service or Task (see guide)
3. Access dashboard at `http://127.0.0.1:5000`

## Technologies Used

**Frontend:**
- React 18 + Vite
- TailwindCSS + shadcn/ui
- TanStack Query (React Query)
- Wouter (lightweight routing)
- Framer Motion (animations)

**Backend:**
- Node.js + Express
- PostgreSQL + Drizzle ORM
- Zod (schema validation)
- TypeScript

**Windows Agent:**
- Python 3.8+
- WMI (Windows Management Instrumentation)
- PyWin32 (Windows API access)

## Support

For detailed setup instructions, see **INSTALLATION_GUIDE.md**

Common issues and their solutions are documented in the guide, along with:
- Step-by-step installation walkthrough
- Python environment setup
- Windows Agent configuration
- Firewall and security settings
- Auto-start configuration
- Troubleshooting checklist


## Error Handling and Troubleshooting

### Centralized Error Handling
All server errors are handled by a global error handler. This ensures that any unhandled exceptions or API errors are consistently logged and surfaced to the user interface (for client errors) or to the server logs.

### Persistent Error Log
In addition to console output, all server-side errors are written to a persistent log file at:

   data/error.log

This file is automatically created if it does not exist. Each error entry includes a timestamp and the full error stack trace, making it easy to diagnose issues after the fact.

#### How to Use the Error Log
- If something is not working as expected, check `data/error.log` for recent error entries.
- Each entry will include the time, error message, and stack trace.
- This log is especially useful for troubleshooting issues that do not appear in the client UI.

### Client Error Handling
All errors encountered in the client application are surfaced to the user via toast notifications. If you see an error notification, you can check the server's `data/error.log` for more technical details.

### Example Error Log Entry
```
[2025-12-22T14:35:10.123Z] Error: Failed to start process
   at startProcess (server/process.ts:42:15)
   at ...
```

### Troubleshooting Tips
- Always check `data/error.log` first when debugging server issues.
- For client-side issues, look for toast notifications and cross-reference with the error log.
- If the log file grows too large, you can safely delete or archive it; a new one will be created automatically.

For more details on installation and setup, see [INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md).

## Persistence: Fallback Storage, SQLite, and Backups

This application supports multiple persistence backends for maximum reliability:

- **Primary:** PostgreSQL (set `DATABASE_URL`)
- **Fallback:** Embedded JSON file (`data/fallback-db.json`)
- **Optional:** Embedded SQLite (`data/fallback.db`) if `better-sqlite3` is installed and `FALLBACK_SQLITE=1` is set

### Safe Writes and Backups
- All writes to the fallback JSON DB use a temp file and atomic rename for safety.
- Before each write, a timestamped backup is created: `fallback-db.json.bak.<timestamp>`
- Old backups are rotated (default: keep 10, configurable via `FALLBACK_DB_BACKUP_KEEP`)
- On write failure, the last backup is automatically restored.

### Enabling SQLite Fallback
- Install the native dependency:
  ```sh
  npm install --save better-sqlite3
  ```
- Set the environment variable:
  ```sh
  set FALLBACK_SQLITE=1
  # or in .env: FALLBACK_SQLITE=1
  ```
- On next server start, `data/fallback.db` will be used for persistence.

### Migrating JSON → SQLite
- Use the CLI tool:
  ```sh
  node server/tools/migrate_json_to_sqlite.cjs
  ```
- Or use the admin API/backup UI in the dashboard to trigger migration.

### Restoring from Backup
- Use the admin API/backup UI to restore any `.bak` file to `fallback-db.json`.
- The current DB is backed up before restore.

### Benchmarking
- Compare JSON vs SQLite performance:
  ```sh
  npm run benchmark:storage
  ```

See `server/storage.ts` for implementation details and `server/tools/` for migration/benchmark scripts.

## Windows Packaging & Native Dependencies

This project supports packaging the server as a single Windows executable for easy deployment:

- Uses `esbuild` to bundle the server code
- Uses `pkg` to create a standalone `.exe` (Node.js runtime included)
- See `BUILD_WINDOWS.md` for full instructions

### Quick Build Steps

1. Install dependencies:
   ```sh
   npm install
   ```
2. Build and package:
   ```sh
   npm run build:windows
   ```
   The output will be in `dist/device-sentinel.exe`.

3. (Optional) Create a ZIP or NSIS installer:
   ```sh
   npm run package:zip
   npm run package:nsis
   ```

### Native Modules (SQLite)
- If you want to use the embedded SQLite fallback (`better-sqlite3`), you must install it **before** packaging:
  ```sh
  npm install --save better-sqlite3
  ```
- Note: Packaging with native modules may require additional configuration. See the `pkg` and `better-sqlite3` docs for troubleshooting.
- By default, the packaged exe uses file-based fallback storage. For full database support, run the Node.js server with `DATABASE_URL` set.

See `BUILD_WINDOWS.md` for more details and troubleshooting tips.

## License

All code and scripts are provided as-is for personal and organizational use.

---

**Ready to get started?** Open the browser to `http://127.0.0.1:5000` and the health check will guide you through any setup issues!
