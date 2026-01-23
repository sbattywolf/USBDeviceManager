# USB Device Manager Agent

# USB Device Manager Agent

## Overview
PowerShell-based monitoring agent for USB Device Manager hardware and software management. Provides real-time device monitoring, health checking, and automated system management for racing simulation environments.

## Project Structure

```
agent/
├── SimRacingAgent/              # Main agent implementation
│   ├── SimRacingAgent.ps1       # Main entry point
│   ├── Core/                    # Core engine components
│   ├── Modules/                 # Feature modules
│   ├── Services/                # External service integrations
│   ├── Utils/                   # Utilities and configuration
│   ├── Tools/                   # Development tools
│   ├── Docs/                    # Detailed documentation
│   └── README.md               # Agent-specific documentation
├── SimRacingAgent.Tests/        # Comprehensive test suite
│   ├── TestRunner.ps1          # Test execution entry point
│   ├── Unit/                   # Unit tests
│   ├── Integration/            # Integration tests
│   ├── Regression/             # Regression tests
│   ├── Helpers/                # Test utilities
│   └── README.md              # Testing documentation
└── README.md                  # This file
```

## Quick Start

### Installation
```powershell
# Navigate to agent directory
cd agent/SimRacingAgent

# Install and configure
./SimRacingAgent.ps1 -Configure
```

### Testing
```powershell
# Run complete test suite
cd ../SimRacingAgent.Tests
./TestRunner.ps1

# Run specific categories
./TestRunner.ps1 -Category Unit
```

## Features

- **🖥️ Device Monitoring**: Real-time USB device detection and tracking
- **🎮 Software Management**: Automated game and application lifecycle
- **🤖 Automation Engine**: Rule-based automation and workflows
- **📊 Health Monitoring**: System performance and predictive analytics
- **🔗 API Integration**: Seamless integration with USB Device Manager Server

## Documentation

- **Agent Implementation**: See `SimRacingAgent/README.md`
- **Testing Guide**: See `SimRacingAgent.Tests/README.md`
- **API Documentation**: See `SimRacingAgent/Docs/`
- **Configuration Guide**: See `SimRacingAgent/Docs/Configuration.md`

## Development

The agent follows PowerShell best practices and includes:

- **Comprehensive Testing**: Unit, integration, and regression tests
- **Modular Architecture**: Separated concerns and clean interfaces
- **Error Handling**: Robust error handling and recovery
- **Performance Optimization**: Efficient resource usage and monitoring
- **Documentation**: Extensive documentation and examples

For detailed development information, see the respective README files in each subdirectory.

### Intelligent Analytics
- **Health scoring**: 0-100 intelligent process health rating
- **Leak detection**: Automatic memory and handle leak identification
- **Activity classification**: Smart categorization (Low/Normal/High/Critical)
- **Predictive insights**: Recommendations for optimal system performance

## Terminal Interface

### Health Check Commands
- `1` - Comprehensive Health Check
- `2` - USB Health Check
- `3` - Process Health Check  
- `4` - Auto Health Check Demo

### Standard Commands
- `H` - Help
- `S` - Status
- `U` - USB Devices
- `P` - Managed Processes
- `C` - Configuration
- `Q` - Quit

## REST API Endpoints

- `PUT /healthcheck` - Complete system health
- `PUT /healthcheck/usb` - USB-specific health
- `PUT /healthcheck/processes` - Process-specific health

### Sample Response
```json
{
  "usb": {
    "DeviceCount": 7,
    "Activity": "High",
    "Performance": { "TotalDuration": 85 }
  },
  "processes": {
    "Analytics": {
      "HealthyProcesses": 4,
      "UnhealthyProcesses": 0
    }
  }
}
```

## Configuration

Configuration is managed through the ConfigManager module with JSON-based storage and runtime updates. Key settings include:

- Health check polling intervals
- USB monitoring sensitivity
- Process management policies
- API server configuration
- Logging preferences

## Agent Identity and Modes

### Agent identity
- Each agent instance exposes a unique `AgentId` (GUID) used when registering and heartbeating to the server.
- The agent also reports a `HostId` / `MachineId` (derived from machine-specific identifiers) so the server can enforce one-agent-per-PC rules.
- The agent's persistent configuration lives in a JSON file under the agent directory (see `ConfigManager` module).

### AgentMode
- `External`: the agent runs standalone (default). It will attempt to connect to the configured server and register/heartbeat.
- `Embedded`: the server may host an embedded agent as a child process. When an embedded agent is active the server rejects remote agent heartbeats to enforce a single active agent per host.
- `Disabled`: agent functionality is disabled and the server will reject heartbeats/registrations.

To change `AgentMode`:

- Via Server UI: Open Dashboard → Settings → Agent and change `AgentMode` (recommended).
- Via configuration: edit `server/config/service-config.json` (or `ServiceConfig` persisted path) and set `AgentMode` to `External`, `Embedded`, or `Disabled`.

Notes:
- If you need a remote agent to register on a host currently hosting an embedded agent, stop the embedded agent first via the Dashboard, then switch `AgentMode` to `External` and save.
- The server responds with HTTP `409 Conflict` when rejecting a heartbeat due to an active embedded agent, and HTTP `403 Forbidden` when agent functionality is disabled.

## File Structure

```
agent/
├── SimRacingAgent.ps1   # Main executable
├── src/
│   ├── core/           # Essential functionality
│   ├── modules/        # Monitoring capabilities
│   └── api/            # REST interface
├── docs/               # Documentation
└── tools/              # Installation utilities
```

## Testing

Comprehensive test suite located in `tests/` directory:
- Unit tests for each module
- Integration tests for API endpoints
- Performance benchmarks
- Configuration validation tests

## Installation

Installation scripts and tools are available in the `tools/` directory for automated deployment and configuration.