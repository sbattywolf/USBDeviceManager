@echo off
set ASPNETCORE_ENVIRONMENT=Development
cd /d "%~dp0\..\server\USBDeviceManager"
start "USBDeviceManager" dotnet run --project "E:\Workspaces\Git\SimRacing\USBDeviceManager\server\USBDeviceManager\USBDeviceManager.csproj" -c Debug --urls "http://localhost:5000;https://localhost:5001"
echo Launched server in Development environment.
