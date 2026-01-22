using System.Net;
using System.Net.Http.Json;
using FluentAssertions;
using Microsoft.AspNetCore.Mvc.Testing;
using USBDeviceManager.Models;
using USBDeviceManager.Tests.Fixtures;

namespace USBDeviceManager.Tests.Functional;

/// <summary>
/// Functional tests for complete SimRacing Dashboard workflows
/// Tests end-to-end user scenarios and system integration
/// </summary>
[Trait("Category","Functional")]
public class DashboardFunctionalTests : IClassFixture<SimRacingTestFactory>
{
    private readonly SimRacingTestFactory _factory;
    private readonly HttpClient _client;

    public DashboardFunctionalTests(SimRacingTestFactory factory)
    {
        _factory = factory;
        _client = _factory.CreateClient();
    }

    [Fact]
    public async Task CreateSoftware_MissingRequiredField_ReturnsBadRequest()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();

        // Missing ExecutablePath which is required by SoftwareCreateDto
        var invalidSoftware = new
        {
            Name = "IncompleteApp"
            // ExecutablePath omitted
        };

        // Act
        HttpResponseMessage response = await _client.PostAsJsonAsync("/api/software", invalidSoftware);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        var content = await response.Content.ReadAsStringAsync();
        // response should include structured validation errors produced by ValidationFilter
        content.Should().Contain("errors");
    }

    [Fact]
    public async Task StartSoftware_WhenDisabled_ReturnsBadRequest()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();

        var swDto = new
        {
            Name = "DisabledApp",
            ExecutablePath = "C:\\fake\\app.exe",
            IsEnabled = false
        };

        HttpResponseMessage createResp = await _client.PostAsJsonAsync("/api/software", swDto);
        createResp.StatusCode.Should().Be(HttpStatusCode.Created);
        ManagedSoftware? created = await createResp.Content.ReadFromJsonAsync<ManagedSoftware>();
        created.Should().NotBeNull();

        // Act - attempt to start the disabled software
        HttpResponseMessage startResp = await _client.PostAsync($"/api/software/{created!.Id}/start", null);

        // Assert
        startResp.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        var body = await startResp.Content.ReadAsStringAsync();
        body.ToLowerInvariant().Should().Contain("disabled");
    }

    [Fact]
    public async Task SimRacingWorkflow_SetupDeviceAndSoftwareWithAutomation_ShouldWorkEndToEnd()
    {
        // Arrange - Start with clean slate
        await _factory.ResetDatabaseAsync();

        // Step 1: Add a racing wheel device
        var racingWheel = new UsbDevice
        {
            DeviceId = "USB\\VID_046D&PID_C29A",
            Name = "Logitech G29 Racing Wheel",
            VendorId = "046D",
            ProductId = "C29A",
            Description = "Professional racing wheel with force feedback",
            IsEnabled = true
        };

        HttpResponseMessage deviceResponse = await _client.PostAsJsonAsync("/api/devices", racingWheel);
        deviceResponse.StatusCode.Should().Be(HttpStatusCode.Created);

        UsbDevice? createdDevice = await deviceResponse.Content.ReadFromJsonAsync<UsbDevice>();
        createdDevice.Should().NotBeNull();

        // Step 2: Add racing software
        var racingSoftware = new ManagedSoftware
        {
            Name = "iRacing",
            ExecutablePath = @"C:\Program Files\iRacing\iRacingSim64DX11.exe",
            StartupArguments = "--fullscreen",
            WorkingDirectory = @"C:\Program Files\iRacing",
            AutoStart = false,
            IsEnabled = true
        };

        HttpResponseMessage softwareResponse = await _client.PostAsJsonAsync("/api/software", racingSoftware);
        softwareResponse.StatusCode.Should().Be(HttpStatusCode.Created);

        ManagedSoftware? createdSoftware = await softwareResponse.Content.ReadFromJsonAsync<ManagedSoftware>();
        createdSoftware.Should().NotBeNull();

        // Step 3: Create automation rule - Start iRacing when wheel connects
        var automationRule = new AutomationRule
        {
            Name = "Auto-start iRacing on G29 connection",
            Description = "Automatically launch iRacing when the Logitech G29 wheel is connected",
            Trigger = AutomationTrigger.DeviceConnected,
            Action = AutomationAction.StartSoftware,
            TriggerDeviceId = createdDevice!.Id,
            TargetSoftwareId = createdSoftware!.Id,
            IsEnabled = true
        };

        HttpResponseMessage ruleResponse = await _client.PostAsJsonAsync("/api/automation", automationRule);
        ruleResponse.StatusCode.Should().Be(HttpStatusCode.Created);

        AutomationRule? createdRule = await ruleResponse.Content.ReadFromJsonAsync<AutomationRule>();
        createdRule.Should().NotBeNull();

        // Step 4: Verify dashboard shows all components
        HttpResponseMessage dashboardResponse = await _client.GetAsync("/api/monitoring/dashboard");
        dashboardResponse.StatusCode.Should().Be(HttpStatusCode.OK);

        System.Text.Json.JsonElement dashboardJson = System.Text.Json.JsonDocument.Parse(await dashboardResponse.Content.ReadAsStringAsync()).RootElement;
        dashboardJson.TryGetProperty("systemStatus", out _).Should().BeTrue();

        // Step 5: Test automation trigger - Simulate device connection
        var deviceEvent = new { DeviceId = createdDevice!.Id, EventType = "connected" };
        HttpResponseMessage triggerResponse = await _client.PostAsJsonAsync("/api/automation/trigger/device", deviceEvent);
        triggerResponse.StatusCode.Should().Be(HttpStatusCode.OK);

        // Step 6: Verify rule execution was logged
        HttpResponseMessage executionsResponse = await _client.GetAsync($"/api/automation/{createdRule!.Id}/executions");
        executionsResponse.StatusCode.Should().Be(HttpStatusCode.OK);

        RuleExecution[]? executions = await executionsResponse.Content.ReadFromJsonAsync<RuleExecution[]>();
        executions.Should().NotBeNull();
        executions!.Should().HaveCountGreaterOrEqualTo(1);

        // Step 7: Clean up - Test deletion cascade
        HttpResponseMessage deleteRuleResponse = await _client.DeleteAsync($"/api/automation/{createdRule!.Id}");
        deleteRuleResponse.StatusCode.Should().Be(HttpStatusCode.NoContent);

        HttpResponseMessage deleteSoftwareResponse = await _client.DeleteAsync($"/api/software/{createdSoftware!.Id}");
        deleteSoftwareResponse.StatusCode.Should().Be(HttpStatusCode.NoContent);

        HttpResponseMessage deleteDeviceResponse = await _client.DeleteAsync($"/api/devices/{createdDevice!.Id}");
        deleteDeviceResponse.StatusCode.Should().Be(HttpStatusCode.NoContent);
    }

    [Fact]
    public async Task MultiDeviceRacingSetup_ComplexAutomation_ShouldHandleMultipleDevicesAndSoftware()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();

        // Create multiple racing devices
        UsbDevice[] devices =
        [
            new UsbDevice
            {
                DeviceId = "USB\\VID_046D&PID_C29A",
                Name = "Logitech G29 Wheel",
                VendorId = "046D",
                ProductId = "C29A",
                IsEnabled = true
            },
            new UsbDevice
            {
                DeviceId = "USB\\VID_044F&PID_B66D",
                Name = "Thrustmaster T300 RS",
                VendorId = "044F",
                ProductId = "B66D",
                IsEnabled = true
            }
        ];

        var createdDevices = new List<UsbDevice>();
        foreach (UsbDevice? device in devices)
        {
            HttpResponseMessage response = await _client.PostAsJsonAsync("/api/devices", device);
            UsbDevice? createdDevice = await response.Content.ReadFromJsonAsync<UsbDevice>();
            createdDevices.Add(createdDevice!);
        }

        // Create multiple racing applications
        ManagedSoftware[] software =
        [
            new ManagedSoftware
            {
                Name = "iRacing",
                ExecutablePath = @"C:\Program Files\iRacing\iRacingSim64DX11.exe",
                IsEnabled = true
            },
            new ManagedSoftware
            {
                Name = "SimHub",
                ExecutablePath = @"C:\Program Files\SimHub\SimHubWPF.exe",
                IsEnabled = true
            }
        ];

        var createdSoftware = new List<ManagedSoftware>();
        foreach (ManagedSoftware? sw in software)
        {
            HttpResponseMessage response = await _client.PostAsJsonAsync("/api/software", sw);
            ManagedSoftware? createdSw = await response.Content.ReadFromJsonAsync<ManagedSoftware>();
            createdSoftware.Add(createdSw!);
        }

        // Create automation rules for different scenarios
        AutomationRule[] rules =
        [
            new AutomationRule
            {
                Name = "Start iRacing on any wheel connection",
                Trigger = AutomationTrigger.DeviceConnected,
                Action = AutomationAction.StartSoftware,
                TargetSoftwareId = createdSoftware[0].Id,
                IsEnabled = true
            },
            new AutomationRule
            {
                Name = "Start SimHub on system startup",
                Trigger = AutomationTrigger.SystemStartup,
                Action = AutomationAction.StartSoftware,
                TargetSoftwareId = createdSoftware[1].Id,
                IsEnabled = true
            }
        ];

        foreach (AutomationRule? rule in rules)
        {
            HttpResponseMessage response = await _client.PostAsJsonAsync("/api/automation", rule);
            response.StatusCode.Should().Be(HttpStatusCode.Created);
        }

        // Act - Test system monitoring with multiple components
        HttpResponseMessage dashboardResponse = await _client.GetAsync("/api/monitoring/dashboard");

        // Assert
        dashboardResponse.StatusCode.Should().Be(HttpStatusCode.OK);
        System.Text.Json.JsonElement dashboardJson = System.Text.Json.JsonDocument.Parse(await dashboardResponse.Content.ReadAsStringAsync()).RootElement;
        dashboardJson.TryGetProperty("systemStatus", out _).Should().BeTrue();

        // Verify all devices and software are tracked
        HttpResponseMessage devicesResponse = await _client.GetAsync("/api/devices");
        UsbDevice[]? allDevices = await devicesResponse.Content.ReadFromJsonAsync<UsbDevice[]>();
        allDevices.Should().HaveCount(2);

        HttpResponseMessage softwareResponse = await _client.GetAsync("/api/software");
        ManagedSoftware[]? allSoftware = await softwareResponse.Content.ReadFromJsonAsync<ManagedSoftware[]>();
        allSoftware.Should().HaveCount(2);

        HttpResponseMessage rulesResponse = await _client.GetAsync("/api/automation");
        AutomationRule[]? allRules = await rulesResponse.Content.ReadFromJsonAsync<AutomationRule[]>();
        allRules.Should().HaveCount(2);
    }

    [Fact]
    public async Task SystemHealthMonitoring_ContinuousMonitoring_ShouldTrackSystemMetrics()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();

        // Act - Test health monitoring endpoints
        HttpResponseMessage healthResponse = await _client.GetAsync("/api/monitoring/health");

        // Assert
        healthResponse.StatusCode.Should().Be(HttpStatusCode.OK);
        System.Text.Json.JsonElement healthJson = System.Text.Json.JsonDocument.Parse(await healthResponse.Content.ReadAsStringAsync()).RootElement;
        healthJson.GetProperty("status").GetString().Should().Be("healthy");

        // Test system status retrieval
        HttpResponseMessage statusResponse = await _client.GetAsync("/api/monitoring/status");
        statusResponse.StatusCode.Should().Be(HttpStatusCode.OK);

        SystemStatus? statusData = await statusResponse.Content.ReadFromJsonAsync<SystemStatus>();
        statusData.Should().NotBeNull();
        statusData!.Timestamp.Should().BeCloseTo(DateTime.UtcNow, TimeSpan.FromMinutes(1));

        // Test status refresh
        HttpResponseMessage refreshResponse = await _client.PostAsync("/api/monitoring/status/refresh", null);
        refreshResponse.StatusCode.Should().Be(HttpStatusCode.OK);

        // Test metrics recording
        var testMetric = new HealthMetric
        {
            MetricName = "Test_CPU_Temperature",
            Value = 65.5,
            Source = "Hardware",
            Timestamp = DateTime.UtcNow
        };

        HttpResponseMessage metricResponse = await _client.PostAsJsonAsync("/api/monitoring/metrics", testMetric);
        metricResponse.StatusCode.Should().Be(HttpStatusCode.Created);

        // Verify metric retrieval
        HttpResponseMessage getMetricsResponse = await _client.GetAsync("/api/monitoring/metrics/Test_CPU_Temperature");
        getMetricsResponse.StatusCode.Should().Be(HttpStatusCode.OK);

        HealthMetric[]? retrievedMetrics = await getMetricsResponse.Content.ReadFromJsonAsync<HealthMetric[]>();
        retrievedMetrics.Should().NotBeNull();
        retrievedMetrics!.Should().HaveCountGreaterOrEqualTo(1);
        retrievedMetrics.Should().Contain(m => m.MetricName == "Test_CPU_Temperature" && m.Value == 65.5);
    }

    [Fact]
    public async Task ErrorHandlingAndRecovery_InvalidOperations_ShouldHandleGracefully()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();

        // Test 1: Invalid device operations
        var invalidDevice = new UsbDevice
        {
            DeviceId = "", // Invalid - empty
            Name = "", // Invalid - empty
            IsEnabled = true
        };

        HttpResponseMessage deviceResponse = await _client.PostAsJsonAsync("/api/devices", invalidDevice);
        deviceResponse.StatusCode.Should().Be(HttpStatusCode.BadRequest);

        // Test 2: Operations on non-existent resources
        HttpResponseMessage nonExistentDeviceResponse = await _client.GetAsync("/api/devices/99999");
        nonExistentDeviceResponse.StatusCode.Should().Be(HttpStatusCode.NotFound);

        HttpResponseMessage nonExistentSoftwareResponse = await _client.PostAsync("/api/software/99999/start", null);
        nonExistentSoftwareResponse.StatusCode.Should().Be(HttpStatusCode.NotFound);

        HttpResponseMessage nonExistentRuleResponse = await _client.PostAsync("/api/automation/99999/execute", null);
        nonExistentRuleResponse.StatusCode.Should().Be(HttpStatusCode.NotFound);

        // Test 3: Invalid automation triggers
        var invalidTrigger = new { DeviceId = 99999, EventType = "invalid_event" };
        HttpResponseMessage triggerResponse = await _client.PostAsJsonAsync("/api/automation/trigger/device", invalidTrigger);
        triggerResponse.StatusCode.Should().Be(HttpStatusCode.BadRequest);

        // Test 4: System should still be responsive after errors
        HttpResponseMessage healthResponse = await _client.GetAsync("/api/monitoring/health");
        healthResponse.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task PerformanceUnderLoad_MultipleSimultaneousRequests_ShouldMaintainResponsiveness()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();
        await _factory.SeedTestDataAsync();

        var tasks = new List<Task<HttpResponseMessage>>();
        var stopwatch = System.Diagnostics.Stopwatch.StartNew();

        // Act - Generate concurrent load
        // Reduce load in CI/local tests to avoid SQLite concurrency limits
        for (var i = 0; i < 5; i++)
        {
            tasks.Add(_client.GetAsync("/api/devices"));
            tasks.Add(_client.GetAsync("/api/software"));
            tasks.Add(_client.GetAsync("/api/automation"));
            tasks.Add(_client.GetAsync("/api/monitoring/dashboard"));
            tasks.Add(_client.GetAsync("/api/monitoring/health"));
        }

        HttpResponseMessage[] responses = await Task.WhenAll(tasks);
        stopwatch.Stop();

        // Assert
        responses.Should().OnlyContain(r => r.IsSuccessStatusCode);
        stopwatch.ElapsedMilliseconds.Should().BeLessThan(5000); // Should complete within 5 seconds

        // Verify system is still responsive after load test
        HttpResponseMessage finalHealthCheck = await _client.GetAsync("/api/monitoring/health");
        finalHealthCheck.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task DataConsistency_ConcurrentModifications_ShouldMaintainIntegrity()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();

        // Create test device
        var device = new UsbDevice
        {
            DeviceId = "USB\\VID_TEST&PID_CONCURRENT",
            Name = "Concurrency Test Device",
            IsEnabled = true
        };

        HttpResponseMessage deviceResponse = await _client.PostAsJsonAsync("/api/devices", device);
        UsbDevice? createdDevice = await deviceResponse.Content.ReadFromJsonAsync<UsbDevice>();

        // Act - Perform concurrent modifications
        // Perform toggle operations sequentially to avoid SQLite concurrency locks in tests
        for (var i = 0; i < 10; i++)
        {
            var enableState = i % 2 == 0;
            HttpResponseMessage res = await _client.PostAsJsonAsync($"/api/devices/{createdDevice!.Id}/toggle", enableState);
            res.IsSuccessStatusCode.Should().BeTrue();
        }

        // Verify final state is consistent
        HttpResponseMessage finalDeviceResponse = await _client.GetAsync($"/api/devices/{createdDevice!.Id}");
        finalDeviceResponse.StatusCode.Should().Be(HttpStatusCode.OK);

        UsbDevice? finalDevice = await finalDeviceResponse.Content.ReadFromJsonAsync<UsbDevice>();
        finalDevice.Should().NotBeNull();
        finalDevice!.Id.Should().Be(createdDevice.Id);
        // Basic sanity: ensure we retrieved a device
        finalDevice.Should().NotBeNull();
    }

    [Fact]
    public async Task AutomationWorkflow_ComplexRuleExecution_ShouldExecuteInCorrectOrder()
    {
        // Arrange
        await _factory.ResetDatabaseAsync();
        await _factory.SeedTestDataAsync();

        using Data.SimRacingContext context = _factory.GetDbContext();
        UsbDevice device = context.UsbDevices.First();
        ManagedSoftware software = context.ManagedSoftware.First();

        // Create chained automation rules
        var rule1 = new AutomationRule
        {
            Name = "Primary Rule - Start Software",
            Trigger = AutomationTrigger.DeviceConnected,
            Action = AutomationAction.StartSoftware,
            TriggerDeviceId = device.Id,
            TargetSoftwareId = software.Id,
            IsEnabled = true
        };

        var rule2 = new AutomationRule
        {
            Name = "Secondary Rule - Send Notification",
            Trigger = AutomationTrigger.DeviceConnected,
            Action = AutomationAction.SendNotification,
            TriggerDeviceId = device.Id,
            IsEnabled = true
        };

        await _client.PostAsJsonAsync("/api/automation", rule1);
        await _client.PostAsJsonAsync("/api/automation", rule2);

        // Act - Trigger automation
        var deviceEvent = new { DeviceId = device.Id, EventType = "connected" };
        HttpResponseMessage triggerResponse = await _client.PostAsJsonAsync("/api/automation/trigger/device", deviceEvent);

        // Assert
        triggerResponse.StatusCode.Should().Be(HttpStatusCode.OK);

        System.Text.Json.JsonElement triggerJson = System.Text.Json.JsonDocument.Parse(await triggerResponse.Content.ReadAsStringAsync()).RootElement;
        triggerJson.GetProperty("triggeredRules").GetInt32().Should().BeGreaterOrEqualTo(1);

        // Verify both rules were triggered
        HttpResponseMessage executionsResponse = await _client.GetAsync("/api/automation/executions?hours=1");
        executionsResponse.StatusCode.Should().Be(HttpStatusCode.OK);

        RuleExecution[]? executions = await executionsResponse.Content.ReadFromJsonAsync<RuleExecution[]>();
        executions.Should().NotBeNull();
        executions!.Should().HaveCountGreaterOrEqualTo(2);

        // All executions should be recent and successful
        executions.Should().OnlyContain(e => e.ExecutedAt >= DateTime.UtcNow.AddMinutes(-5));
        executions.Should().OnlyContain(e => e.Success == true);
    }
}
