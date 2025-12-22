# SimRacing Agent

## Overview
PowerShell-based monitoring agent for SimRacing hardware and software management. Provides real-time device monitoring, health checking, and automated system management for racing simulation environments.

## Architecture

```
SimRacingAgent/
├── SimRacingAgent.ps1          # Main entry point
├── Core/                       # Core engine components
│   ├── AgentEngine.ps1         # Main agent engine
│   ├── HealthCheck.ps1         # Health monitoring system
│   └── EventManager.ps1        # Event handling and processing
├── Modules/                    # Feature modules
│   ├── DeviceMonitor.ps1       # USB device monitoring
│   ├── SoftwareManager.ps1     # Software lifecycle management
│   └── AutomationEngine.ps1    # Automation rules and triggers
├── Services/                   # External service integrations
│   ├── ApiService.ps1          # HTTP API communication
│   ├── NotificationService.ps1 # Notification delivery
│   └── TelemetryService.ps1    # Telemetry and metrics
├── Utils/                      # Utilities and configuration
│   ├── Config.ps1              # Configuration management
│   ├── Logging.ps1             # Logging framework
│   └── Utilities.ps1           # Common utility functions
├── Tools/                      # Development and maintenance tools
└── Docs/                       # Documentation
```

## Features

### 🖥️ **Device Monitoring**
- Real-time USB device detection and tracking
- Hardware health monitoring and status reporting
- Automatic device configuration and driver management
- Support for racing wheels, pedals, shifters, and custom hardware

### 🎮 **Software Management**
- Automated game and application launching
- Process monitoring and lifecycle management
- Performance optimization and resource management
- Integration with popular racing simulators

### 🤖 **Automation Engine**
- Rule-based automation for device events
- Trigger-action workflow automation
- Custom scripting and macro support
- Multi-condition logic and dependencies

### 📊 **Health & Monitoring**
- System performance monitoring
- Predictive health analytics
- Resource usage optimization
- Comprehensive logging and metrics

## Quick Start

### Installation
```powershell
# Clone repository
git clone <repository-url>
cd SimRacingAgent

# Install dependencies
./Tools/Install-Dependencies.ps1

# Configure agent
./SimRacingAgent.ps1 -Configure
```

### Basic Usage
```powershell
# Start monitoring
./SimRacingAgent.ps1 -Start

# Check status
./SimRacingAgent.ps1 -Status

# Stop agent
./SimRacingAgent.ps1 -Stop
```

### Configuration
```powershell
# Edit configuration
notepad ./Utils/agent-config.json

# Validate configuration
./SimRacingAgent.ps1 -ValidateConfig

# Reset to defaults
./SimRacingAgent.ps1 -ResetConfig
```

## API Integration

The agent integrates with the SimRacing Dashboard Server for centralized management:

```powershell
# Configure server connection
$config = @{
    ServerUrl = "http://localhost:5000"
    ApiKey = "your-api-key"
    EnableTelemetry = $true
}

./SimRacingAgent.ps1 -ConfigureServer $config
```

## Development

### Testing
```powershell
# Run all tests
./SimRacingAgent.Tests/TestRunner.ps1

# Run specific test category
./SimRacingAgent.Tests/TestRunner.ps1 -Category Unit
./SimRacingAgent.Tests/TestRunner.ps1 -Category Integration
./SimRacingAgent.Tests/TestRunner.ps1 -Category Regression
```

### Debugging
```powershell
# Enable debug mode
./SimRacingAgent.ps1 -Debug -Verbose

# Check logs
Get-Content ./Logs/agent-*.log -Tail 50 -Wait
```

## Configuration

### Agent Settings
- **MonitoringInterval**: Device polling frequency (default: 5 seconds)
- **HealthCheckInterval**: Health monitoring frequency (default: 30 seconds)
- **LogLevel**: Logging verbosity (Info, Debug, Verbose)
- **AutoRestart**: Automatic restart on failures
- **TelemetryEnabled**: Send metrics to dashboard server

### Device Configuration
- **SupportedDevices**: List of monitored device types
- **DeviceActions**: Actions triggered by device events
- **HealthThresholds**: Performance and health limits
- **AutoConfiguration**: Automatic device setup

### Software Integration
- **ManagedSoftware**: Applications under agent control
- **LaunchSequences**: Automated startup procedures
- **ProcessMonitoring**: Resource usage tracking
- **PerformanceOptimization**: System tuning settings

## Monitoring & Metrics

The agent provides comprehensive monitoring capabilities:

- **Device Status**: Connection state, performance metrics
- **System Health**: CPU, memory, disk usage
- **Application Performance**: Frame rates, response times
- **Network Activity**: API communication, data transfer
- **Error Tracking**: Failures, recovery attempts

## Troubleshooting

### Common Issues

**Agent Won't Start**
```powershell
# Check execution policy
Get-ExecutionPolicy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Verify dependencies
./Tools/Test-Dependencies.ps1
```

**Device Not Detected**
```powershell
# Scan for devices manually
./SimRacingAgent.ps1 -ScanDevices -Verbose

# Check device drivers
./Tools/Check-Drivers.ps1
```

**High CPU Usage**
```powershell
# Reduce monitoring frequency
./SimRacingAgent.ps1 -SetInterval 10

# Check for memory leaks
./Tools/Monitor-Performance.ps1
```

### Log Analysis
```powershell
# Search for errors
Select-String -Path "./Logs/*.log" -Pattern "ERROR|CRITICAL"

# Monitor real-time
Get-Content "./Logs/agent-$(Get-Date -Format 'yyyy-MM-dd').log" -Wait -Tail 20
```

## Contributing

1. **Fork the repository**
2. **Create feature branch**: `git checkout -b feature/new-feature`
3. **Add tests for new functionality**
4. **Run test suite**: `./SimRacingAgent.Tests/TestRunner.ps1`
5. **Submit pull request**

### Code Standards
- Follow PowerShell best practices
- Include comprehensive error handling
- Add unit tests for new functions
- Update documentation for changes
- Use consistent naming conventions

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

- **Documentation**: See `./Docs/` directory
- **Issues**: Submit via GitHub Issues
- **Discussions**: GitHub Discussions
- **Wiki**: Comprehensive guides and examples