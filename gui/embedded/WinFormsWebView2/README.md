# WinForms WebView2 Embedded GUI PoC

This is a minimal Windows Forms proof-of-concept that hosts a `WebView2` control and
navigates to the server preview page at `http://localhost:5000/preview/index.html`.

Prereqs
- .NET 8 SDK
- WebView2 runtime installed on the machine (or the app will attempt to initialize and may prompt the user).

Build & run

```powershell
dotnet build gui\embedded\WinFormsWebView2\WinFormsWebView2.csproj
dotnet run --project gui\embedded\WinFormsWebView2\WinFormsWebView2.csproj
```

Notes
- This PoC assumes the server is already running and serving the preview page. Start the server (e.g. `dotnet run --project server/USBDeviceManager`) before launching the PoC.
- The PoC is intentionally minimal to keep dependencies small. For production, consider WinUI3 + WebView2 or a packaged MSIX with runtime dependencies handled.
