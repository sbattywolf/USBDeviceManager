# Windows Agent Documentation

## Overview
The Windows Agent provides intelligent system monitoring with advanced health check capabilities. This documentation covers the complete system architecture, features, and usage.

## Quick Reference

### Getting Started
```powershell
cd agent
.\SimRacingAgent.ps1
```

### Key Features
- **PUT-based Health Checks**: On-demand system analysis
- **USB Device Monitoring**: Real-time device tracking with change detection
- **Process Management**: Intelligent lifecycle management with health scoring
- **REST API**: Complete system control via HTTP endpoints
- **Resource Efficient**: 90%+ reduction in background resource usage

### Terminal Commands
- `1` - Comprehensive Health Check
- `2` - USB Health Check  
- `3` - Process Health Check
- `4` - Auto Health Check Demo
- `H` - Help, `S` - Status, `Q` - Quit

### API Endpoints
- `PUT /healthcheck` - Complete system health
- `PUT /healthcheck/usb` - USB device analysis
- `PUT /healthcheck/processes` - Process health analysis

## Architecture

### Module Structure
```
agent/src/
├── core/
│   ├── AgentCore.psm1      # Instance management, logging
│   └── ConfigManager.psm1  # Configuration handling
├── modules/
│   ├── USBMonitor.psm1     # USB device monitoring
│   └── ProcessManager.psm1 # Process lifecycle management
└── api/
    └── APIServer.psm1      # REST API server
```

### Health Check System
The system implements an intelligent PUT-based architecture that:
- Provides real-time data collection only when requested
- Uses adaptive polling intervals based on system activity
- Delivers comprehensive performance analytics
- Maintains zero background resource usage when idle

### Configuration Management
JSON-based configuration with runtime updates:
- Health check polling intervals
- USB monitoring sensitivity  
- Process management policies
- API server settings
- Logging configuration

## Advanced Features

### Intelligent Analytics
- **Health Scoring**: 0-100 rating for process health
- **Leak Detection**: Automatic memory and handle leak identification
- **Activity Classification**: Smart categorization (Low/Normal/High/Critical)
- **Predictive Insights**: Performance optimization recommendations

### Performance Monitoring
- Sub-100ms response times for health checks
- Millisecond-precision timing for all operations
- Resource usage analysis (Memory, CPU, handles)
- Historical trend analysis with 50-point history

### Adaptive Behavior
- **Smart Polling**: Adjusts intervals based on system activity
- **Activity Detection**: Responds faster during high-activity periods
- **Resource Optimization**: Scales down during idle periods
- **Predictive Scheduling**: Recommends optimal check intervals

## Testing and Development

### Test Suite
Located in `agent/tests/`:
- Unit tests for each module
- Integration tests for API endpoints
- Performance benchmarks
- Configuration validation

### Development Workflow
1. Module development in appropriate `src/` subdirectory
2. Add corresponding test file in `tests/`
3. Update main agent imports if needed
4. Document changes in relevant README

## Deployment

### Installation
Installation tools available in `agent/tools/`:
- `Install-Agent.ps1` - Automated agent deployment
- `Uninstall-Agent.ps1` - Clean removal utility

### Configuration
Default configuration provides optimal settings for most environments. Customize via:
- JSON configuration files
- Runtime API updates
- Command-line parameters

## Troubleshooting

### Common Issues
- **Module Import Errors**: Verify PowerShell execution policy
- **Permission Errors**: Run with appropriate administrator privileges
- **Port Conflicts**: Check API port availability (default: 8080)

### Logging
Comprehensive logging system provides:
- Component-specific log entries
- Configurable log levels (Debug, Info, Warning, Error)
- File and console output options
- Security-aware log sanitization

## Performance Considerations

### Resource Usage
- **Memory**: Minimal footprint with intelligent caching
- **CPU**: On-demand processing only
- **Network**: Local-only operations for security
- **Storage**: Efficient JSON-based data storage

### Scalability
The system is designed to:
- Handle large numbers of USB devices efficiently
- Manage multiple processes with intelligent scoring
- Scale health check frequency based on system load
- Maintain performance as monitored items increase

For detailed technical information, see the specific module documentation in each component directory.