# SimRacing Dashboard Server

A comprehensive monitoring and automation server for SimRacing environments with USB device management, software control, and rule-based automation.

## 🚀 **Features**

### **Core Functionality**
1. **Monitoring Dashboard** - Real-time status monitoring for all connected devices and software
2. **USB Device Configuration** - Manage tracked devices and monitoring rules
3. **Software Management** - Control applications with start/stop/restart commands
4. **Configuration Management** - Multiple configuration tabs for different functionalities  
5. **Device-Software Correlation** - Automation rules based on USB device connections
6. **HTTP API** - RESTful API for all operations
7. **Multi-Platform Support** - Windows 11, Android (future), HomeAssistant plugin (future)

### **Technical Architecture**
- **Framework**: ASP.NET Core 8.0
- **Database**: SQLite (file-based, lightweight)
- **API**: RESTful HTTP endpoints
- **UI**: Blazor Server for real-time dashboard
- **Cross-Platform**: .NET 8 runtime

## 📋 **Requirements**

### **Core Requirements**
- Windows 11 (primary target)
- .NET 8 Runtime
- SQLite database
- HTTP API access
- Intranet-only operation (no security)

### **Future Extensions (TODO)**
- MQTT message broker integration
- HomeAssistant plugin/addon
- Android companion app
- Advanced automation scripting

## 🏗️ **Project Structure**

```
server/
├── SimRacingDashboard/              # Main ASP.NET Core application
│   ├── Controllers/                 # HTTP API controllers
│   ├── Models/                      # Data models
│   ├── Services/                    # Business logic services
│   ├── Data/                        # Database context and configurations
│   ├── Views/                       # Blazor components and pages
│   ├── wwwroot/                     # Static files (CSS, JS, images)
│   └── Program.cs                   # Application entry point
├── SimRacingDashboard.Data/         # Data layer project
├── SimRacingDashboard.Core/         # Core models and interfaces
└── docker/                         # Docker configurations for deployment
```