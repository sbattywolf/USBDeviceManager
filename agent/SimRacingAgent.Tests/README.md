# SimRacing Agent Test Suite

## Overview
Comprehensive PowerShell test suite for the SimRacing Agent following Pester testing framework and professional PowerShell testing practices.

## Test Structure

```
SimRacingAgent.Tests/
├── TestRunner.ps1                  # Main test execution entry point
├── Unit/                          # Unit tests for individual components
│   ├── Core/                      # Core engine tests
│   │   ├── AgentEngine.Tests.ps1
│   │   ├── HealthCheck.Tests.ps1
│   │   └── EventManager.Tests.ps1
│   ├── Modules/                   # Module-specific tests
│   │   ├── DeviceMonitor.Tests.ps1
│   │   ├── SoftwareManager.Tests.ps1
│   │   └── AutomationEngine.Tests.ps1
│   ├── Services/                  # Service integration tests
│   │   ├── ApiService.Tests.ps1
│   │   └── NotificationService.Tests.ps1
│   └── Utils/                     # Utility function tests
│       ├── Config.Tests.ps1
│       └── Utilities.Tests.ps1
├── Integration/                   # Integration tests
│   ├── AgentIntegration.Tests.ps1
│   ├── DeviceWorkflow.Tests.ps1
│   └── ApiIntegration.Tests.ps1
├── Regression/                    # Regression tests
│   ├── AgentRegressionTests.ps1
│   └── CompatibilityTests.ps1
└── Helpers/                       # Test utilities and mocks
    ├── TestHelpers.ps1
    ├── MockData.ps1
    └── TestUtilities.ps1
```

## Test Categories

### Unit Tests
- **Component Isolation**: Test individual functions and modules in isolation
- **Mock Dependencies**: Use mocked external dependencies and system calls
- **Fast Execution**: Quick feedback for development cycles
- **Edge Cases**: Boundary conditions and error scenarios

### Integration Tests  
- **End-to-End Workflows**: Complete device monitoring and automation workflows
- **External Dependencies**: Real system interactions (with safety measures)
- **Cross-Module Testing**: Module interaction and data flow validation
- **Performance Validation**: Resource usage and timing requirements

### Regression Tests
- **Backward Compatibility**: Ensure changes don't break existing functionality
- **Version Migration**: Configuration and data migration testing
- **Platform Compatibility**: Windows version and PowerShell edition testing
- **Long-Running Scenarios**: Extended operation and stability testing

## Running Tests

### All Tests
```powershell
# Run complete test suite
./TestRunner.ps1

# Run with detailed output
./TestRunner.ps1 -Verbose

# Generate test report
./TestRunner.ps1 -GenerateReport
```

### Specific Categories
```powershell
# Unit tests only
./TestRunner.ps1 -Category Unit

# Integration tests
./TestRunner.ps1 -Category Integration

# Regression tests
./TestRunner.ps1 -Category Regression
```

### Individual Test Files
```powershell
# Run specific test file
Invoke-Pester .\Unit\Core\AgentEngine.Tests.ps1

# Run with coverage
Invoke-Pester .\Unit\Core\AgentEngine.Tests.ps1 -CodeCoverage
```

## Test Framework

### Pester Configuration
- **Pester 5.x**: Modern Pester testing framework
- **Code Coverage**: Comprehensive coverage analysis
- **Mocking**: Advanced mocking capabilities for external dependencies
- **Parallel Execution**: Fast test execution with parallel processing

### Custom Test Utilities
- **TestHelpers.ps1**: Common test setup and teardown functions
- **MockData.ps1**: Realistic test data generation
- **TestUtilities.ps1**: Custom assertion and validation functions

## Test Data Management

### Mock Data Generation
```powershell
# Generate mock USB devices
$mockDevices = New-MockUsbDevices -Count 5 -IncludeRacingWheel

# Generate mock software configurations
$mockSoftware = New-MockSoftwareConfig -IncludeGames @("iRacing", "ACC")

# Generate mock automation rules
$mockRules = New-MockAutomationRules -DeviceEvents -SoftwareActions
```

### Test Environment Setup
```powershell
# Setup isolated test environment
Initialize-TestEnvironment

# Cleanup after tests
Remove-TestEnvironment

# Reset agent state
Reset-AgentState
```

## Test Patterns

### Unit Test Example
```powershell
Describe "DeviceMonitor" {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../../Modules/DeviceMonitor.ps1" -Force
        $mockDevices = New-MockUsbDevices -Count 3
    }

    Context "Get-UsbDevices" {
        It "Should return all connected devices" {
            # Arrange
            Mock Get-WmiObject { return $mockDevices }

            # Act
            $result = Get-UsbDevices

            # Assert
            $result | Should -HaveCount 3
            $result[0].Name | Should -Be "Test Racing Wheel"
        }

        It "Should handle no devices gracefully" {
            # Arrange
            Mock Get-WmiObject { return @() }

            # Act
            $result = Get-UsbDevices

            # Assert
            $result | Should -BeNullOrEmpty
            Should -Invoke Get-WmiObject -Times 1
        }
    }
}
```

### Integration Test Example
```powershell
Describe "Agent Integration Workflow" {
    BeforeAll {
        Initialize-TestEnvironment
        Start-TestAgent
    }

    AfterAll {
        Stop-TestAgent
        Remove-TestEnvironment
    }

    It "Should detect device connection and trigger automation" {
        # Arrange
        $automationRule = New-TestAutomationRule -Trigger "DeviceConnected"
        Add-AutomationRule $automationRule

        # Act
        Simulate-DeviceConnection -DeviceId "TEST_WHEEL_001"
        Start-Sleep -Seconds 2

        # Assert
        $executedActions = Get-ExecutedAutomationActions
        $executedActions | Should -HaveCount 1
        $executedActions[0].RuleId | Should -Be $automationRule.Id
    }
}
```

## Continuous Testing

### Test Automation
- **Pre-commit Hooks**: Run unit tests before code commits
- **CI/CD Integration**: Automated testing in build pipelines
- **Scheduled Testing**: Regular regression test execution
- **Performance Monitoring**: Track test execution time trends

### Test Reporting
```powershell
# Generate comprehensive test report
./TestRunner.ps1 -GenerateReport -ReportFormat HTML

# Export test results
./TestRunner.ps1 -ExportResults -Format JUnit

# Coverage analysis
./TestRunner.ps1 -CodeCoverage -CoverageFormat Cobertura
```

## Mock Frameworks

### System Mocks
- **USB Device Simulation**: Mock USB device connections and events
- **Process Mocking**: Simulate software launches and monitoring
- **File System Mocking**: Mock configuration file operations
- **Registry Mocking**: Mock Windows registry interactions

### External Service Mocks
- **API Service Mocks**: Mock HTTP API calls to dashboard server
- **Notification Service Mocks**: Mock email and notification delivery
- **Telemetry Mocks**: Mock metrics collection and reporting

## Performance Testing

### Load Testing Scenarios
```powershell
# Test high-frequency device events
Test-DeviceEventLoad -EventsPerSecond 10 -Duration 60

# Test memory usage over time
Test-MemoryUsage -Duration 3600 -MaxMemoryMB 100

# Test automation rule performance
Test-AutomationRulePerformance -RuleCount 50 -EventFrequency High
```

### Resource Monitoring
- **Memory Usage**: Track memory consumption during tests
- **CPU Usage**: Monitor CPU utilization patterns
- **Execution Time**: Measure test execution performance
- **Resource Cleanup**: Verify proper resource disposal

## Test Environment

### Requirements
- **PowerShell 5.1+**: Compatible with Windows PowerShell and PowerShell Core
- **Pester 5.x**: Modern testing framework
- **Administrative Rights**: Some tests require elevated permissions
- **Test Devices**: Optional physical devices for hardware testing

### Safety Measures
- **Isolated Environment**: Tests run in isolated test environment
- **Non-destructive**: Tests don't modify production configurations
- **Rollback Capability**: Automatic rollback of test changes
- **Resource Protection**: Safeguards against resource exhaustion

## Troubleshooting Tests

### Common Test Issues
```powershell
# Test discovery problems
Get-ChildItem -Path . -Recurse -Filter "*.Tests.ps1" | Test-Path

# Module import issues
Get-Module -ListAvailable | Where-Object Name -like "*Pester*"

# Permission problems
Test-AdminRights

# Mock verification failures
Show-MockCallHistory
```

### Debugging Failed Tests
```powershell
# Run single test with debugging
Invoke-Pester .\Unit\Core\AgentEngine.Tests.ps1 -Debug

# Enable verbose output
$VerbosePreference = "Continue"
Invoke-Pester .\Unit\Core\AgentEngine.Tests.ps1 -Verbose

# Inspect test state
Export-TestState -Path "./TestDebug.json"
```

## Best Practices

### Test Organization
- **Descriptive Names**: Clear test descriptions and naming
- **Logical Grouping**: Organize tests by feature and functionality
- **Consistent Structure**: Standard arrange-act-assert pattern
- **Proper Isolation**: Independent tests without side effects

### Mock Strategy
- **Minimal Mocking**: Mock only external dependencies
- **Realistic Behavior**: Mocks should behave like real components
- **Verification**: Verify mock interactions where appropriate
- **Cleanup**: Proper mock cleanup between tests

### Performance Considerations
- **Fast Execution**: Keep unit tests fast (< 1 second each)
- **Resource Efficiency**: Minimize resource usage in tests
- **Parallel Safety**: Ensure tests can run in parallel safely
- **Cleanup**: Proper resource cleanup and disposal

## Contributing

### Adding New Tests
1. **Create test file** following naming conventions (*.Tests.ps1)
2. **Use standard template** with proper Describe/Context/It structure
3. **Add appropriate mocks** for external dependencies
4. **Include edge cases** and error scenarios
5. **Update test documentation**

### Test Review Checklist
- [ ] Tests follow naming conventions
- [ ] Proper use of mocking
- [ ] Edge cases covered
- [ ] Performance considerations addressed
- [ ] Documentation updated

## Maintenance

### Regular Tasks
- **Update Test Data**: Keep mock data current and realistic
- **Review Performance**: Monitor test execution times
- **Update Dependencies**: Keep testing frameworks current
- **Clean Obsolete Tests**: Remove tests for deprecated features

### Test Health Monitoring
- **Flaky Test Detection**: Identify and fix unreliable tests
- **Coverage Analysis**: Maintain high code coverage
- **Performance Trends**: Track test execution time trends
- **Failure Analysis**: Investigate and resolve test failures