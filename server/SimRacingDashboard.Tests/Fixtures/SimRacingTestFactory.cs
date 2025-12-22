using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using SimRacingDashboard.Data;
using System.Data.Common;
using System.IO;
using System.Diagnostics;

namespace SimRacingDashboard.Tests.Fixtures;

/// <summary>
/// Test application factory for integration and functional tests
/// Provides isolated test environment with in-memory database
/// </summary>
public class SimRacingTestFactory : WebApplicationFactory<Program>
{
    private readonly string _testDatabaseName;
    private readonly string _dbFilePath;
    private readonly string _connectionString;

    public SimRacingTestFactory()
    {
        // Deterministic per-run test DB name (timestamp + PID). This makes the
        // DB filename discoverable and helps with cleanup across runs.
        _testDatabaseName = $"SimRacingTest_{DateTime.UtcNow:yyyyMMddHHmmss}_{Process.GetCurrentProcess().Id}";

        // Use a temporary file-based SQLite DB to allow multiple connections
        _dbFilePath = Path.Combine(Path.GetTempPath(), _testDatabaseName + ".db");
        _connectionString = $"Data Source={_dbFilePath};Cache=Shared";

        // Defensive startup cleanup: remove old leftover SimRacingTest_*.db files.
        // Expiration window can be configured via SIMRACING_TEST_DB_EXPIRATION_HOURS (hours).
        try
        {
            var tempDir = Path.GetTempPath();
            var files = Directory.EnumerateFiles(tempDir, "SimRacingTest_*.db");

            int expirationHours = 6;
            var env = Environment.GetEnvironmentVariable("SIMRACING_TEST_DB_EXPIRATION_HOURS");
            if (!string.IsNullOrEmpty(env) && int.TryParse(env, out var parsed) && parsed >= 0)
            {
                expirationHours = parsed;
            }

            var expiration = TimeSpan.FromHours(expirationHours);

            foreach (var f in files)
            {
                try
                {
                    var fi = new FileInfo(f);
                    if (DateTime.UtcNow - fi.LastWriteTimeUtc > expiration)
                    {
                        File.Delete(f);
                    }
                }
                catch
                {
                    // ignore per-file errors
                }
            }
        }
        catch
        {
            // ignore any file-system errors during startup cleanup
        }

        // Create the database file and apply PRAGMAs to improve concurrency
        try
        {
            using var tmpConn = new SqliteConnection(_connectionString);
            tmpConn.Open();
            using (var cmd = tmpConn.CreateCommand())
            {
                cmd.CommandText = "PRAGMA journal_mode=WAL;";
                cmd.ExecuteNonQuery();
            }
            using (var cmd = tmpConn.CreateCommand())
            {
                cmd.CommandText = "PRAGMA busy_timeout=10000;";
                cmd.ExecuteNonQuery();
            }
            tmpConn.Close();
        }
        catch
        {
            // ignore
        }
        // Eagerly initialize EF/SQLite model and database while single-threaded so
        // that any SQLite user-function registration happens before concurrent tests.
        try
        {
            using var initContext = GetDbContext();
            initContext.Database.EnsureCreated();
            // force model creation
            _ = initContext.Model;
        }
        catch
        {
            // Ignore initialization errors here; tests will surface them.
        }
    }

    /// <summary>
    /// Configure test services and database
    /// </summary>
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureServices(services =>
        {
            // Remove existing database context registration
            var descriptor = services.SingleOrDefault(
                d => d.ServiceType == typeof(DbContextOptions<SimRacingContext>));
            
            if (descriptor != null)
            {
                services.Remove(descriptor);
            }

            // Use a file-based SQLite database so multiple concurrent connections work
            services.AddDbContext<SimRacingContext>(options =>
            {
                options.UseSqlite(_connectionString);
                options.EnableSensitiveDataLogging();
                options.EnableDetailedErrors();
            });

            // Reduce logging noise in tests
            services.AddLogging(builder =>
            {
                builder.ClearProviders();
                builder.AddDebug();
                builder.SetMinimumLevel(LogLevel.Warning);
            });

            // Build a temporary provider and initialize the database via DI to ensure
            // EF/SQLite registers any required functions while single-threaded.
            try
            {
                var sp = services.BuildServiceProvider();
                using var scope = sp.CreateScope();
                var ctx = scope.ServiceProvider.GetRequiredService<SimRacingContext>();
                ctx.Database.EnsureCreated();
            }
            catch
            {
                // ignore init errors here; tests will report them
            }
        });

        builder.UseEnvironment("Testing");
        builder.UseConfiguration(new ConfigurationBuilder()
            .AddJsonFile("appsettings.Testing.json")
            .Build());
    }

    /// <summary>
    /// Get database context for test data setup
    /// </summary>
    /// <summary>
    /// Create a standalone <see cref="SimRacingContext"/> instance backed by the
    /// shared in-memory SQLite connection. Callers must dispose the returned context.
    /// </summary>
    public SimRacingContext GetDbContext()
    {
        var options = new DbContextOptionsBuilder<SimRacingContext>()
            .UseSqlite(_connectionString)
            .EnableSensitiveDataLogging()
            .EnableDetailedErrors()
            .Options;

        return new SimRacingContext(options);
    }

    /// <summary>
    /// Seed test data for functional tests
    /// </summary>
    public async Task SeedTestDataAsync()
    {
        using var context = GetDbContext();

        // Ensure database is created
        await context.Database.EnsureCreatedAsync();
        
        // Clear existing data
        context.UsbDevices.RemoveRange(context.UsbDevices);
        context.ManagedSoftware.RemoveRange(context.ManagedSoftware);
        context.AutomationRules.RemoveRange(context.AutomationRules);
        await context.SaveChangesAsync();
        
        // Add test devices and software, save them first so EF assigns IDs
        var testDevices = TestDataGenerator.GenerateTestDevices(3);
        context.UsbDevices.AddRange(testDevices);

        var testSoftware = TestDataGenerator.GenerateTestSoftware(2);
        context.ManagedSoftware.AddRange(testSoftware);

        await context.SaveChangesAsync();

        // Now generate and add automation rules using persisted IDs. Build rules
        // here to ensure they reference the just-saved entities (avoid using
        // generators that may rely on pre-save IDs).
        var rng = new Random();
        var rules = new List<Models.AutomationRule>();
        var ruleNames = new[]
        {
            "Auto-start software on device connect",
            "Notify on device connect"
        };

        for (int i = 0; i < 2; i++)
        {
            var device = testDevices[rng.Next(testDevices.Count)];
            ManagedSoftware? sw = null;
            if (testSoftware.Any())
            {
                sw = testSoftware[rng.Next(testSoftware.Count)];
            }

            var r = new Models.AutomationRule
            {
                Name = ruleNames[i % ruleNames.Length],
                Trigger = Models.AutomationTrigger.DeviceConnected,
                Action = sw != null ? Models.AutomationAction.StartSoftware : Models.AutomationAction.SendNotification,
                TriggerDeviceId = device.Id,
                TargetSoftwareId = sw?.Id,
                IsEnabled = true,
                CreatedAt = DateTime.UtcNow
            };

            rules.Add(r);
        }

        context.AutomationRules.AddRange(rules);

        await context.SaveChangesAsync();
    }

    /// <summary>
    /// Reset database for clean test state
    /// </summary>
    public async Task ResetDatabaseAsync()
    {
        using var context = GetDbContext();

        // Clear all data
        context.RuleExecutions.RemoveRange(context.RuleExecutions);
        context.AutomationRules.RemoveRange(context.AutomationRules);
        context.SoftwareStatuses.RemoveRange(context.SoftwareStatuses);
        context.ManagedSoftware.RemoveRange(context.ManagedSoftware);
        context.DeviceStatuses.RemoveRange(context.DeviceStatuses);
        context.UsbDevices.RemoveRange(context.UsbDevices);
        context.HealthMetrics.RemoveRange(context.HealthMetrics);
        context.SystemStatuses.RemoveRange(context.SystemStatuses);
        
        await context.SaveChangesAsync();
    }

    /// <summary>
    /// Create authenticated HTTP client for API testing
    /// </summary>
    public HttpClient CreateAuthenticatedClient()
    {
        var client = CreateClient();
        
        // Add any authentication headers if needed
        // client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        
        return client;
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            // Remove the temporary DB file. Do not access Services here because the
            // underlying ServiceProvider may already be disposed by the base.
            try
            {
                if (!string.IsNullOrEmpty(_dbFilePath) && File.Exists(_dbFilePath))
                {
                    File.Delete(_dbFilePath);
                }
            }
            catch
            {
                // ignore disposal errors during test teardown
            }
        }
        
        base.Dispose(disposing);
    }
}