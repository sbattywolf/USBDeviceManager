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
