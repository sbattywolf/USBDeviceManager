Windows Packaging (quick start)

This project includes a convenience packaging flow that bundles the server into a single Windows executable (file-fallback mode).

How it works
- `server/pack-entry.ts` is a minimal production entrypoint (no Vite/dev imports).
- `npm run bundle:server` uses `esbuild` to create `dist/server.js`.
- `npm run package:win` uses `pkg` to create `dist/device-sentinel.exe` (Node.js runtime baked in).

Build steps

1. Install dependencies:

```powershell
npm install
```

2. Bundle and package (creates `dist/device-sentinel.exe`):

```powershell
npm run build:windows
```

Run the executable

```powershell
.\dist\device-sentinel.exe
```

Notes & limitations
- The packaged exe targets the file-based fallback storage. To use an external Postgres DB, run the Node server locally with `DATABASE_URL` set instead of the packaged binary.
- The build bundles the server code only (no client Vite dev server). If you need a single-bundle that serves the client assets, build the client separately and place the `client/dist` files under `dist/static` before running the exe.
- Native database drivers or other native dependencies (e.g., `better-sqlite3`) are not included — building with them may require additional steps.

If you want, I can produce an NSIS installer wrapper or create a ZIP with the exe and a ready-to-run static folder. Which would you prefer?

Packaging options added:

- ZIP (recommended quick distribution):
	- `npm run bundle:server` to bundle `dist/server.js`.
	- `npm run package:win` to produce `dist/device-sentinel.exe` (already done by `build:windows`).
	- `npm run package:zip` will create `release/device-sentinel.zip` containing the `dist` folder.

- NSIS installer (optional):
	- `device-sentinel.nsi` is included at the project root.
	- To build the installer, install NSIS (https://nsis.sourceforge.io) and run:

```powershell
npm run package:nsis
```

This attempts to run `makensis device-sentinel.nsi` and will error if NSIS is not installed. The installer places `device-sentinel.exe` under `Program Files\\Device Sentinel` and creates a desktop shortcut.
