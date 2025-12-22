using Xunit.Abstractions;

namespace SimRacingDashboard.Tests;

/// <summary>
/// Global test setup and configuration
/// Provides common test utilities and logging configuration
/// </summary>
public class GlobalTestSetup
{
    public static void ConfigureTestLogging(ITestOutputHelper output)
    {
        // Configure test-specific logging if needed
        Environment.SetEnvironmentVariable("ASPNETCORE_ENVIRONMENT", "Testing");
    }
}

/// <summary>
/// Test categories for organizing test execution
/// </summary>
public static class TestCategories
{
    public const string Unit = "Unit";
    public const string Integration = "Integration";
    public const string Functional = "Functional";
    public const string Performance = "Performance";
    public const string Database = "Database";
    public const string Api = "Api";
    public const string Automation = "Automation";
}

/// <summary>
/// Custom test collection for shared test factory
/// Ensures proper test isolation and resource management
/// </summary>
[CollectionDefinition("SimRacing Test Collection")]
public class SimRacingTestCollection : ICollectionFixture<SimRacingTestFactory>
{
    // This class has no code, and is never created. Its purpose is simply
    // to be the place to apply [CollectionDefinition] and all the
    // ICollectionFixture<> interfaces.
}