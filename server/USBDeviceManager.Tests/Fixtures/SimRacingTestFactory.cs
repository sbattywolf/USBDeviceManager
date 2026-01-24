using System.Data.Common;
using System.Diagnostics;
using System.IO;
using System.Threading;
using System.Collections.Generic;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using USBDeviceManager.Data;

namespace USBDeviceManager.Tests.Fixtures;

/// <summary>
/// Test application factory for integration and functional tests
/// Provides isolated test environment with in-memory database
/// </summary>
public class SimRacingTestFactory : WebApplicationFactory<Program>
{
    private TextWriter? _originalOut;
    private TextWriter? _originalErr;
    private StreamWriter? _consoleWriter;
    private readonly string _testDatabaseName;
    private readonly string _dbFilePath;
    private readonly string _connectionString;
    // no shared connection by default; use connection string to allow EF to manage connections

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
            IEnumerable<string> files = Directory.EnumerateFiles(tempDir, "SimRacingTest_*.db");

            var expirationHours = 6;
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
                catch (Exception ex)
                {
                    Console.Error.WriteLine($"SimRacingTestFactory: failed to delete temp DB '{f}': {ex}");
                }
            }
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"SimRacingTestFactory: startup cleanup failed: {ex}");
        }

        // Create the database file and apply PRAGMAs to improve concurrency
        try
        {
            using var tmpConn = new SqliteConnection(_connectionString);
            tmpConn.Open();
            using (SqliteCommand cmd = tmpConn.CreateCommand())
            {
                cmd.CommandText = "PRAGMA journal_mode=WAL;";
                cmd.ExecuteNonQuery();
            }
            using (SqliteCommand cmd = tmpConn.CreateCommand())
            {
                cmd.CommandText = "PRAGMA busy_timeout=10000;";
                cmd.ExecuteNonQuery();
            }
            tmpConn.Close();
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"SimRacingTestFactory: failed to set PRAGMAs on '{_dbFilePath}': {ex}");
        }
        // Eagerly initialize EF/SQLite model and database while single-threaded so
        // that any SQLite user-function registration happens before concurrent tests.
        try
        {
            using SimRacingContext initContext = GetDbContext();
            initContext.Database.EnsureCreated();
            // force model creation
            _ = initContext.Model;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"SimRacingTestFactory: EF model initialization failed: {ex}");
        }
    }

    /// <summary>
    /// Configure test services and database
    /// </summary>
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
            // Redirect Console output/errors to a test artifact file so CI uploads host logs
            try
            {
                var artifactsDir = Path.Combine(Directory.GetCurrentDirectory(), "TestResults", "artifacts");
                Directory.CreateDirectory(artifactsDir);
                var consoleLogPath = Path.Combine(artifactsDir, _testDatabaseName + "-server-console.log");

                _originalOut = Console.Out;
                _originalErr = Console.Error;
                _consoleWriter = new StreamWriter(new FileStream(consoleLogPath, FileMode.Append, FileAccess.Write, FileShare.Read)) { AutoFlush = true };
                Console.SetOut(_consoleWriter);
                Console.SetError(_consoleWriter);
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"SimRacingTestFactory: failed to redirect console output: {ex}");
            }

        builder.ConfigureServices(services =>
        {
            // Remove existing database context registration
            ServiceDescriptor? descriptor = services.SingleOrDefault(
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

            // Reduce logging noise in tests but capture host logs to a file
            services.AddLogging(builder =>
            {
                builder.ClearProviders();

                // Ensure test artifacts folder exists and compute deterministic log path
                try
                {
                    var artifactsDir = Path.Combine(Directory.GetCurrentDirectory(), "TestResults", "artifacts");
                    Directory.CreateDirectory(artifactsDir);
                    var logPath = Path.Combine(artifactsDir, _testDatabaseName + "-server.log");

                    builder.AddProvider(new FileLoggerProvider(logPath));
                }
                catch (Exception ex)
                {
                    Console.Error.WriteLine($"SimRacingTestFactory: failed to configure file logger: {ex}");
                }

                builder.AddDebug();
                builder.SetMinimumLevel(LogLevel.Debug);
            });

            // Build a temporary provider and initialize the database via DI to ensure
            // EF/SQLite registers any required functions while single-threaded.
            try
            {
                ServiceProvider sp = services.BuildServiceProvider();
                using IServiceScope scope = sp.CreateScope();
                SimRacingContext ctx = scope.ServiceProvider.GetRequiredService<SimRacingContext>();
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

    // Simple file logger provider used only in test builds to capture WebHost logs
    private class FileLoggerProvider : ILoggerProvider
    {
        private readonly StreamWriter _writer;
        private readonly object _lock = new object();

        public FileLoggerProvider(string path)
        {
            // Open file in append mode and keep it for the test lifetime
            _writer = new StreamWriter(new FileStream(path, FileMode.Append, FileAccess.Write, FileShare.Read))
            {
                AutoFlush = true
            };
        }

        public ILogger CreateLogger(string categoryName)
        {
            return new FileLogger(_writer, _lock, categoryName);
        }

        public void Dispose()
        {
            try
            {
                _writer?.Dispose();
            }
            catch
            {
                // swallow
            }
        }
    }

    private class FileLogger : ILogger
    {
        private readonly StreamWriter _writer;
        private readonly object _lock;
        private readonly string _category;

        public FileLogger(StreamWriter writer, object lck, string category)
        {
            _writer = writer;
            _lock = lck;
            _category = category;
        }

        public IDisposable? BeginScope<TState>(TState state) where TState : notnull => null;

        public bool IsEnabled(LogLevel logLevel) => true;

        public void Log<TState>(LogLevel logLevel, EventId eventId, TState state, Exception? exception, Func<TState, Exception?, string> formatter)
        {
            try
            {
                var message = formatter(state, exception);
                lock (_lock)
                {
                    _writer.WriteLine($"[{DateTime.UtcNow:O}] [{logLevel}] {_category}: {message}");
                    if (exception != null)
                    {
                        _writer.WriteLine(exception.ToString());
                    }
                }
            }
            catch
            {
                // Swallow to avoid affecting tests
            }
        }
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
        DbContextOptions<SimRacingContext> options = new DbContextOptionsBuilder<SimRacingContext>()
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
        using SimRacingContext context = GetDbContext();

        // Ensure database is created
        await context.Database.EnsureCreatedAsync();

        // Clear existing data
        context.UsbDevices.RemoveRange(context.UsbDevices);
        context.ManagedSoftware.RemoveRange(context.ManagedSoftware);
        context.AutomationRules.RemoveRange(context.AutomationRules);
        await context.SaveChangesAsync();

        // Add test devices and software, save them first so EF assigns IDs
        List<UsbDevice> testDevices = TestDataGenerator.GenerateTestDevices(3);
        context.UsbDevices.AddRange(testDevices);

        List<ManagedSoftware> testSoftware = TestDataGenerator.GenerateTestSoftware(2);
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

        for (var i = 0; i < 2; i++)
        {
            UsbDevice device = testDevices[rng.Next(testDevices.Count)];
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
        using SimRacingContext context = GetDbContext();

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
    /// Dump a lightweight snapshot of the SQLite database (schema + recent rows)
    /// to the given output file path as JSON. Best-effort: failures are logged
    /// to Console.Error but do not throw to avoid masking test results.
    /// </summary>
    public void DumpDatabaseSnapshot(string outFilePath)
    {
        try
        {
            using var conn = new SqliteConnection(_connectionString);
            conn.Open();

            var tables = new List<string>();
            using (var cmd = conn.CreateCommand())
            {
                cmd.CommandText = "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';";
                using var r = cmd.ExecuteReader();
                while (r.Read())
                {
                    tables.Add(r.GetString(0));
                }
            }

            var tablesData = new Dictionary<string, object>();

            foreach (var t in tables)
            {
                var tableObj = new Dictionary<string, object>();

                using (var cmd = conn.CreateCommand())
                {
                    cmd.CommandText = "SELECT sql FROM sqlite_master WHERE type='table' AND name=@name;";
                    cmd.Parameters.AddWithValue("@name", t);
                    var createSql = cmd.ExecuteScalar()?.ToString() ?? string.Empty;
                    tableObj["create"] = createSql;
                }

                // Capture up to 200 recent rows
                using (var cmd = conn.CreateCommand())
                {
                    cmd.CommandText = $"SELECT * FROM \"{t}\" ORDER BY rowid DESC LIMIT 200;";
                    using var rdr = cmd.ExecuteReader();
                    var rows = new List<Dictionary<string, object>>();
                    while (rdr.Read())
                    {
                        var row = new Dictionary<string, object>();
                        for (int i = 0; i < rdr.FieldCount; i++)
                        {
                            var name = rdr.GetName(i);
                            var val = rdr.IsDBNull(i) ? null : rdr.GetValue(i);
                            row[name] = val;
                        }
                        rows.Add(row);
                    }

                    tableObj["rows"] = rows;
                }

                tablesData[t] = tableObj;
            }

            var outObj = new { dumpedAt = DateTime.UtcNow, tables = tablesData };
            var json = JsonSerializer.Serialize(outObj, new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(outFilePath, json);
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"SimRacingTestFactory: DumpDatabaseSnapshot failed: {ex}");
        }
    }

    /// <summary>
    /// Create authenticated HTTP client for API testing
    /// </summary>
    public HttpClient CreateAuthenticatedClient()
    {
        HttpClient client = CreateClient();

        // Add any authentication headers if needed
        // client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        return client;
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            // Best-effort: clear any SQLite connection pools so underlying file
            // handles are released before we attempt to delete the DB file.
            try
            {
                try
                {
                    SqliteConnection.ClearAllPools();
                }
                catch (Exception ex)
                {
                    Console.Error.WriteLine($"SimRacingTestFactory: ClearAllPools() failed: {ex}");
                }

                if (!string.IsNullOrEmpty(_dbFilePath) && File.Exists(_dbFilePath))
                {
                    const int maxAttempts = 5;
                    int delayMs = 200;
                    for (int attempt = 1; attempt <= maxAttempts; attempt++)
                    {
                        try
                        {
                            File.Delete(_dbFilePath);
                            break; // success
                        }
                        catch (IOException ioEx) when (attempt < maxAttempts)
                        {
                            Console.Error.WriteLine($"SimRacingTestFactory: delete attempt {attempt} failed: {ioEx.Message}. Retrying in {delayMs}ms.");
                            Thread.Sleep(delayMs);
                            delayMs *= 2;
                        }
                        catch (Exception ex)
                        {
                            Console.Error.WriteLine($"SimRacingTestFactory: failed to delete temp DB on dispose '{_dbFilePath}': {ex}");
                            break;
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"SimRacingTestFactory: unexpected error during dispose cleanup: {ex}");
            }
        }

        // Restore Console output and dispose writer if we redirected it
        try
        {
            if (_consoleWriter != null)
            {
                try
                {
                    _consoleWriter.Flush();
                }
                catch { }

                try
                {
                    Console.SetOut(_originalOut ?? TextWriter.Null);
                    Console.SetError(_originalErr ?? TextWriter.Null);
                }
                catch { }

                try
                {
                    _consoleWriter.Dispose();
                }
                catch { }
            }
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"SimRacingTestFactory: error restoring console output: {ex}");
        }

        // Ensure base disposal runs to release other test host resources.
        base.Dispose(disposing);
    }
}
