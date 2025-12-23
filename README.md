# USB Device Manager

A comprehensive USB Device Manager for hardware monitoring, software management, and automation with intelligent health monitoring and a simple dashboard interface.

## Overview

This project provides a complete USB Device Manager environment consisting of:

- **PowerShell Agent (USB Device Manager Agent)**: Real-time device monitoring and automation
- **ASP.NET Core Dashboard Server**: Web-based management interface and HTTP APIs
- **Comprehensive Testing**: Professional test suites for both components

## Project Structure

```
USBMonitor/
├── agent/                          # PowerShell Agent Implementation
│   ├── SimRacingAgent/             # Main agent implementation (folder: SimRacingAgent)
│   │   ├── SimRacingAgent.ps1      # Main entry point (USB Device Manager Agent)
│   │   ├── Core/                   # Core engine components
│   │   ├── Modules/                # Feature modules (USB, Process, Automation)
│   │   ├── Services/               # External integrations (API, Notifications)
│   │   ├── Utils/                  # Utilities and configuration
│   │   ├── Tools/                  # Development tools
│   │   └── Docs/                   # Detailed documentation
│   ├── SimRacingAgent.Tests/       # Comprehensive test suite
│   │   ├── TestRunner.ps1          # Test execution entry point
│   │   ├── Unit/                   # Unit tests
│   │   ├── Integration/            # Integration tests
│   │   ├── Regression/             # Regression tests
│   │   └── Helpers/                # Test utilities
│   └── README.md                   # Agent overview and quick start
├── server/                         # ASP.NET Core Server
│   ├── USBDeviceManager/           # Main server implementation
│   │   ├── Controllers/            # HTTP API controllers
│   │   ├── Models/                 # Data models
│   │   ├── Data/                   # Entity Framework context
│   │   ├── Components/             # Blazor UI components
│   │   ├── Hubs/                   # SignalR hubs
│   │   └── Program.cs              # Server entry point
│   ├── USBDeviceManager.Tests/     # Comprehensive test suite
│   │   ├── Unit/                   # Unit tests
│   │   ├── Integration/            # Integration tests
│   │   ├── Functional/             # End-to-end functional tests
│   │   ├── Fixtures/               # Test infrastructure
│   │   └── Helpers/                # Test utilities
│   └── README.md                   # Server documentation
└── shared/                         # Shared resources
    ├── config/                     # Common configuration files
    └── docs/                       # Project-wide documentation
```

## Features

### 🖥️ **PowerShell Agent**
- **Device Monitoring**: Real-time USB device detection and health tracking
- **Software Management**: Automated game and application lifecycle management
- **Automation Engine**: Rule-based automation with device event triggers
- **Health Analytics**: Advanced system performance monitoring and analytics
- **API Integration**: Seamless communication with dashboard server

### 🌐 **Dashboard Server**
- **Web Dashboard**: Modern Blazor UI with real-time updates
- **HTTP APIs**: RESTful APIs for all functionality with Swagger documentation
- **Database Storage**: SQLite database for configuration and monitoring data
- **Real-time Updates**: SignalR for live dashboard updates
- **Multi-platform**: .NET 8 cross-platform support

### 🧪 **Professional Testing**
- **Comprehensive Coverage**: Unit, integration, and functional tests
- **Realistic Test Data**: Domain-specific test data generation
- **Performance Testing**: Load testing and performance validation
- **CI/CD Ready**: Automated testing and reporting capabilities

## Quick Start

### Agent Setup (USB Device Manager Agent)
```powershell
# Navigate to agent
cd agent/SimRacingAgent

# Configure and start agent
./SimRacingAgent.ps1 -Configure
./SimRacingAgent.ps1 -Start
```

### Server Setup
```powershell
# USB Device Manager

A comprehensive USB Device Manager for hardware monitoring, software management, and automation with intelligent health monitoring and a simple dashboard interface.

## Overview

This project provides a complete environment management system consisting of:

- **PowerShell Agent**: Real-time device monitoring and automation
- **ASP.NET Core Server**: Web-based management interface and HTTP APIs
- **Comprehensive Testing**: Professional test suites for both components

## Project Structure

```
USBMonitor/
├── agent/                          # PowerShell Agent Implementation
│   ├── SimRacingAgent/             # Main agent implementation
│   │   ├── SimRacingAgent.ps1      # Main entry point
│   │   ├── Core/                   # Core engine components
│   │   ├── Modules/                # Feature modules (USB, Process, Automation)
│   │   ├── Services/               # External integrations (API, Notifications)
│   │   ├── Utils/                  # Utilities and configuration
│   │   ├── Tools/                  # Development tools
│   │   └── Docs/                   # Detailed documentation
│   ├── SimRacingAgent.Tests/       # Comprehensive test suite
│   │   ├── TestRunner.ps1          # Test execution entry point
│   │   ├── Unit/                   # Unit tests
│   │   ├── Integration/            # Integration tests
│   │   ├── Regression/             # Regression tests
│   │   └── Helpers/                # Test utilities
│   └── README.md                   # Agent overview and quick start
├── server/                         # ASP.NET Core Server
│   ├── USBDeviceManager/           # Main server implementation
│   │   ├── Controllers/            # HTTP API controllers
│   │   ├── Models/                 # Data models
│   │   ├── Data/                   # Entity Framework context
│   │   ├── Components/             # Blazor UI components
│   │   ├── Hubs/                   # SignalR hubs
│   │   └── Program.cs              # Server entry point
│   ├── USBDeviceManager.Tests/     # Comprehensive test suite
│   │   ├── Unit/                   # Unit tests
│   │   ├── Integration/            # Integration tests
│   │   ├── Functional/             # End-to-end functional tests
│   │   ├── Fixtures/               # Test infrastructure
│   │   └── Helpers/                # Test utilities
│   └── README.md                   # Server documentation
└── shared/                         # Shared resources
    ├── config/                     # Common configuration files
    └── docs/                       # Project-wide documentation
```