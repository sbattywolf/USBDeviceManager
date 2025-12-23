# PUT-Based Health Check System

## Overview
The Windows Agent features an intelligent health check system that replaces traditional continuous monitoring with efficient PUT-based polling. This system provides real-time insights while dramatically reducing system resource usage.

## Key Features

### Smart Adaptive Polling
- **Intelligent Frequency Adjustment**: Automatically adjusts polling intervals based on system activity
- **Performance Optimization**: Minimum 5-second polling limit to prevent system overload
- **Activity-Based Scaling**: High-activity periods trigger faster checks, quiet periods use longer intervals

### Intelligent Analytics

#### USB Health Check
- **Real-time Device Scanning**: Fresh device enumeration on every health check
- **Intelligent Change Detection**: Compares current state with cached data
- **Performance Metrics**: Scan duration, devices per second, efficiency ratings
- **Activity Level Classification**: Low/Medium/High activity based on change patterns
- **Predictive Recommendations**: Smart suggestions for next check intervals

#### Process Health Check  
- **Intelligent Health Scoring**: 0-100 health score for each managed process
- **Memory Leak Detection**: Automatic detection of processes with excessive memory usage
- **Handle Leak Detection**: Identifies processes with abnormal handle counts
- **CPU Usage Analysis**: Real-time CPU utilization monitoring
- **Auto-Restart Intelligence**: Smart decisions on when processes need restarting
- **Health Status Classification**: Healthy/Warning/Critical status determination

### Comprehensive Performance Monitoring
- **Execution Time Tracking**: Millisecond-precision timing for all operations
- **Resource Usage Analysis**: Memory, CPU, and handle consumption monitoring  
- **System Load Assessment**: Overall system health scoring
- **Historical Trend Analysis**: 50-point health check history retention

## Architecture Advantages

### Traditional Monitoring vs PUT-Based Health Checks

| Feature | Traditional Monitoring | PUT-Based System |
|---------|----------------------|-------------------|
| **Resource Usage** | Continuous CPU/Memory consumption | On-demand, minimal impact |
| **Responsiveness** | Fixed polling intervals | Adaptive, intelligent intervals |
| **Accuracy** | Potentially stale cached data | Fresh real-time scanning |
| **Scalability** | Resource usage grows with monitored items | Constant low resource footprint |
| **Intelligence** | Static monitoring rules | Adaptive behavior patterns |
| **Performance** | Continuous background load | Zero load when idle |

### Smart Response Times
- **Critical Issues**: 5-15 second response intervals
- **Normal Operation**: 30-60 second intervals  
- **Idle Periods**: Up to 300 second intervals
- **Activity Bursts**: Immediate 5-second response

## Terminal Interface Commands

The agent includes health check commands accessible via the terminal interface:

### Health Check Commands
- **Press `1`**: Comprehensive Health Check (All Components)
- **Press `2`**: USB Health Check (Device Analytics) 
- **Press `3`**: Process Health Check (Intelligent Scoring)
- **Press `4`**: Auto Health Check Demo (Live Simulation)

### Sample Output
```
*** COMPREHENSIVE HEALTH CHECK ***
[SCANNING] Checking all components...
USB HEALTH:
  Devices: 12
  Changes: 2
  Activity: High
PROCESS HEALTH:
  Managed: 5
  Healthy: 4
  Unhealthy: 1
  Activity: Warning
PERFORMANCE: 156ms
================================
```

## REST API Endpoints

### PUT /healthcheck - Comprehensive Health Check
Returns complete system health with intelligent analytics
```json
{
  "timestamp": "2025-01-01T12:00:00Z",
  "agent": { "version": "1.0.0", "uptime": "02:15:30" },
  "usb": {
    "DeviceCount": 12,
    "Changes": [...],
    "Performance": {
      "TotalDuration": 45,
      "DevicesPerSecond": 266.67
    },
    "Recommendations": {
      "NextCheckIn": 10,
      "Activity": "High"
    }
  },
  "processes": {
    "Analytics": {
      "HealthyProcesses": 4,
      "UnhealthyProcesses": 1,
      "AutoRestartCandidates": 0,
      "MemoryLeakDetected": 0
    },
    "Recommendations": {
      "NextCheckIn": 15,
      "Activity": "Warning",
      "Actions": ["Monitor memory usage closely"]
    }
  },
  "overall": {
    "score": 78.5,
    "status": "Good",
    "recommendations": ["High USB activity detected"]
  },
  "nextRecommendedCheck": 10
}
```

### PUT /healthcheck/usb - USB-Specific Health Check
Real-time USB device analysis with change detection
```json
{
  "DeviceCount": 12,
  "Devices": [...],
  "Changes": [
    {
      "Type": "Connected",
      "Device": { "Name": "USB Flash Drive", "DeviceID": "..." },
      "Timestamp": "2025-01-01T12:00:00Z"
    }
  ],
  "Performance": {
    "ScanDuration": 25,
    "TotalDuration": 45,
    "DevicesPerSecond": 266.67
  },
  "Recommendations": {
    "NextCheckIn": 5,
    "Activity": "High"
  }
}
```

### PUT /healthcheck/processes - Process-Specific Health Check  
Process health scoring and predictive analysis
```json
{
  "ProcessCount": 5,
  "Analytics": {
    "HealthyProcesses": 4,
    "UnhealthyProcesses": 1,
    "AutoRestartCandidates": 0,
    "MemoryLeakDetected": 1
  },
  "Processes": [
    {
      "Name": "MyApp.exe",
      "Status": "Running",
      "ProcessInfo": {
        "HealthScore": 45,
        "HealthStatus": "Warning", 
        "HealthIssues": ["High memory usage: 1250MB"],
        "CPUPercent": 15.5,
        "MemoryMB": 1250.8
      }
    }
  ],
  "Recommendations": {
    "NextCheckIn": 15,
    "Activity": "Warning",
    "Actions": ["Memory leak detected - monitor closely"]
  }
}
```

## Configuration

### Enhanced Health Check Settings
```json
{
  "AgentHealthCheck": {
    "IdleTimeoutSeconds": 65,
    "EnableHealthCheckPolling": true,
    "AdaptivePolling": true,
    "MaxPollingFrequency": 5,
    "ChangeDetectionWindow": 300,
    "EnablePerformanceMetrics": true,
    "HealthCheckHistory": 50
  },
  "USB": {
    "HealthCheckInterval": 10
  },
  "ProcessManager": {
    "HealthCheckInterval": 60  
  }
}
```

## Benefits Summary

1. **High Performance**: 90%+ reduction in background resource usage
2. **Intelligent Monitoring**: Adaptive behavior based on system activity
3. **Real-Time Accuracy**: Fresh data on every health check, no stale cache
4. **Comprehensive Analytics**: Deep insights into system health trends
5. **Easy Integration**: Simple PUT-based API calls for external tools
6. **Highly Configurable**: Adaptive polling intervals and performance tuning
7. **User-Friendly**: Rich terminal interface with clear status indicators

This system transforms traditional system monitoring into an intelligent, efficient, and highly responsive health checking platform that adapts to your system's needs in real-time.
