# SimRacing Dashboard Test Suite

## Overview
Comprehensive test suite for the SimRacing Dashboard Server following .NET testing best practices and patterns inspired by the PowerShell agent testing architecture.

## Test Structure

```
SimRacingDashboard.Tests/
├── Unit/                           # Unit tests for individual components
│   ├── SimRacingContextTests.cs   # Database context and entity tests
│   ├── DevicesControllerTests.cs  # Device API controller tests
│   ├── SoftwareControllerTests.cs # Software API controller tests
│   ├── AutomationControllerTests.cs # Automation API controller tests
│   └── MonitoringControllerTests.cs # Monitoring API controller tests
├── Integration/                    # Integration tests for API endpoints
│   ├── DevicesApiIntegrationTests.cs # Full HTTP API integration tests
│   ├── SoftwareApiIntegrationTests.cs
│   ├── AutomationApiIntegrationTests.cs
│   └── MonitoringApiIntegrationTests.cs
├── Functional/                     # End-to-end functional tests
│   ├── DashboardFunctionalTests.cs # Complete workflow testing
│   ├── AutomationWorkflowTests.cs  # Multi-step automation scenarios
│   └── PerformanceTests.cs         # Load and performance testing
├── Fixtures/                       # Test infrastructure
│   ├── SimRacingTestFactory.cs     # Test application factory
│   └── DatabaseFixture.cs          # Database test utilities
└── Helpers/                        # Test utilities
    ├── TestDataGenerator.cs        # Realistic test data generation
    ├── ApiTestHelpers.cs           # HTTP client utilities
    └── AssertionExtensions.cs      # Custom FluentAssertions
```

## Test Categories

### Unit Tests
- **Database Operations**: Entity Framework context, relationships, constraints
- **Controller Logic**: API endpoint behavior, validation, error handling
- **Business Logic**: Service layer functionality, data transformations
- **Model Validation**: Entity validation rules and data integrity

### Integration Tests
- **API Endpoints**: Full HTTP request/response cycles with database
- **Cross-Controller Operations**: Multi-endpoint workflows
- **Database Integration**: Real database operations with transaction handling
- **Error Handling**: Exception propagation and error responses

### Functional Tests
- **End-to-End Scenarios**: Complete user workflows from UI to database
- **Automation Workflows**: Device events triggering software automation
- **System Integration**: Multiple components working together
- **Performance Testing**: Load testing and response time validation

## Test Technologies

### Core Testing Framework
- **xUnit**: Primary testing framework
- **FluentAssertions**: Readable assertion syntax
- **Microsoft.AspNetCore.Mvc.Testing**: Integration testing support

### Test Data Management
- **Bogus**: Realistic fake data generation
- **AutoFixture**: Object creation and customization
- **Entity Framework InMemory**: Fast in-memory database for testing

### Mocking and Isolation
- **Moq**: Mocking framework for dependencies
- **Microsoft.EntityFrameworkCore.InMemory**: Database isolation
- **TestContainers**: External service testing (optional)

### Performance and Monitoring
- **System.Diagnostics**: Performance measurement
- **Microsoft.Extensions.Logging.Testing**: Log verification
- **Custom metrics**: Response time and throughput validation

## Running Tests

### All Tests
```bash
dotnet test
```

### Specific Categories
```bash
# Unit tests only
dotnet test --filter "TestCategory=Unit"

# Integration tests
dotnet test --filter "TestCategory=Integration"

# Functional tests
dotnet test --filter "TestCategory=Functional"
```

### With Coverage
```bash
dotnet test --collect:"XPlat Code Coverage"
```

### Parallel Execution
```bash
dotnet test --parallel
```

## Test Data Generation

### Realistic Test Data
The test suite uses **Bogus** to generate realistic racing-related test data:

- **USB Devices**: Racing wheels, pedals, shifters with proper vendor/product IDs
- **Software**: Popular racing games and utilities with realistic paths
- **Automation Rules**: Common racing automation scenarios
- **System Metrics**: Realistic CPU, memory, and performance data

### Consistent Test Environment
- **In-Memory Database**: Fast, isolated database per test
- **Deterministic Data**: Consistent test data generation
- **Clean State**: Each test starts with a clean database
- **Transaction Rollback**: Automatic cleanup between tests

## Test Patterns

### Arrange-Act-Assert
```csharp
[Fact]
public async Task GetDevice_WithValidId_ShouldReturnDevice()
{
    // Arrange
    var device = TestDataGenerator.CreateSimpleTestDevice("Test Device");
    _context.UsbDevices.Add(device);
    await _context.SaveChangesAsync();

    // Act
    var result = await _controller.GetDevice(device.Id);

    // Assert
    result.Value.Should().NotBeNull();
    result.Value!.Name.Should().Be("Test Device");
}
```

### Integration Test Pattern
```csharp
[Fact]
public async Task CreateDevice_ValidDevice_ShouldReturnCreatedWithLocation()
{
    // Arrange
    await _factory.ResetDatabaseAsync();
    var newDevice = new UsbDevice { /* ... */ };

    // Act
    var response = await _client.PostAsJsonAsync("/api/devices", newDevice);

    // Assert
    response.StatusCode.Should().Be(HttpStatusCode.Created);
    response.Headers.Location.Should().NotBeNull();
}
```

### Functional Test Pattern
```csharp
[Fact]
public async Task SimRacingWorkflow_SetupDeviceAndSoftwareWithAutomation_ShouldWorkEndToEnd()
{
    // Arrange - Setup complete racing environment
    // Act - Execute full user workflow
    // Assert - Verify end-to-end functionality
}
```

## Performance Testing

### Response Time Targets
- **API Endpoints**: < 500ms for CRUD operations
- **Dashboard Queries**: < 1000ms for complex aggregations
- **Automation Triggers**: < 200ms for rule execution
- **Health Checks**: < 100ms for system status

### Load Testing Scenarios
- **Concurrent Users**: 50+ simultaneous dashboard users
- **Device Events**: 100+ device status updates per second
- **Automation Rules**: 10+ rules executing simultaneously
- **Data Queries**: Complex reporting queries under load

## Continuous Integration

### Test Execution Pipeline
1. **Unit Tests**: Fast feedback on code changes
2. **Integration Tests**: Verify API contract compliance
3. **Functional Tests**: Validate end-user scenarios
4. **Performance Tests**: Ensure response time targets

### Test Reports
- **Coverage Reports**: Code coverage metrics and trends
- **Performance Metrics**: Response time and throughput data
- **Test Results**: Pass/fail status with detailed logs
- **Regression Detection**: Automated detection of performance degradation

## Debugging Tests

### Test Output
- **Detailed Logging**: Comprehensive test execution logs
- **HTTP Traffic**: Request/response details for API tests
- **Database Queries**: Entity Framework query logging
- **Performance Metrics**: Timing and resource usage data

### IDE Integration
- **Visual Studio**: Full debugging support with breakpoints
- **VS Code**: Integrated test runner and debugging
- **JetBrains Rider**: Advanced test analysis and profiling
- **Command Line**: Detailed console output and formatting

## Best Practices

### Test Organization
- **Single Responsibility**: One test per specific behavior
- **Descriptive Names**: Clear test method names describing scenarios
- **Consistent Structure**: Standard Arrange-Act-Assert pattern
- **Proper Categorization**: Use test categories for organization

### Data Management
- **Isolated Tests**: Each test runs in isolation
- **Clean State**: Start with fresh data for each test
- **Realistic Data**: Use domain-appropriate test data
- **Performance Conscious**: Minimize test data setup time

### Assertion Quality
- **Specific Assertions**: Test exact expected behavior
- **Error Messages**: Clear failure messages for debugging
- **Multiple Assertions**: Verify all relevant aspects
- **Boundary Conditions**: Test edge cases and limits

## Maintenance

### Test Updates
- **API Changes**: Update tests when API contracts change
- **New Features**: Add tests for new functionality
- **Bug Fixes**: Add regression tests for fixed issues
- **Performance**: Update performance baselines as needed

### Test Health
- **Execution Time**: Monitor and optimize slow tests
- **Flaky Tests**: Identify and fix unreliable tests
- **Coverage Gaps**: Maintain high code coverage
- **Documentation**: Keep test documentation current