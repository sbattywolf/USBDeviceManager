PyQt Desktop GUI scaffold

This is a minimal PyQt6-based desktop GUI scaffold that talks to the existing server HTTP API
provided by the project. It is intended as a starting point to rebuild the desktop UI using the
reference PyQt implementation.

Quick start (Windows PowerShell):

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python main.py --api http://localhost:5000
```

The app expects the server to expose endpoints like `/api/devices` and `/api/software` similar to
the Blazor frontend. Adjust `--api` to point to your running server.

Logs and Screenshot Thumbnail
-----------------------------

The Logs tab includes a small inline thumbnail preview of the most recent diagnostic
screenshot captured by the application (saved to `logs/screenshots/`). When the app
captures a screenshot (for example on unhandled exceptions or specific UI errors) the
path is appended to `logs/desktop_activity.log` and the thumbnail will refresh when
you open the Logs tab or when new log entries are written.

To open the full-size image in your system viewer, click the `View Latest Screenshot`
button in the Logs tab.

Notes:
- Screenshots are saved as PNG files under `logs/screenshots/`.
- If you run the app in a temporary or CI environment, ensure a visible display
	(or use a headless Qt setup) for screenshots to be captured successfully.
