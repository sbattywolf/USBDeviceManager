@echo off
set ASPNETCORE_ENVIRONMENT=Development
cd /d "%~dp0\..\server\USBDeviceManager"
rem Allow TEST_PORT env var to override the default port for local dev
if defined TEST_PORT (
	set "PORT=%TEST_PORT%"
) else (
	set "PORT=5000"
)
if defined TEST_HTTPS_PORT (
	set "HTTPS_PORT=%TEST_HTTPS_PORT%"
) else (
	set /A HTTPS_PORT=%PORT%+1
)
start "USBDeviceManager" dotnet run --project "E:\Workspaces\Git\SimRacing\USBDeviceManager\server\USBDeviceManager\USBDeviceManager.csproj" -c Debug --urls "http://localhost:%PORT%;https://localhost:%HTTPS_PORT%"
echo Launched server on ports %PORT%/%HTTPS_PORT% in Development environment.
